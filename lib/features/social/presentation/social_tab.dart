import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';

/// Aba Social: desafios e conquistas.
class SocialTab extends StatelessWidget {
  const SocialTab({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return TabScroll(
      children: [
        const NvSectionTitle('Social'),
        MenuCard(
          icon: Icons.emoji_events_outlined,
          title: 'Desafios entre amigos',
          onTap: () => AppRoutes.challenges(context, services),
        ),
        MenuCard(
          icon: Icons.military_tech_outlined,
          title: 'Minhas conquistas',
          onTap: () => AppRoutes.achievements(context, services),
        ),
      ],
    );
  }
}
