import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../foods/data/food_repository.dart';
import '../../foods/domain/food.dart';
import '../../foods/domain/number_format.dart';
import '../../foods/presentation/food_search_page.dart';
import '../../meals/domain/meal_type.dart';
import '../../meals/presentation/meal_type_selector.dart';
import '../data/recognition_repository.dart';
import '../domain/detected_item.dart';
import '../domain/nutrition_estimate.dart';
import 'edit_item_sheet.dart';

/// Revisao do que a IA identificou na foto (RF02.1, RF02.3), e tambem o
/// registro manual de uma refeicao (sem [photo], comecando vazia).
///
/// Mostra a foto, a confianca de cada item e deixa o paciente corrigir as
/// gramas, trocar um alimento por outro da TACO ou excluir itens antes de
/// registrar. Alimentos que a IA reconheceu mas que nao estao na TACO precisam
/// ser trocados ou excluidos. O tipo da refeicao vem sugerido pelo horario e
/// pode ser trocado (RF19). A tabela nutricional e recalculada pela API a cada
/// edicao. Ao registrar, a tela fecha devolvendo `true` (`Navigator.pop`).
class RecognitionReviewPage extends StatefulWidget {
  const RecognitionReviewPage({
    required this.repository,
    required this.patientId,
    required this.items,
    this.photo,
    this.consumedAt,
    this.foods,
    super.key,
  });

  final RecognitionRepository repository;
  final int patientId;

  /// Foto enviada para a IA; nula no registro manual.
  final ImageProvider? photo;
  final List<DetectedItem> items;

  /// Quando a refeicao foi consumida; padrao: agora.
  final DateTime? consumedAt;

  /// Busca na TACO para trocar um alimento. Precisa buscar so na TACO (sem
  /// `patientId`): o calculo usa o id do alimento na tabela.
  final FoodRepository? foods;

  @override
  State<RecognitionReviewPage> createState() => _RecognitionReviewPageState();
}

enum _Status { calculating, ready, failure, saving }

class _RecognitionReviewPageState extends State<RecognitionReviewPage> {
  late final List<DetectedItem> _items = List.of(widget.items);
  late final DateTime _consumedAt = widget.consumedAt ?? DateTime.now();
  late MealType _type = MealType.suggestedAt(_consumedAt.toLocal());

  /// Identifica o calculo mais recente: respostas antigas sao ignoradas.
  int _requestId = 0;

  _Status _status = _Status.calculating;
  NutritionEstimate? _estimate;

  /// Calculo de cada item, na ordem de [_items] (nulo fora da TACO).
  List<EstimatedItem?> _itemEstimates = const [];
  String _errorMessage = '';

  int get _outsideTaco => _items.where((item) => !item.isInTaco).length;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    final requestId = ++_requestId;
    final inTaco = [
      for (final item in _items)
        if (item.isInTaco) item,
    ];
    if (inTaco.isEmpty) {
      setState(() {
        _status = _Status.ready;
        _estimate = null;
        _itemEstimates = List.filled(_items.length, null);
      });
      return;
    }

    setState(() => _status = _Status.calculating);
    try {
      final estimate = await widget.repository.calculate(inTaco);
      if (!mounted || requestId != _requestId) return;
      final calculated = estimate.items.iterator;
      setState(() {
        _status = _Status.ready;
        _estimate = estimate;
        _itemEstimates = [
          for (final item in _items)
            item.isInTaco && calculated.moveNext() ? calculated.current : null,
        ];
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _status = _Status.failure;
        _estimate = null;
        _itemEstimates = List.filled(_items.length, null);
        _errorMessage = _describe(error);
      });
    }
  }

  String _describe(Object error) {
    if (error is ApiException) {
      if (error.statusCode == null) {
        return 'Sem conexão com a API. Verifique sua internet.';
      }
      // 422/404 do calculo explicam qual alimento nao foi encontrado na TACO.
      if (error.statusCode == 422 || error.statusCode == 404) {
        final detail = _detail(error.message);
        if (detail != null) return 'Não foi possível calcular: $detail';
      }
    }
    return 'Não foi possível calcular a tabela nutricional. Tente novamente.';
  }

  String? _detail(String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      return detail is String ? detail : null;
    } on FormatException {
      return null;
    }
  }

  Future<FoodPortion?> _searchTaco(BuildContext sheetContext) {
    return Navigator.of(sheetContext).push<FoodPortion>(
      MaterialPageRoute(
        builder: (_) => FoodSearchPage(repository: widget.foods!),
      ),
    );
  }

  /// Adiciona um alimento da TACO que a IA nao viu (ou monta a refeicao manual).
  Future<void> _addItem() async {
    final foods = widget.foods;
    if (foods == null) return;
    final portion = await Navigator.of(context).push<FoodPortion>(
      MaterialPageRoute(builder: (_) => FoodSearchPage(repository: foods)),
    );
    if (portion == null || !mounted) return;
    setState(
      () => _items.add(
        DetectedItem.manual(
          name: portion.food.name,
          tacoId: portion.food.id,
          grams: portion.grams,
        ),
      ),
    );
    await _calculate();
  }

  Future<void> _edit(int index) async {
    final edited = await showModalBottomSheet<DetectedItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => EditItemSheet(
        item: _items[index],
        searchFood:
            widget.foods == null ? null : () => _searchTaco(sheetContext),
      ),
    );
    if (edited == null || !mounted) return;
    setState(() => _items[index] = edited);
    await _calculate();
  }

  void _remove(int index) {
    final removed = _items[index];
    setState(() => _items.removeAt(index));
    _calculate();

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${removed.displayName} removido'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            if (!mounted) return;
            setState(
              () => _items.insert(index.clamp(0, _items.length), removed),
            );
            _calculate();
          },
        ),
      ),
    );
  }

  bool get _canSave =>
      _status == _Status.ready && _estimate != null && _outsideTaco == 0;

  Future<void> _save() async {
    final estimate = _estimate;
    if (estimate == null || _outsideTaco > 0) return;
    setState(() => _status = _Status.saving);
    try {
      await widget.repository.saveMeal(
        patientId: widget.patientId,
        consumedAt: _consumedAt,
        type: _type,
        estimate: estimate,
        origin: widget.photo == null ? MealOrigin.manual : MealOrigin.photo,
      );
      if (!mounted) return;
      // O "desfazer" de um item excluido nao vale mais fora desta tela.
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _Status.ready);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível registrar a refeição.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsReview = _items.where((i) => i.level == ConfidenceLevel.low);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.photo == null ? 'Nova refeição' : 'Revisar refeição'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.photo case final photo?) ...[
            _Photo(photo: photo),
            const SizedBox(height: 16),
          ],
          MealTypeSelector(
            value: _type,
            onChanged: (type) => setState(() => _type = type),
          ),
          const SizedBox(height: 16),
          if (needsReview.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'A IA não tem certeza de ${needsReview.length} '
                '${needsReview.length == 1 ? 'item' : 'itens'}. '
                'Confira antes de registrar.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_outsideTaco > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _outsideTaco == 1
                    ? '1 alimento não está na tabela TACO. Troque por um da '
                        'tabela ou exclua para registrar.'
                    : '$_outsideTaco alimentos não estão na tabela TACO. '
                        'Troque por alimentos da tabela ou exclua para '
                        'registrar.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                widget.photo == null
                    ? 'Adicione os alimentos da refeição.'
                    : 'Nenhum alimento na refeição.',
                textAlign: TextAlign.center,
              ),
            ),
          for (var index = 0; index < _items.length; index++)
            _ItemTile(
              item: _items[index],
              estimate: _itemEstimates.elementAtOrNull(index),
              onEdit: () => _edit(index),
              onRemove: () => _remove(index),
            ),
          if (widget.foods != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(
                onPressed: _status == _Status.saving ? null : _addItem,
                icon: const Icon(Icons.add),
                label: Text(
                  widget.photo == null
                      ? 'Adicionar alimento'
                      : 'Adicionar item manual',
                ),
              ),
            ),
          if (_status == _Status.failure) ...[
            const SizedBox(height: 8),
            Text(_errorMessage, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: _calculate,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar de novo'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(liveRegion: true, child: _buildTotal(context)),
              FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: _status == _Status.saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotal(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    switch (_status) {
      case _Status.calculating:
        return Text('Calculando...', style: style);
      case _Status.failure:
        return Text('Total indisponível', style: style);
      case _Status.ready:
      case _Status.saving:
        final kcal = _estimate?.totalKcal ?? 0;
        return Text('Total: ${formatNumber(kcal)} kcal', style: style);
    }
  }
}

/// Cor do badge de cada faixa de confianca, da paleta do prototipo. Fixas (e nao
/// do tema): o texto do badge e branco nos dois temas.
Color confidenceColor(ConfidenceLevel level) {
  switch (level) {
    case ConfidenceLevel.high:
      return const Color(0xFF2B6C00);
    case ConfidenceLevel.medium:
      return const Color(0xFF8C5000);
    case ConfidenceLevel.low:
      return const Color(0xFFBA1A1A);
  }
}

/// Foto enviada para a IA.
class _Photo extends StatelessWidget {
  const _Photo({required this.photo});

  final ImageProvider photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: Image(
          image: photo,
          fit: BoxFit.cover,
          semanticLabel: 'Foto da refeição',
        ),
      ),
    );
  }
}

/// Um alimento: badge de confianca, porcao, kcal e acoes.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.estimate,
    required this.onEdit,
    required this.onRemove,
  });

  final DetectedItem item;
  final EstimatedItem? estimate;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = confidenceColor(item.level);
    final percent = (item.confidence * 100).round();
    final kcal =
        estimate == null ? '' : ' · ${formatNumber(estimate!.kcal)} kcal';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.displayName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Badge(
                        text: item.manual
                            ? 'Manual'
                            : '${item.level.label} · $percent%',
                        color: item.manual ? theme.colorScheme.outline : color,
                      ),
                      Text(
                        item.isInTaco
                            ? '${formatNumber(item.grams)} g$kcal'
                            : 'Fora da TACO · ${formatNumber(item.grams)} g',
                        style: item.isInTaco
                            ? theme.textTheme.bodySmall
                            : theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: item.isInTaco
                  ? 'Editar ${item.displayName}'
                  : 'Trocar ${item.displayName}',
              icon: Icon(
                item.isInTaco ? Icons.edit_outlined : Icons.swap_horiz,
              ),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: 'Excluir ${item.displayName}',
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }
}
