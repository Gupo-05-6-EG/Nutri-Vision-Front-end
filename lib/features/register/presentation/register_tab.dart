import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';

/// Aba Registrar: refeição por foto (a IA identifica), montada à mão (funciona
/// sem internet) e o histórico do dia.
class RegisterTab extends StatelessWidget {
  const RegisterTab({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TabScroll(
      children: [
        const NvSectionTitle('Registrar refeição'),
        NvCard(
          onTap: () => AppRoutes.photoMeal(context, services),
          semanticLabel: 'Foto do prato. A IA identifica os alimentos e as '
              'porções. Ganhe 20 XP.',
          child: ExcludeSemantics(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text('Foto do prato', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'A IA identifica os alimentos e as porções',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const XpBadge(xp: 20, prefix: '+'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        MenuCard(
          icon: Icons.edit_note_rounded,
          title: 'Adicionar manualmente',
          subtitle: 'Busque os alimentos na tabela TACO (+10 XP)',
          onTap: () => AppRoutes.manualMeal(context, services),
        ),
        MenuCard(
          icon: Icons.restaurant_menu_outlined,
          title: 'Histórico de refeições',
          subtitle: 'O que você registrou em cada dia',
          onTap: () => AppRoutes.history(context, services),
        ),
      ],
    );
  }
}
