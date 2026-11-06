import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/auth_controller.dart';
import 'auth_validators.dart';
import 'linked_signup_page.dart';
import 'widgets/auth_widgets.dart';

/// Passo 1 do cadastro "Tenho nutricionista": codigo de 6 digitos.
///
/// A API so resgata o codigo depois do cadastro (precisa do token do
/// paciente), entao aqui o codigo so e validado no formato.
class LinkCodePage extends StatefulWidget {
  const LinkCodePage({required this.auth, super.key});

  final AuthController auth;

  @override
  State<LinkCodePage> createState() => _LinkCodePageState();
}

class _LinkCodePageState extends State<LinkCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinkedSignupPage(
          auth: widget.auth,
          linkCode: _code.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AuthScaffold(
      title: 'Cadastro',
      children: [
        Icon(
          Icons.medical_services_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'Bem-vindo! Vincular ao nutricionista',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Insira o código de 6 dígitos fornecido pelo seu nutricionista '
          'para iniciar o acompanhamento.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: AuthTextField(
            controller: _code,
            label: 'Código de 6 dígitos',
            hint: '000000',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: AuthValidators.linkCode,
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(label: 'Continuar', onPressed: _submit),
        const SizedBox(height: 16),
        Text(
          'Ainda não tem o código? Solicite ao seu profissional.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
