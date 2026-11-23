import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import 'auth_error_message.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.auth, super.key});

  final AuthController auth;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.auth.login(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      // A raiz do app ja trocou para a area logada; volta ate ela.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Login',
      children: [
        Icon(Icons.eco, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          'Acessar sua conta',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Entre para continuar sua jornada saudável e conquistar níveis '
          'incríveis!',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          AuthMessageBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        Form(
          key: _formKey,
          child: Column(
            children: [
              AuthTextField(
                controller: _email,
                label: 'E-mail',
                hint: 'seu.email@exemplo.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _password,
                label: 'Senha',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.loginPassword,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Entrar',
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Não tem uma conta? Cadastre-se'),
        ),
      ],
    );
  }
}
