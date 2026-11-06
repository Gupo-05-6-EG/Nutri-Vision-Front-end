import 'package:flutter/material.dart';

import '../application/auth_controller.dart';
import '../data/auth_models.dart';
import 'auth_error_message.dart';
import 'widgets/auth_widgets.dart';

/// Tela em que o paciente aceita ou recusa o vinculo com o nutricionista
/// (RF14). O vinculo fica `pendente` ate o paciente responder.
class LinkConfirmationPage extends StatefulWidget {
  const LinkConfirmationPage({
    required this.auth,
    required this.professional,
    super.key,
  });

  final AuthController auth;
  final LinkedProfessional professional;

  @override
  State<LinkConfirmationPage> createState() => _LinkConfirmationPageState();
}

class _LinkConfirmationPageState extends State<LinkConfirmationPage> {
  bool _accepting = false;
  bool _refusing = false;
  String? _error;

  bool get _busy => _accepting || _refusing;

  Future<void> _answer({required bool accept}) async {
    final id = widget.professional.id;
    if (id == null || _busy) return;

    setState(() {
      _accepting = accept;
      _refusing = !accept;
      _error = null;
    });

    try {
      if (accept) {
        await widget.auth.acceptLink(id);
      } else {
        await widget.auth.refuseLink(id);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = authErrorMessage(
          error,
          notFound: 'Vínculo não encontrado. Peça um novo código.',
        );
        _accepting = false;
        _refusing = false;
      });
      return;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoUrl = widget.professional.photoUrl;

    return AuthScaffold(
      title: 'Vínculo',
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl),
          child: photoUrl == null ? const Icon(Icons.person, size: 40) : null,
        ),
        const SizedBox(height: 16),
        Text(
          widget.professional.name,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'quer acompanhar você no Nutri Vision. '
          'Aceitar o vínculo?',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          AuthMessageBanner(message: _error!),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Aceitar vínculo',
          loading: _accepting,
          onPressed: _busy ? null : () => _answer(accept: true),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => _answer(accept: false),
          child: _refusing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Recusar'),
        ),
      ],
    );
  }
}
