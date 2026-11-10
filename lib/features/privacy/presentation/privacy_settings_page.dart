import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_error_message.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../data/privacy_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({
    required this.auth,
    required this.repository,
    super.key,
  });

  final AuthController auth;
  final PrivacyRepository repository;

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  PrivacyConsentStatus? _status;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await widget.repository.getConsentStatus();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: destructive
                    ? TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _revokeConsent() async {
    final confirmed = await _confirm(
      title: 'Revogar consentimento?',
      message: 'A revogação será registrada. Algumas funções que dependem '
          'dos seus dados de saúde podem deixar de funcionar.',
      confirmLabel: 'Revogar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.repository.revokeConsent();
      await _loadConsent();
      if (mounted) _showMessage('Consentimento revogado.');
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _exportData() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final data = await widget.repository.exportData();
      final contents = const JsonEncoder.withIndent('  ').convert(data);
      await SharePlus.instance.share(
        ShareParams(
          title: 'Exportação de dados Nutri Vision',
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(contents)),
              mimeType: 'application/json',
              name: 'nutri-vision-dados.json',
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _confirm(
      title: 'Excluir conta e dados?',
      message: 'A exclusão é permanente e não pode ser desfeita. Seus dados '
          'associados à conta serão removidos.',
      confirmLabel: 'Excluir permanentemente',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.repository.deleteAccount();
      await widget.auth.logout();
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} às $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = _status;

    return AuthScaffold(
      title: 'Privacidade e dados',
      alignTop: true,
      children: [
        Text(
          'Gerencie seu consentimento e seus dados pessoais.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (_error != null) ...[
          AuthMessageBanner(message: _error!),
          const SizedBox(height: 16),
        ],
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (status != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status.isActive
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: status.isActive ? colors.primary : colors.error,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          status.isActive
                              ? 'Consentimento ativo'
                              : 'Sem consentimento ativo',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  if (status.consents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Histórico',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    for (final consent in status.consents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Aviso de privacidade ${consent.version}'),
                        subtitle: Text(
                          'Aceito em ${_formatDate(consent.acceptedAt)}'
                          '${consent.revokedAt == null ? '' : '\nRevogado em ${_formatDate(consent.revokedAt!)}'}',
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (status.isActive)
            OutlinedButton.icon(
              onPressed: _working ? null : _revokeConsent,
              icon: const Icon(Icons.block_outlined),
              label: const Text('Revogar consentimento'),
            ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _working ? null : _exportData,
          icon: _working
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
          label: const Text('Exportar meus dados (JSON)'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _working ? null : _deleteAccount,
          style: OutlinedButton.styleFrom(foregroundColor: colors.error),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Excluir conta e dados'),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _loading || _working ? null : _loadConsent,
          icon: const Icon(Icons.refresh),
          label: const Text('Atualizar histórico'),
        ),
      ],
    );
  }
}
