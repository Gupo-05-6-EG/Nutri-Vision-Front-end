import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../home/presentation/home_tab.dart';
import '../../profile/presentation/profile_tab.dart';
import '../../register/presentation/register_tab.dart';
import '../../social/presentation/social_tab.dart';

/// Abas do app do paciente, como no protótipo: Início, Registrar, Social e
/// Perfil. Substitui a home provisória (lista de botões).
class MainShell extends StatefulWidget {
  const MainShell({required this.services, this.initialTab = 0, super.key});

  final AppServices services;
  final int initialTab;

  static const tabLabels = ['Início', 'Registrar', 'Social', 'Perfil'];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialTab;

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final s = widget.services;
    return Scaffold(
      appBar: AppBar(
        title: const NvBrand(),
        actions: [
          ListenableBuilder(
            listenable: s.profile,
            builder: (context, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: XpBadge(xp: s.profile.xp),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeTab(services: s, onRegister: () => _select(1)),
            RegisterTab(services: s),
            SocialTab(services: s),
            ProfileTab(services: s),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'Registrar',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group),
            label: 'Social',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

/// Item de menu das abas: cartão com ícone, título, descrição e seta.
class MenuCard extends StatelessWidget {
  const MenuCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NvCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        semanticLabel: subtitle == null ? title : '$title. $subtitle',
        child: ExcludeSemantics(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rolagem padrão das abas, com largura máxima em telas largas.
class TabScroll extends StatelessWidget {
  const TabScroll({required this.children, this.onRefresh, super.key});

  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }
}
