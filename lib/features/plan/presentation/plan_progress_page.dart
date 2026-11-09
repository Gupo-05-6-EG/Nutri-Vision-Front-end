import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../foods/domain/number_format.dart';
import '../../meals/domain/meal.dart';
import '../data/plan_repository.dart';
import '../domain/meal_plan.dart';
import '../domain/progress.dart';

/// Plano prescrito e progresso do paciente (RF06, RF25).
///
/// Mostra o plano ativo do nutricionista e barras de progresso de hoje e da
/// semana (kcal e macros). As metas vem do plano; enquanto nao ha plano, vale
/// o teto calorico da triagem ([fallbackGoalKcal]).
class PlanProgressPage extends StatefulWidget {
  const PlanProgressPage({
    required this.repository,
    required this.patientId,
    this.fallbackGoalKcal,
    this.today,
    super.key,
  });

  final PlanRepository repository;
  final int patientId;

  /// Teto calorico da triagem (Task 1.3), usado quando nao ha plano ativo.
  final double? fallbackGoalKcal;

  /// Dia atual; existe para os testes nao dependerem do relogio.
  final DateTime? today;

  @override
  State<PlanProgressPage> createState() => _PlanProgressPageState();
}

enum _Status { loading, success, failure }

enum _Period { day, week }

class _PlanProgressPageState extends State<PlanProgressPage> {
  _Status _status = _Status.loading;
  _Period _period = _Period.day;
  MealPlan? _plan;
  WeekConsumption? _consumption;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final plan = await widget.repository.activePlan(widget.patientId);
      final consumption = await widget.repository.weekConsumption(
        patientId: widget.patientId,
        today: widget.today ?? DateTime.now(),
      );
      if (!mounted) return;
      setState(() {
        _status = _Status.success;
        _plan = plan;
        _consumption = consumption;
      });
    } catch (error) {
      if (!mounted) return;
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
    return 'Não foi possível carregar o seu plano. Tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu plano e progresso')),
      body: switch (_status) {
        _Status.loading => const Center(child: CircularProgressIndicator()),
        _Status.failure => _Message(
            icon: Icons.cloud_off,
            text: _errorMessage,
            onRetry: _load,
          ),
        _Status.success => RefreshIndicator(
            onRefresh: _load,
            child: _buildContent(),
          ),
      },
    );
  }

  Widget _buildContent() {
    final plan = _plan;
    final consumption = _consumption!;
    final isWeek = _period == _Period.week;
    final days = isWeek ? 7 : 1;

    final dailyKcal = plan?.goalKcal ?? widget.fallbackGoalKcal;
    final totals = isWeek ? consumption.week : consumption.today;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SegmentedButton<_Period>(
          segments: const [
            ButtonSegment(value: _Period.day, label: Text('Hoje')),
            ButtonSegment(value: _Period.week, label: Text('Semana')),
          ],
          selected: {_period},
          onSelectionChanged: (selection) =>
              setState(() => _period = selection.first),
        ),
        const SizedBox(height: 12),
        _ProgressCard(
          title: isWeek ? 'Meta da semana' : 'Meta diária',
          subtitle: isWeek ? 'De segunda-feira até hoje' : null,
          totals: totals,
          goalKcal: dailyKcal == null ? null : dailyKcal * days,
          goalProtein: plan == null ? null : plan.goalProtein * days,
        ),
        const SizedBox(height: 8),
        _GoalSource(plan: plan, hasCeiling: widget.fallbackGoalKcal != null),
        if (plan != null) ...[
          const SizedBox(height: 16),
          _PlanSection(plan: plan),
        ],
      ],
    );
  }
}

const _proteinColor = Color(0xFFF59E0B);
const _carbsColor = Color(0xFFEAB308);
const _fatColor = Color(0xFFDC2626);

/// Calorias e macros do periodo contra as metas, em barras de progresso.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.totals,
    required this.goalKcal,
    required this.goalProtein,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final NutritionTotals totals;
  final double? goalKcal;
  final double? goalProtein;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = goalKcal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _GoalBar(
              label: 'Calorias',
              consumed: totals.kcal,
              goal: goal,
              unit: 'kcal',
              color: theme.colorScheme.primary,
              large: true,
            ),
            const SizedBox(height: 16),
            _GoalBar(
              label: 'Proteína',
              consumed: totals.protein,
              goal: goalProtein,
              unit: 'g',
              color: _proteinColor,
            ),
            const SizedBox(height: 12),
            _GoalBar(
              label: 'Carboidratos',
              consumed: totals.carbs,
              goal: null,
              unit: 'g',
              color: _carbsColor,
            ),
            const SizedBox(height: 12),
            _GoalBar(
              label: 'Gorduras',
              consumed: totals.fat,
              goal: null,
              unit: 'g',
              color: _fatColor,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma barra: consumido contra a meta. Sem meta, mostra so o consumido.
class _GoalBar extends StatelessWidget {
  const _GoalBar({
    required this.label,
    required this.consumed,
    required this.goal,
    required this.unit,
    required this.color,
    this.large = false,
  });

  final String label;
  final double consumed;
  final double? goal;
  final String unit;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Meta zero ou ausente: sem barra, so o consumido.
    final target = (goal != null && goal! > 0) ? goal : null;
    final ratio = target == null ? 0.0 : progressRatio(consumed, target);
    final exceeded = ratio > 1;

    final value = target == null
        ? '${formatNumber(consumed)} $unit'
        : '${formatNumber(consumed)} / ${formatNumber(target)} $unit';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: large
                    ? theme.textTheme.titleSmall
                    : theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              value,
              style: large
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ],
        ),
        if (target != null) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: large ? 12 : 8,
            borderRadius: BorderRadius.circular(6),
            color: exceeded ? theme.colorScheme.error : color,
            semanticsLabel: 'Progresso de $label',
          ),
          const SizedBox(height: 4),
          Text(
            exceeded
                ? '${formatNumber(consumed - target)} $unit acima da meta'
                : '${formatNumber(target - consumed)} $unit restantes',
            style: theme.textTheme.bodySmall?.copyWith(
              color: exceeded ? theme.colorScheme.error : null,
            ),
          ),
        ] else
          Text('Sem meta definida', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// Diz de onde vem a meta mostrada nas barras.
class _GoalSource extends StatelessWidget {
  const _GoalSource({required this.plan, required this.hasCeiling});

  final MealPlan? plan;
  final bool hasCeiling;

  @override
  Widget build(BuildContext context) {
    final String text;
    if (plan != null) {
      text = 'Metas do plano do seu nutricionista.';
    } else if (hasCeiling) {
      text = 'Você ainda não tem um plano do nutricionista. '
          'Usando o seu teto calórico diário.';
    } else {
      text = 'Você ainda não tem plano nem meta diária. '
          'Calcule a sua meta na tela inicial.';
    }
    return Text(text, style: Theme.of(context).textTheme.bodySmall);
  }
}

/// Plano prescrito: um cartao por refeicao, com horario, metas e alimentos.
class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.plan});

  final MealPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = plan.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Plano prescrito', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(plan.title, style: theme.textTheme.titleLarge),
        if (note != null && note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(note, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 12),
        for (final meal in plan.meals) _PlanMealCard(meal: meal),
      ],
    );
  }
}

class _PlanMealCard extends StatelessWidget {
  const _PlanMealCard({required this.meal});

  final PlanMeal meal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = meal.note;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(meal.name, style: theme.textTheme.titleMedium),
                ),
                if (meal.time != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(meal.time!, style: theme.textTheme.labelLarge),
                  ),
                Text(
                  '${formatNumber(meal.goalKcal)} kcal',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            Text(
              'Meta de proteína: ${formatNumber(meal.goalProtein)} g',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final food in meal.foods)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(food.name)),
                    Text(
                      '${formatNumber(food.grams)} g',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (note != null && note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(note, style: theme.textTheme.bodySmall),
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
