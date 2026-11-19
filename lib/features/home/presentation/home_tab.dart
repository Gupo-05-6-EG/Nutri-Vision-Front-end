import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';

/// Aba Início: resumo do dia.
class HomeTab extends StatelessWidget {
  const HomeTab({required this.services, required this.onRegister, super.key});

  final AppServices services;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final profile = services.profile;
    return ListenableBuilder(
      listenable: profile,
      builder: (context, _) {
        final goal = profile.goal;
        return TabScroll(
          onRefresh: profile.refresh,
          children: [
            NvSectionTitle(
              'Olá, ${profile.profile?.firstName ?? 'paciente'}!',
            ),
            MenuCard(
              icon: Icons.insights_outlined,
              title: 'Meu plano e progresso',
              subtitle: goal.isSet
                  ? 'Meta de ${formatInt(goal.kcal!.round())} kcal por dia'
                  : 'Faça a triagem para calcular a sua meta',
              onTap: () => AppRoutes.plan(context, services),
            ),
            NvButton(
              label: 'Registrar refeição',
              icon: Icons.add_circle_outline,
              onPressed: onRegister,
            ),
          ],
        );
      },
    );
  }
}
