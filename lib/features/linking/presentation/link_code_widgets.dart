import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/ui/nv_widgets.dart';
import '../../auth/presentation/auth_validators.dart';

/// Lê o código de 6 dígitos de um QR Code do painel do nutricionista.
///
/// O painel gera `nutrivision://vinculo?codigo=123456`, mas qualquer texto com
/// exatamente 6 dígitos seguidos vale (ex.: só "123456").
String? parseLinkCode(String? raw) {
  if (raw == null) return null;
  final fromUri = Uri.tryParse(raw.trim())?.queryParameters['codigo'];
  final candidate = fromUri ?? raw;
  final match = RegExp(r'(?<!\d)(\d{6})(?!\d)').firstMatch(candidate);
  return match?.group(1);
}

/// Abre o leitor e devolve o código lido (ou `null`).
typedef ScanLinkCode = Future<String?> Function(BuildContext context);

Future<String?> scanLinkCodeWithCamera(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const QrScanPage(),
    ),
  );
}

/// Código do nutricionista em 6 caixas, como no protótipo.
///
/// Por baixo é um único campo de texto (acessível e com o teclado numérico):
/// as caixas só desenham os dígitos digitados.
class LinkCodeField extends StatefulWidget {
  const LinkCodeField({
    required this.controller,
    this.onSubmitted,
    this.label = 'Código de 6 dígitos',
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final String label;

  @override
  State<LinkCodeField> createState() => _LinkCodeFieldState();
}

class _LinkCodeFieldState extends State<LinkCodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  static const _boxHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = widget.controller.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Digite o código de 6 dígitos:',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            // O campo de verdade fica por baixo, invisível: ele recebe o
            // toque, o teclado, a validação e a mensagem de erro.
            TextFormField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              enableSuggestions: false,
              showCursor: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: AuthValidators.linkCode,
              onFieldSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                labelText: widget.label,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                labelStyle: const TextStyle(color: Colors.transparent),
                filled: false,
                constraints: const BoxConstraints(minHeight: _boxHeight),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: _boxHeight / 2,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: _boxHeight,
              child: IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _Box(
                          digit: i < text.length ? text[i] : null,
                          active: _focus.hasFocus &&
                              (i == text.length ||
                                  (i == 5 && text.length == 6)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active});

  final String? digit;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? scheme.primary : scheme.surfaceContainerHighest,
            width: active ? 2.5 : 2,
          ),
        ),
        child: Text(
          digit ?? '',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Leitor do QR Code do vínculo (câmera, no celular e no navegador).
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  bool _done = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = parseLinkCode(barcode.rawValue);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear QR Code')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Não foi possível abrir a câmera. Digite o código de 6 '
                  'dígitos que o seu nutricionista passou.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: NvCard(
                child: Text(
                  'Aponte para o QR Code mostrado no painel do nutricionista.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quem gerou o código: mostrado antes de criar a conta (protótipo).
class ProfessionalPreviewCard extends StatelessWidget {
  const ProfessionalPreviewCard({
    required this.name,
    this.crn,
    this.caption = 'Nutricionista vinculado',
    super.key,
  });

  final String name;
  final String? crn;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NvCard(
      semanticLabel: '$caption: $name${crn == null ? '' : ', $crn'}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            NvAvatar(name: name, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, style: theme.textTheme.labelMedium),
                  Text(name, style: theme.textTheme.titleMedium),
                  if (crn != null)
                    Row(
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            crn!,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
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
