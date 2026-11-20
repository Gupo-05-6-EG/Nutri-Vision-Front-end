import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../linking/presentation/link_code_widgets.dart';
import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_error_message.dart';
import 'linked_signup_page.dart';
import 'widgets/auth_widgets.dart';

/// Passo 1 do cadastro "Tenho nutricionista": código de 6 dígitos (ou QR Code).
///
/// O código é conferido na prévia pública da API, que mostra quem é o
/// profissional antes de o paciente criar a conta. O resgate de verdade só
/// acontece depois do cadastro (precisa do token do paciente).
class LinkCodePage extends StatefulWidget {
  const LinkCodePage({
    required this.auth,
    this.scanCode = scanLinkCodeWithCamera,
    super.key,
  });

  final AuthController auth;
  final ScanLinkCode scanCode;

  @override
  State<LinkCodePage> createState() => _LinkCodePageState();
}

class _LinkCodePageState extends State<LinkCodePage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await widget.scanCode(context);
    if (code == null || !mounted) return;
    _code.text = code;
    await _submit();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    final code = _code.text.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    final ProfessionalPreview preview;
    try {
      preview = await widget.auth.previewLinkCode(code);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.statusCode == 404
            ? 'Código inválido ou expirado. Peça um novo ao seu nutricionista.'
            : authErrorMessage(error);
      });
      return;
    }
    if (!mounted) return;
    setState(() => _loading = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LinkedSignupPage(
          auth: widget.auth,
          linkCode: code,
          professional: preview,
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
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 32,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bem-vindo! Vincular ao Nutricionista',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Insira o código de 6 dígitos fornecido pelo seu nutricionista '
          'ou escaneie o QR Code do painel dele.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: LinkCodeField(
            controller: _code,
            onSubmitted: (_) => _submit(),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          AuthMessageBanner(message: _error!),
        ],
        const SizedBox(height: 20),
        AuthPrimaryButton(
          label: 'Continuar',
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('ou', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        NvButton(
          label: 'Escanear QR Code',
          icon: Icons.qr_code_scanner_rounded,
          style: NvButtonStyle.neutral,
          onPressed: _loading ? null : _scan,
        ),
        const SizedBox(height: 16),
        Text(
          'Ainda não tem o código? Solicite ao seu profissional.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
