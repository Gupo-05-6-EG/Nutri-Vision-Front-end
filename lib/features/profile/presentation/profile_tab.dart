import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';

/// Aba Perfil: dados do paciente e configurações.
class ProfileTab extends StatelessWidget {
  const ProfileTab({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final s = services;
    return TabScroll(
      children: [
        const NvSectionTitle('Perfil'),
        MenuCard(
          icon: Icons.local_fire_department_outlined,
          title: 'Calcular minha meta diária',
          onTap: () => AppRoutes.screening(context, s),
        ),
        MenuCard(
          icon: Icons.notifications_outlined,
          title: 'Lembretes de refeição',
          onTap: () => AppRoutes.reminders(context, s),
        ),
        MenuCard(
          icon: Icons.restaurant_outlined,
          title: 'Meus alimentos',
          onTap: () => AppRoutes.foods(context, s),
        ),
        MenuCard(
          icon: Icons.link,
          title: 'Vincular nutricionista',
          onTap: () => AppRoutes.linking(context, s),
        ),
        MenuCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacidade e meus dados',
          onTap: () => AppRoutes.privacy(context, s),
        ),
        NvButton(
          label: 'Sair da conta',
          icon: Icons.logout,
          style: NvButtonStyle.danger,
          onPressed: s.auth.logout,
        ),
      ],
    );
  }
}
