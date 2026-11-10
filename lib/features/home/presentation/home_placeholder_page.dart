import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../auth/application/auth_controller.dart';
import '../../linking/presentation/linking_page.dart';

/// Destino temporario depois do login. A home real (meta diaria, registro de
/// refeicoes etc.) entra em outras tasks e substitui esta tela.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({
    required this.auth,
    super.key,
  });

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Env.appName),
        actions: [
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Login realizado com sucesso.\n'
                'As telas principais entram nas próximas tasks.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LinkingPage(auth: auth),
                  ),
                ),
                icon: const Icon(Icons.link),
                label: const Text('Vincular nutricionista'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
