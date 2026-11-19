import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_colors.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../achievements/data/achievement_repository.dart';
import '../../linking/presentation/pending_link_card.dart';
import '../../meals/domain/meal.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';

/// Aba Início do protótipo: meta diária no anel, macros do dia e conquistas.
class HomeTab extends StatefulWidget {
  const HomeTab({
    required this.services,
    required this.onRegister,
    this.today,
    super.key,
  });

  final AppServices services;
  final VoidCallback onRegister;

  /// Dia mostrado (testes); padrão: hoje.
  final DateTime? today;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  NutritionTotals? _totals;
  List<Achievement>? _achievements;
  bool _consumptionFailed = false;
  Future<void>? _loading;
  bool _profileWasLoading = false;

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    _s.profile.addListener(_onProfileChanged);
    unawaited(_reload());
  }

  @override
  void dispose() {
    _s.profile.removeListener(_onProfileChanged);
    super.dispose();
  }

  /// O perfil recarrega depois de registrar ou sincronizar refeições: é a
  /// deixa para atualizar o consumo do dia também.
  void _onProfileChanged() {
    final loading = _s.profile.loading;
    if (_profileWasLoading && !loading) unawaited(_reload());
    _profileWasLoading = loading;
  }

  Future<void> _reload() => _loading ??= _load().whenComplete(() {
        _loading = null;
      });

  Future<void> _load() async {
    final patientId = _s.patientId;
    if (patientId == null) return;
    final now = widget.today ?? DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    try {
      final consumption = await _s.meals.dailyConsumption(
        patientId: patientId,
        day: day,
      );
      if (!mounted) return;
      setState(() {
        _totals = consumption.totals;
        _consumptionFailed = false;
      });
    } on Object {
      // Sem rede e sem registro local do dia: o anel fica zerado com o aviso.
      if (mounted) setState(() => _consumptionFailed = true);
    }
    try {
      final achievements = await _s.achievements.list();
      if (mounted) setState(() => _achievements = achievements);
    } on Object {
      // Conquistas são um extra da tela: sem elas o resto continua.
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_s.profile.refresh(), _reload()]);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _s.profile,
      builder: (context, _) {
        final profile = _s.profile.profile;
        final goal = _s.profile.goal;
        final totals = _totals ??
            const NutritionTotals(kcal: 0, protein: 0, carbs: 0, fat: 0);
        final nv = NvColors.of(context);
        return TabScroll(
          onRefresh: _refresh,
          children: [
            if (profile?.pendingNutritionist case final pending?) ...[
              PendingLinkCard(services: _s, nutritionist: pending),
              const SizedBox(height: 16),
            ],
            _GoalCard(
              consumedKcal: totals.kcal,
              goalKcal: goal.isSet ? goal.kcal : null,
              failed: _consumptionFailed,
              onScreening: () => AppRoutes.screening(context, _s),
              onRegister: widget.onRegister,
            ),
            const SizedBox(height: 16),
            MacroBar(
              label: 'Proteína',
              icon: Icons.egg_alt_rounded,
              color: nv.protein,
              consumed: totals.protein,
              goal: goal.proteinG,
            ),
            const SizedBox(height: 12),
            MacroBar(
              label: 'Carbo',
              icon: Icons.bakery_dining_rounded,
              color: nv.carbs,
              consumed: totals.carbs,
              goal: goal.carbsG,
            ),
            const SizedBox(height: 12),
            MacroBar(
              label: 'Gordura',
              icon: Icons.water_drop_rounded,
              color: nv.fat,
              consumed: totals.fat,
              goal: goal.fatG,
            ),
            if (_achievements case final achievements?
                when achievements.isNotEmpty) ...[
              const SizedBox(height: 16),
              _AchievementsCard(
                achievements: achievements,
                onOpen: () => AppRoutes.achievements(context, _s),
              ),
            ],
            const SizedBox(height: 16),
            if (profile?.activePlan case final plan?)
              MenuCard(
                icon: Icons.assignment_outlined,
                title: 'Meu plano: ${plan.title}',
                subtitle: profile?.nutritionist == null
                    ? 'Plano alimentar e progresso da semana'
                    : 'Prescrito por ${profile!.nutritionist!.name}',
                onTap: () => AppRoutes.plan(context, _s),
              )
            else
              MenuCard(
                icon: Icons.insights_outlined,
                title: 'Meu progresso',
                subtitle: 'Calorias e macros do dia e da semana',
                onTap: () => AppRoutes.plan(context, _s),
              ),
          ],
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.consumedKcal,
    required this.goalKcal,
    required this.failed,
    required this.onScreening,
    required this.onRegister,
  });

  final double consumedKcal;
  final double? goalKcal;
  final bool failed;
  final VoidCallback onScreening;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = goalKcal;
    final consumed = formatInt(consumedKcal.round());
    final String message;
    if (failed) {
      message = 'Não foi possível carregar o consumo de hoje.';
    } else if (goal == null) {
      message = 'Faça a triagem para calcular a sua meta diária.';
    } else if (consumedKcal <= goal) {
      final rest = formatInt((goal - consumedKcal).round());
      message = 'Restam $rest kcal para o seu objetivo!';
    } else {
      final over = formatInt((consumedKcal - goal).round());
      message = 'Você passou $over kcal da meta de hoje.';
    }
    return NvCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        children: [
          Semantics(
            header: true,
            child: Text('Meta Diária', style: theme.textTheme.headlineSmall),
          ),
          const SizedBox(height: 20),
          ProgressRing(
            progress: goal == null || goal <= 0 ? 0 : consumedKcal / goal,
            semanticLabel: goal == null
                ? 'Consumido hoje: $consumed quilocalorias'
                : 'Consumido hoje: $consumed de '
                    '${formatInt(goal.round())} quilocalorias',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restaurant_rounded,
                  color: theme.colorScheme.primary,
                  size: 36,
                ),
                Text(
                  consumed,
                  style: theme.textTheme.headlineMedium,
                ),
                Text(
                  goal == null
                      ? 'kcal hoje'
                      : '/ ${formatInt(goal.round())} kcal',
                  style: theme.textTheme.labelLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (goal == null && !failed)
            NvButton(
              label: 'Calcular minha meta',
              icon: Icons.local_fire_department_outlined,
              onPressed: onScreening,
            )
          else
            NvButton(
              label: 'Registrar refeição',
              icon: Icons.add_circle_outline,
              style: NvButtonStyle.accent,
              onPressed: onRegister,
            ),
        ],
      ),
    );
  }
}

class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard({required this.achievements, required this.onOpen});

  final List<Achievement> achievements;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    // As obtidas primeiro, depois as mais perto de serem obtidas.
    final sorted = [...achievements]..sort((a, b) {
        if (a.unlocked != b.unlocked) return a.unlocked ? -1 : 1;
        final pa = a.target == 0 ? 0 : a.progress / a.target;
        final pb = b.target == 0 ? 0 : b.progress / b.target;
        return pb.compareTo(pa);
      });
    return NvCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NvSectionTitle(
            'Suas Conquistas',
            icon: Icons.military_tech_rounded,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final achievement in sorted.take(3))
                Expanded(child: _AchievementBadge(achievement: achievement)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = achievement.unlocked;
    return Semantics(
      container: true,
      label: '${achievement.name}: '
          '${unlocked ? 'obtida' : 'bloqueada, ${achievement.progress} de ${achievement.target}'}',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
            ),
            child: Icon(
              unlocked ? Icons.emoji_events_rounded : Icons.lock_outline,
              color: unlocked
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.outline,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: unlocked ? null : theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
