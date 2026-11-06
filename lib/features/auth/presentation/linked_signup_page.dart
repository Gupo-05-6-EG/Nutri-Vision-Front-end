import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_error_message.dart';
import 'auth_validators.dart';
import 'widgets/auth_widgets.dart';

/// Passo 2 do cadastro "Tenho nutricionista": cria a conta e, em seguida,
/// resgata o codigo de vinculo digitado no passo 1.
class LinkedSignupPage extends StatefulWidget {
  const LinkedSignupPage({
    required this.auth,
    required this.linkCode,
    super.key,
  });

  final AuthController auth;
  final String linkCode;

  @override
  State<LinkedSignupPage> createState() => _LinkedSignupPageState();
}

class _LinkedSignupPageState extends State<LinkedSignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  /// Preenchido quando a conta foi criada mas o codigo nao pode ser usado.
  String? _linkError;

  @override
  void dispose() {
    _name.dispose();
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
      await widget.auth.registerPatient(
        PatientSignup(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(error);
        _loading = false;
      });
      return;
    }

    // A conta ja existe e a sessao esta aberta: o codigo so pode ser usado
    // agora, com o token do paciente.
    try {
      await widget.auth.linkProfessional(widget.linkCode);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _linkError = authErrorMessage(
          error,
          notFound: 'Código não encontrado. Confira com o seu nutricionista.',
        );
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_linkError != null) {
      return AuthScaffold(
        title: 'Cadastro',
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Conta criada!',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          AuthMessageBanner(
            message: 'Não foi possível vincular ao nutricionista.\n'
                '$_linkError\n'
                'Você poderá tentar de novo depois.',
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Continuar',
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      );
    }

    return AuthScaffold(
      title: 'Cadastro',
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Crie sua conta',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Ao concluir, vamos vincular você ao seu nutricionista.',
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
                controller: _name,
                label: 'Nome completo',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.name,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.name,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _email,
                label: 'E-mail (para login)',
                hint: 'alex.silva@email.com',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _password,
                label: 'Criar senha',
                hint: 'Mínimo 8 caracteres',
                icon: Icons.lock_outline,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: AuthValidators.newPassword,
              ),
              const SizedBox(height: 8),
              TermsCheckboxField(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AuthPrimaryButton(
          label: 'Criar conta e iniciar jornada!',
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
