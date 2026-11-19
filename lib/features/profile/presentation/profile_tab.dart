import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/config/theme_controller.dart';
import '../../../core/ui/nv_colors.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../domain/patient_profile.dart';

/// Aba Perfil do protótipo: identidade, ofensiva e XP, estatísticas, divisão e
/// as configurações básicas (lembretes, modo de exibição, meta, nutricionista,
/// alimentos e privacidade).
class ProfileTab extends StatelessWidget {
  const ProfileTab({required this.services, super.key});

  final AppServices services;

  static const _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho',
    'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro', //
  ];

  static String memberSince(DateTime date) =>
      'Membro desde ${_months[date.month - 1]} de ${date.year}';

  Future<void> _goal(BuildContext context, PatientProfile? profile) async {
    final goal = profile?.goal;
    if (goal?.source == GoalSource.plan) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Meta diária'),
          content: Text(
            'Sua meta de ${formatInt(goal!.kcal!.round())} kcal foi definida '
            'pelo seu nutricionista no plano alimentar. Para mudar, fale com '
            '${profile?.nutritionist?.name ?? 'ele'}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return;
    }
    await AppRoutes.screening(context, services);
  }

  Future<void> _chooseTheme(BuildContext context) async {
    final controller = services.theme;
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Modo de exibição')),
            for (final mode in [
              ThemeMode.light,
              ThemeMode.dark,
              ThemeMode.system,
            ])
              ListTile(
                leading: Icon(
                  switch (mode) {
                    ThemeMode.light => Icons.light_mode_outlined,
                    ThemeMode.dark => Icons.dark_mode_outlined,
                    ThemeMode.system => Icons.brightness_auto_outlined,
                  },
                ),
                title: Text(ThemeController.label(mode)),
                trailing: controller.mode == mode
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) controller.setMode(chosen);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([services.profile, services.theme]),
      builder: (context, _) {
        final profile = services.profile.profile;
        final theme = Theme.of(context);
        final gamification = profile?.gamification ?? const Gamification();
        final goal = profile?.goal ?? const DailyGoal();
        return RefreshIndicator(
          onRefresh: services.profile.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        profile: profile,
                        error: services.profile.error,
                        onRetry: services.profile.refresh,
                      ),
                      const SizedBox(height: 28),
                      NvSectionTitle(
                        'Estatísticas',
                        trailing: Text(
                          'Divisão ${gamification.division}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      _StatsGrid(gamification: gamification),
                      const SizedBox(height: 24),
                      const NvSectionTitle('Configurações Básicas'),
                      NvCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            _SettingTile(
                              icon: Icons.notifications_active_outlined,
                              title: 'Lembretes de Refeição',
                              subtitle:
                                  'Horários para não esquecer de registrar',
                              onTap: () =>
                                  AppRoutes.reminders(context, services),
                            ),
                            _SettingTile(
                              icon: Icons.light_mode_outlined,
                              title: 'Modo de Exibição',
                              subtitle: 'Aparência da interface',
                              value: ThemeController.label(services.theme.mode),
                              onTap: () => _chooseTheme(context),
                            ),
                            _SettingTile(
                              icon: Icons.track_changes_outlined,
                              title: 'Meta Diária de Calorias',
                              subtitle: goal.source?.label ??
                                  'Faça a triagem para calcular',
                              value: goal.isSet
                                  ? '${formatInt(goal.kcal!.round())} kcal'
                                  : null,
                              onTap: () => _goal(context, profile),
                            ),
                            _SettingTile(
                              icon: Icons.medical_services_outlined,
                              title: profile?.nutritionist == null
                                  ? 'Vincular nutricionista'
                                  : profile!.nutritionist!.name,
                              subtitle: profile?.nutritionist == null
                                  ? 'Use o código que o profissional passou'
                                  : 'Seu nutricionista · ${profile!.nutritionist!.crn}',
                              onTap: profile?.nutritionist == null
                                  ? () => AppRoutes.linking(context, services)
                                  : () => AppRoutes.plan(context, services),
                            ),
                            _SettingTile(
                              icon: Icons.restaurant_outlined,
                              title: 'Meus Alimentos',
                              subtitle: 'Busque e cadastre alimentos',
                              onTap: () => AppRoutes.foods(context, services),
                            ),
                            _SettingTile(
                              icon: Icons.shield_outlined,
                              title: 'Privacidade e Dados (LGPD)',
                              subtitle: 'Exportação e proteção de dados',
                              onTap: () => AppRoutes.privacy(context, services),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      NvButton(
                        label: 'Sair da conta',
                        icon: Icons.logout,
                        style: NvButtonStyle.danger,
                        onPressed: services.auth.logout,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, this.error, this.onRetry});

  final PatientProfile? profile;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = this.profile;
    if (profile == null) {
      if (error != null) {
        return Column(
          children: [
            const Text('Não foi possível carregar o seu perfil.'),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        NvAvatar(name: profile.name, size: 112, highlight: true),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            profile.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        Text(profile.email, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                ProfileTab.memberSince(profile.memberSince),
                style: theme.textTheme.labelMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            StreakBadge(
              days: profile.gamification.streak,
              suffix: ' de ofensiva',
            ),
            XpBadge(xp: profile.gamification.xp),
          ],
        ),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.gamification});

  final Gamification gamification;

  @override
  Widget build(BuildContext context) {
    final nv = NvColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final next = gamification.nextDivision;
    final cards = [
      _StatCard(
        icon: Icons.local_fire_department_rounded,
        color: nv.streak,
        value: formatInt(gamification.streak),
        label: 'Ofensiva Atual',
      ),
      _StatCard(
        icon: Icons.bolt_rounded,
        color: nv.xpStep,
        value: formatInt(gamification.xp),
        label: 'Total de XP',
      ),
      _StatCard(
        icon: Icons.restaurant_rounded,
        color: scheme.primary,
        value: formatInt(gamification.mealsLogged),
        label: 'Refeições Feitas',
      ),
      _StatCard(
        icon: Icons.emoji_events_rounded,
        color: scheme.secondary,
        value: gamification.division,
        label: next == null
            ? 'Divisão Atual'
            : 'Divisão Atual · faltam ${formatInt(gamification.xpToNext ?? 0)} '
                'XP para $next',
        valueColor: scheme.secondary,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.valueColor,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NvCard(
      padding: const EdgeInsets.all(16),
      semanticLabel: '$label: $value',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(color: valueColor),
            ),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.value,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        child: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (value != null)
            Text(
              value!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
