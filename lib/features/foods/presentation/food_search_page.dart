import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/food_repository.dart';
import '../domain/food.dart';
import '../domain/number_format.dart';
import 'portion_sheet.dart';

/// Busca manual de alimentos (RF02.2).
///
/// O paciente digita o nome, escolhe um alimento da lista e informa o peso ou
/// a medida caseira. Ao confirmar, a tela fecha devolvendo um [FoodPortion]
/// (`Navigator.pop`), para o fluxo de montar a refeicao usar.
class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({
    required this.repository,
    this.debounce = const Duration(milliseconds: 300),
    super.key,
  });

  final FoodRepository repository;

  /// Espera depois da ultima tecla antes de chamar a API.
  final Duration debounce;

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

enum _Status { idle, loading, success, failure }

class _FoodSearchPageState extends State<FoodSearchPage> {
  final _controller = TextEditingController();

  Timer? _timer;

  /// Identifica a busca mais recente: respostas de buscas antigas sao ignoradas.
  int _requestId = 0;

  _Status _status = _Status.idle;
  List<Food> _results = const [];
  String _query = '';
  String _errorMessage = '';

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    final query = text.trim();

    if (query.isEmpty) {
      _requestId++;
      setState(() {
        _status = _Status.idle;
        _results = const [];
        _query = '';
      });
      return;
    }

    _timer = Timer(widget.debounce, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;
    setState(() {
      _status = _Status.loading;
      _query = query;
    });

    try {
      final foods = await widget.repository.search(query);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _status = _Status.success;
        _results = foods;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _status = _Status.failure;
        _errorMessage = _describe(error);
      });
    }
  }

  String _describe(Object error) {
    if (error is ApiException && error.statusCode == null) {
      return 'Sem conexão com a API. Verifique sua internet.';
    }
    return 'Não foi possível buscar os alimentos. Tente novamente.';
  }

  Future<void> _select(Food food) async {
    final portion = await showModalBottomSheet<FoodPortion>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PortionSheet(food: food),
    );
    if (portion == null || !mounted) return;
    Navigator.of(context).pop(portion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar alimento')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Ex.: arroz, frango, banana',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.idle:
        return const _Message(
          icon: Icons.search,
          text: 'Digite o nome de um alimento para buscar.',
        );
      case _Status.loading:
        return const Center(child: CircularProgressIndicator());
      case _Status.failure:
        return _Message(
          icon: Icons.cloud_off,
          text: _errorMessage,
          onRetry: () => _search(_query),
        );
      case _Status.success:
        if (_results.isEmpty) {
          return _Message(
            icon: Icons.search_off,
            text: 'Nenhum alimento encontrado para "$_query".',
          );
        }
        return ListView.separated(
          itemCount: _results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final food = _results[index];
            final kcal = formatNumber(food.kcalPer100g);
            return ListTile(
              title: Text(food.name),
              subtitle: Text('${food.category} · $kcal kcal/100 g'),
              onTap: () => _select(food),
            );
          },
        );
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
