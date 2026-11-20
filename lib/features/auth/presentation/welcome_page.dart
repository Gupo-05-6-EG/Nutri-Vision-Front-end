import 'package:flutter/material.dart';

import '../../screening/data/screening_repository.dart';
import '../application/auth_controller.dart';
import 'autonomous_signup_page.dart';
import 'link_code_page.dart';
import 'login_page.dart';
import 'widgets/auth_widgets.dart';
import '../../../core/ui/nv_widgets.dart';

/// Primeira tela para quem nao tem sessao: login ou um dos dois cadastros.
class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.auth, required this.screening, super.key});

  final AuthController auth;
  final ScreeningRepository screening;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = auth.notice;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (notice != null) ...[
                    AuthMessageBanner(message: notice, isError: false),
                    const SizedBox(height: 24),
                  ],
                  const _Illustration(),
                  const SizedBox(height: 24),
                  Text(
                    'Bem-vindo ao',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  Text(
                    'Nutri Vision!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sua jornada gamificada para uma alimentação mais '
                    'inteligente começa aqui.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  NvButton(
                    label: 'Login',
                    icon: Icons.login_rounded,
                    onPressed: () => _open(context, LoginPage(auth: auth)),
                  ),
                  const SizedBox(height: 12),
                  NvButton(
                    label: 'Tenho nutricionista',
                    icon: Icons.medical_services_outlined,
                    onPressed: () => _open(context, LinkCodePage(auth: auth)),
                  ),
                  const SizedBox(height: 12),
                  NvButton(
                    label: 'Vou seguir sozinho',
                    icon: Icons.person_outline,
                    style: NvButtonStyle.secondary,
                    onPressed: () => _open(
                      context,
                      AutonomousSignupPage(auth: auth, screening: screening),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

/// Ilustração do protótipo (a tigela) com o selo de XP de boas-vindas.
class _Illustration extends StatelessWidget {
  const _Illustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        height: 190,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/tigela.png',
                fit: BoxFit.contain,
                semanticLabel: 'Tigela de salada',
                errorBuilder: (context, _, __) => Icon(
                  Icons.eco,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const Positioned(
              top: 0,
              right: -8,
              child: XpBadge(xp: 10, prefix: '+'),
            ),
          ],
        ),
      ),
    );
  }
}
