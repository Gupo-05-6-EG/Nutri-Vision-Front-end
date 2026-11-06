import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'autonomous_signup_page.dart';
import 'link_code_page.dart';
import 'login_page.dart';
import 'widgets/auth_widgets.dart';

/// Primeira tela para quem nao tem sessao: login ou um dos dois cadastros.
class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.auth, super.key});

  final AuthController auth;

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
                  Icon(Icons.eco, size: 96, color: theme.colorScheme.primary),
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
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => _open(context, LoginPage(auth: auth)),
                    child: const Text('Login'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () => _open(context, LinkCodePage(auth: auth)),
                    child: const Text('Tenho nutricionista'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: () =>
                        _open(context, AutonomousSignupPage(auth: auth)),
                    child: const Text('Vou seguir sozinho'),
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
