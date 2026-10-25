import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../foods/domain/number_format.dart';
import '../data/recognition_repository.dart';
import '../domain/detected_item.dart';
import '../domain/nutrition_estimate.dart';
import 'edit_item_sheet.dart';

/// Revisao do que a IA identificou na foto (RF02.1, RF02.3).
///
/// Mostra a foto com as tags de cada alimento, a confianca de cada item e
/// deixa o paciente corrigir as gramas e o preparo ou excluir itens antes de
/// registrar. A tabela nutricional e recalculada pela API a cada edicao. Ao
/// registrar, a tela fecha devolvendo `true` (`Navigator.pop`).
class RecognitionReviewPage extends StatefulWidget {
  const RecognitionReviewPage({
    required this.repository,
    required this.patientId,
    required this.photo,
    required this.items,
    this.consumedAt,
    super.key,
  });

  final RecognitionRepository repository;
  final int patientId;

  /// Foto enviada para a IA. As caixas dos itens sao fracoes dela.
  final ImageProvider photo;
  final List<DetectedItem> items;

  /// Quando a refeicao foi consumida; padrao: agora.
  final DateTime? consumedAt;

  @override
  State<RecognitionReviewPage> createState() => _RecognitionReviewPageState();
}

enum _Status { calculating, ready, failure, saving }

class _RecognitionReviewPageState extends State<RecognitionReviewPage> {
  late final List<DetectedItem> _items = List.of(widget.items);

  /// Identifica o calculo mais recente: respostas antigas sao ignoradas.
  int _requestId = 0;

  _Status _status = _Status.calculating;
  NutritionEstimate? _estimate;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  Future<void> _calculate() async {
    final requestId = ++_requestId;
    if (_items.isEmpty) {
      setState(() {
        _status = _Status.ready;
        _estimate = null;
      });
      return;
    }

    setState(() => _status = _Status.calculating);
    try {
      final estimate = await widget.repository.calculate(_items);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _status = _Status.ready;
        _estimate = estimate;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _status = _Status.failure;
        _estimate = null;
        _errorMessage = _describe(error);
      });
    }
  }

  String _describe(Object error) {
    if (error is ApiException) {
      if (error.statusCode == null) {
        return 'Sem conexão com a API. Verifique sua internet.';
      }
      // 422/404 do calculo explicam qual classe ficou sem mapeamento na TACO.
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

  Future<void> _edit(int index) async {
    final edited = await showModalBottomSheet<DetectedItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EditItemSheet(item: _items[index]),
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

  Future<void> _save() async {
    final estimate = _estimate;
    if (estimate == null) return;
    setState(() => _status = _Status.saving);
    try {
      await widget.repository.saveMeal(
        patientId: widget.patientId,
        consumedAt: widget.consumedAt ?? DateTime.now(),
        estimate: estimate,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _Status.ready);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível registrar a refeição.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final needsReview = _items.where((i) => i.level == ConfidenceLevel.low);
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar refeição')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TaggedPhoto(photo: widget.photo, items: _items),
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
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Nenhum alimento na refeição.',
                textAlign: TextAlign.center,
              ),
            ),
          for (var index = 0; index < _items.length; index++)
            _ItemTile(
              item: _items[index],
              photo: widget.photo,
              estimate: _estimate?.items.elementAtOrNull(index),
              onEdit: () => _edit(index),
              onRemove: () => _remove(index),
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
          child: Row(
            children: [
              Expanded(child: _buildTotal(context)),
              FilledButton.icon(
                onPressed: _status == _Status.ready && _estimate != null
                    ? _save
                    : null,
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

/// Cor do badge de cada faixa de confianca.
Color confidenceColor(ConfidenceLevel level, ColorScheme scheme) {
  switch (level) {
    case ConfidenceLevel.high:
      return const Color(0xFF2E7D32);
    case ConfidenceLevel.medium:
      return const Color(0xFFB26A00);
    case ConfidenceLevel.low:
      return scheme.error;
  }
}

/// Foto com uma caixa e uma tag por alimento identificado.
class _TaggedPhoto extends StatelessWidget {
  const _TaggedPhoto({required this.photo, required this.items});

  final ImageProvider photo;
  final List<DetectedItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      // A camera entrega 4:3; as caixas sao fracoes da foto inteira.
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: photo,
                  fit: BoxFit.fill,
                  semanticLabel: 'Foto da refeição',
                ),
                for (final item in items)
                  if (item.box case final box?)
                    Positioned(
                      left: box.left * width,
                      top: box.top * height,
                      width: box.width * width,
                      height: box.height * height,
                      child: _Tag(
                        item: item,
                        color: confidenceColor(item.level, scheme),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.item, required this.color});

  final DetectedItem item;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final percent = (item.confidence * 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: color, width: 2)),
      child: Align(
        alignment: Alignment.topLeft,
        child: ColoredBox(
          color: color,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              '${item.displayName} $percent%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ),
    );
  }
}

/// Um alimento: recorte da foto, badge de confianca, porcao e acoes.
class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.item,
    required this.photo,
    required this.estimate,
    required this.onEdit,
    required this.onRemove,
  });

  final DetectedItem item;
  final ImageProvider photo;
  final EstimatedItem? estimate;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = confidenceColor(item.level, theme.colorScheme);
    final percent = (item.confidence * 100).round();
    final kcal =
        estimate == null ? '' : ' · ${formatNumber(estimate!.kcal)} kcal';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _Crop(photo: photo, box: item.box),
            const SizedBox(width: 12),
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
                        text: '${item.level.label} · $percent%',
                        color: color,
                      ),
                      Text(
                        '${item.preparation.label} · '
                        '${formatNumber(item.grams)} g$kcal',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar ${item.displayName}',
              icon: const Icon(Icons.edit_outlined),
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

/// Recorte quadrado da foto na caixa do alimento.
class _Crop extends StatelessWidget {
  const _Crop({required this.photo, required this.box});

  static const double size = 56;

  final ImageProvider photo;
  final BoundingBox? box;

  /// Alinhamento que poe a caixa dentro da janela do recorte.
  static double _align(double start, double extent) {
    if (extent >= 1) return 0;
    return (start / (1 - extent)) * 2 - 1;
  }

  @override
  Widget build(BuildContext context) {
    final box = this.box;
    final Widget image;
    if (box == null || box.width <= 0 || box.height <= 0) {
      image = Image(image: photo, fit: BoxFit.cover);
    } else {
      image = OverflowBox(
        maxWidth: size / box.width,
        maxHeight: size / box.height,
        alignment: Alignment(
          _align(box.left, box.width),
          _align(box.top, box.height),
        ),
        child: Image(image: photo, fit: BoxFit.fill),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox.square(dimension: size, child: image),
    );
  }
}
