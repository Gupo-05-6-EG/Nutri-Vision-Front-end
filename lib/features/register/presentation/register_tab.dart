import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';

/// Aba Registrar: foto do prato e histórico do dia.
class RegisterTab extends StatelessWidget {
  const RegisterTab({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return TabScroll(
      children: [
        const NvSectionTitle('Registrar refeição'),
        MenuCard(
          icon: Icons.photo_camera_outlined,
          title: 'Registrar refeição por foto',
          subtitle: 'A IA identifica os alimentos e as porções',
          onTap: () => AppRoutes.photoMeal(context, services),
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
