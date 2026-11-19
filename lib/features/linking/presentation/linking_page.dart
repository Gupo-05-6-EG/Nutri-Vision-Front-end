import 'package:flutter/material.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/presentation/auth_error_message.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../../core/ui/nv_widgets.dart';
import 'link_code_widgets.dart';

class LinkingPage extends StatefulWidget {
  const LinkingPage({
    required this.auth,
    this.scanCode = scanLinkCodeWithCamera,
    super.key,
  });

  final AuthController auth;
  final ScanLinkCode scanCode;

  @override
  State<LinkingPage> createState() => _LinkingPageState();
}

class _LinkingPageState extends State<LinkingPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  LinkedProfessional? _nutritionist;
  bool _loading = false;
  bool _linked = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _findNutritionist() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _nutritionist = null;
    });
    try {
      final professional =
          await widget.auth.linkProfessional(_codeController.text.trim());
      if (!mounted) return;
      if (professional.id == null || !professional.isPending) {
        setState(() => _error = 'A API retornou um vínculo inválido.');
        return;
      }
      setState(() => _nutritionist = professional);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(
          error,
          notFound: 'Código não encontrado. Confira com o seu nutricionista.',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _scan() async {
    final code = await widget.scanCode(context);
    if (code == null || !mounted) return;
    _codeController.text = code;
    await _findNutritionist();
  }

  Future<void> _confirmLink() async {
    final id = _nutritionist?.id;
    if (_loading || id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.acceptLink(id);
      if (!mounted) return;
      setState(() => _linked = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _linked
                  ? _successView(colors)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: BackButton(
                            color: colors.primary,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child:
                              Icon(Icons.link, size: 32, color: colors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Conecte-se ao seu nutricionista',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Digite o c\u{00f3}digo de 6 d\u{00ed}gitos que seu nutricionista compartilhou com voc\u{00ea}.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        Form(
                          key: _formKey,
                          child: LinkCodeField(
                            controller: _codeController,
                            label: 'C\u{00f3}digo de vincula\u{00e7}\u{00e3}o',
                            onSubmitted: (_) => _findNutritionist(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        NvButton(
                          label: 'Escanear QR Code',
                          icon: Icons.qr_code_scanner_rounded,
                          style: NvButtonStyle.neutral,
                          onPressed: _loading ? null : _scan,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: colors.error)),
                        ],
                        const SizedBox(height: 18),
                        AuthPrimaryButton(
                          label: 'Continuar',
                          loading: _loading && _nutritionist == null,
                          onPressed: _findNutritionist,
                        ),
                        if (_nutritionist case final nutritionist?) ...[
                          const SizedBox(height: 28),
                          _NutritionistCard(nutritionist: nutritionist),
                          const SizedBox(height: 18),
                          NvButton(
                            label: 'Confirmar vincula\u{00e7}\u{00e3}o',
                            icon: Icons.check,
                            style: NvButtonStyle.accent,
                            loading: _loading,
                            onPressed: _confirmLink,
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView(ColorScheme colors) => Column(
        children: [
          Icon(Icons.check_circle, size: 72, color: colors.primary),
          const SizedBox(height: 20),
          Text(
            'Vincula\u{00e7}\u{00e3}o conclu\u{00ed}da!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Agora voc\u{00ea} est\u{00e1} conectado ao seu nutricionista.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Concluir',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
}

class _NutritionistCard extends StatelessWidget {
  const _NutritionistCard({required this.nutritionist});

  final LinkedProfessional nutritionist;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors.primaryContainer,
              foregroundImage: nutritionist.photoUrl == null
                  ? null
                  : NetworkImage(nutritionist.photoUrl!),
              child: nutritionist.photoUrl == null
                  ? Icon(Icons.person, color: colors.primary, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voc\u{00ea} vai se conectar com',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nutritionist.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
