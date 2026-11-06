import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../auth/application/auth_controller.dart';

/// Destino temporario depois do login. A home real (meta diaria, registro de
/// refeicoes etc.) entra em outras tasks e substitui esta tela.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({required this.auth, super.key});

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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Login realizado com sucesso.\n'
            'As telas principais entram nas próximas tasks.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
