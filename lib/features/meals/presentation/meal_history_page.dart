import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../foods/domain/number_format.dart';
import '../data/meal_repository.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';
import 'meal_type_filter.dart';

/// Historico de refeicoes (RF04, RF12).
///
/// Feed cronologico do dia escolhido (abre no dia atual), com o total de
/// calorias em uma barra de progresso contra a meta diaria e os macros do dia.
/// Pode filtrar por tipo de refeicao (RF19); com filtro, os totais sao so os
/// daquele tipo.
class MealHistoryPage extends StatefulWidget {
  const MealHistoryPage({
    required this.repository,
    required this.patientId,
    required this.dailyGoalKcal,
    this.today,
    super.key,
  });

  final MealRepository repository;
  final int patientId;

  /// Meta de calorias do dia, usada como 100% da barra de progresso.
  final double dailyGoalKcal;

  /// Dia atual; existe para os testes nao dependerem do relogio.
  final DateTime? today;

  @override
  State<MealHistoryPage> createState() => _MealHistoryPageState();
}

enum _Status { loading, success, failure }

class _MealHistoryPageState extends State<MealHistoryPage> {
  late final DateTime _today = _dateOnly(widget.today ?? DateTime.now());
  late DateTime _day = _today;
  MealType? _type;

  /// Identifica a carga mais recente: respostas de dias antigos sao ignoradas.
  int _requestId = 0;

  _Status _status = _Status.loading;
  DailyConsumption? _consumption;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  static DateTime _dateOnly(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() => _status = _Status.loading);

    try {
      final consumption = await widget.repository.dailyConsumption(
        patientId: widget.patientId,
        day: _day,
        type: _type,
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _status = _Status.success;
        _consumption = consumption;
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
    return 'Não foi possível carregar as refeições. Tente novamente.';
  }

  void _changeDay(int days) {
    _day = DateTime(_day.year, _day.month, _day.day + days);
    _load();
  }

  void _changeType(MealType? type) {
    _type = type;
    _load();
  }

  String _dayLabel() {
    final difference = _today.difference(_day).inDays;
    if (difference == 0) return 'Hoje';
    if (difference == 1) return 'Ontem';
    final day = _day.day.toString().padLeft(2, '0');
    final month = _day.month.toString().padLeft(2, '0');
    return '$day/$month/${_day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = !_day.isBefore(_today);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de refeições')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Dia anterior',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeDay(-1),
                ),
                Expanded(
                  child: Text(
                    _dayLabel(),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Próximo dia',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isToday ? null : () => _changeDay(1),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: MealTypeFilter(value: _type, onChanged: _changeType),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.loading:
        return const Center(child: CircularProgressIndicator());
      case _Status.failure:
        return _Message(
          icon: Icons.cloud_off,
          text: _errorMessage,
          onRetry: _load,
        );
      case _Status.success:
        final consumption = _consumption!;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              _DailyProgress(
                totals: consumption.totals,
                goalKcal: widget.dailyGoalKcal,
              ),
              const SizedBox(height: 16),
              if (consumption.meals.isEmpty)
                _Message(
                  icon: Icons.restaurant,
                  text: _type == null
                      ? 'Nenhuma refeição registrada neste dia.'
                      : 'Nenhum ${_type!.label.toLowerCase()} registrado '
                          'neste dia.',
                )
              else
                for (final meal in consumption.meals) _MealCard(meal: meal),
            ],
          ),
        );
    }
  }
}

/// Calorias do dia contra a meta, e os macros consumidos.
class _DailyProgress extends StatelessWidget {
  const _DailyProgress({required this.totals, required this.goalKcal});

  final NutritionTotals totals;
  final double goalKcal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = goalKcal > 0 ? totals.kcal / goalKcal : 0.0;
    final exceeded = ratio > 1;
    final remaining = goalKcal - totals.kcal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatNumber(totals.kcal)} de ${formatNumber(goalKcal)} kcal',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              color: exceeded ? theme.colorScheme.error : null,
              semanticsLabel: 'Progresso da meta de calorias',
            ),
            const SizedBox(height: 8),
            Text(
              exceeded
                  ? '${formatNumber(-remaining)} kcal acima da meta'
                  : '${formatNumber(remaining)} kcal restantes',
              style: theme.textTheme.bodySmall?.copyWith(
                color: exceeded ? theme.colorScheme.error : null,
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Macro(label: 'Proteínas', grams: totals.protein),
                _Macro(label: 'Carboidratos', grams: totals.carbs),
                _Macro(label: 'Gorduras', grams: totals.fat),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.grams});

  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('${formatNumber(grams)} g', style: theme.textTheme.titleMedium),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Uma refeicao do feed: horario, tipo, itens e calorias.
class _MealCard extends StatelessWidget {
  const _MealCard({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = meal.consumedAt.toLocal();
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$hour:$minute', style: theme.textTheme.labelLarge),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mealTypeLabel(meal.type),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${formatNumber(meal.totals.kcal)} kcal',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final item in meal.items)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name)),
                    Text(
                      '${formatNumber(item.grams)} g · '
                      '${formatNumber(item.totals.kcal)} kcal',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (meal.note != null && meal.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(meal.note!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
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
