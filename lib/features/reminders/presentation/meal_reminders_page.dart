import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_error_message.dart';
import '../../meals/domain/meal_type.dart';
import '../application/push_service.dart';
import '../data/reminder_repository.dart';
import '../domain/meal_reminder.dart';

/// Abre o seletor de horario; trocado nos testes.
typedef ReminderTimePicker = Future<TimeOfDay?> Function(
  BuildContext context,
  TimeOfDay initial,
);

/// Configuracao dos lembretes de refeicao (RF26).
///
/// Um lembrete por tipo de refeicao, com horario e liga/desliga. O push e
/// enviado pelo back-end so se a refeicao ainda nao foi registrada. Ao salvar
/// com algum lembrete ligado, pede a permissao de notificacao.
class MealRemindersPage extends StatefulWidget {
  const MealRemindersPage({
    required this.repository,
    required this.patientId,
    required this.push,
    this.pickTime,
    super.key,
  });

  final ReminderRepository repository;
  final int patientId;
  final PushService push;

  /// Seletor de horario; existe para os testes nao dependerem do relogio
  /// do `showTimePicker`.
  final ReminderTimePicker? pickTime;

  @override
  State<MealRemindersPage> createState() => _MealRemindersPageState();
}

enum _Status { loading, failure, ready }

class _MealRemindersPageState extends State<MealRemindersPage> {
  _Status _status = _Status.loading;
  String _errorMessage = '';

  /// Como esta na API.
  List<MealReminder> _saved = const [];

  /// Como esta na tela.
  List<MealReminder> _draft = const [];

  bool _saving = false;
  PushPermission? _permission;

  bool get _hasChanges => !listEquals(_saved, _draft);

  @override
  void initState() {
    super.initState();
    _load();
    _refreshPermission();
  }

  String _describe(Object error) => authErrorMessage(
        error,
        unauthorized: AuthController.sessionExpiredMessage,
        notFound: 'Não encontramos seu cadastro. Entre novamente.',
      );

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final reminders = await widget.repository.fetch(widget.patientId);
      if (!mounted) return;
      setState(() {
        _saved = reminders;
        _draft = reminders;
        _status = _Status.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _describe(error);
        _status = _Status.failure;
      });
    }
  }

  Future<void> _refreshPermission() async {
    try {
      final permission = await widget.push.permissionStatus();
      if (mounted) setState(() => _permission = permission);
    } catch (_) {
      // Sem a situacao da permissao, a tela so nao mostra o aviso.
    }
  }

  Future<void> _requestPermission() async {
    try {
      final permission = await widget.push.requestPermission();
      if (mounted) setState(() => _permission = permission);
    } catch (_) {
      // O pedido falhou: mantem o aviso como estava.
    }
  }

  void _replace(MealReminder reminder) {
    setState(() {
      _draft = [
        for (final current in _draft)
          current.type == reminder.type ? reminder : current,
      ];
    });
  }

  Future<void> _pickTime(MealReminder reminder) async {
    final picker = widget.pickTime ?? _showPicker;
    final picked = await picker(
      context,
      TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (picked == null || !mounted) return;
    _replace(reminder.copyWith(hour: picked.hour, minute: picked.minute));
  }

  static Future<TimeOfDay?> _showPicker(
    BuildContext context,
    TimeOfDay initial,
  ) =>
      showTimePicker(
        context: context,
        initialTime: initial,
        helpText: 'Horário do lembrete',
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
      );

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await widget.repository.save(widget.patientId, _draft);
      if (!mounted) return;
      setState(() {
        _saved = saved;
        _draft = saved;
        _saving = false;
      });
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Lembretes salvos.')));
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_describe(error))));
      return;
    }

    // Pede a permissao quando ela passa a fazer sentido: ha lembrete ligado.
    final canAsk = _permission == PushPermission.notDetermined ||
        _permission == PushPermission.denied;
    if (canAsk && _saved.any((reminder) => reminder.enabled)) {
      await _requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes de refeição')),
      body: switch (_status) {
        _Status.loading => const Center(child: CircularProgressIndicator()),
        _Status.failure => _Message(
            icon: Icons.cloud_off,
            text: _errorMessage,
            onRetry: _load,
          ),
        _Status.ready => _buildList(context),
      },
      bottomNavigationBar: _status == _Status.ready
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _hasChanges && !_saving ? _save : null,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Salvar'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildList(BuildContext context) {
    // Ainda nao respondida: nada a avisar, o pedido sai ao salvar.
    final permission = _permission;
    final showNotice = permission != null &&
        permission != PushPermission.granted &&
        permission != PushPermission.notDetermined;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (showNotice) ...[
          _PermissionNotice(
            permission: permission,
            onAllow: _requestPermission,
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Escolha quando quer ser lembrado de registrar cada refeição. '
          'O lembrete só chega se você ainda não tiver registrado aquela '
          'refeição, no máximo uma vez por dia.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (final reminder in _draft)
          _ReminderCard(
            reminder: reminder,
            enabled: !_saving,
            onToggle: (value) => _replace(reminder.copyWith(enabled: value)),
            onPickTime: () => _pickTime(reminder),
          ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.enabled,
    required this.onToggle,
    required this.onPickTime,
  });

  final MealReminder reminder;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onPickTime;

  static IconData _icon(MealType type) => switch (type) {
        MealType.breakfast => Icons.free_breakfast_outlined,
        MealType.lunch => Icons.lunch_dining_outlined,
        MealType.snack => Icons.bakery_dining_outlined,
        MealType.dinner => Icons.dinner_dining_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final type = reminder.type;
    final time = reminder.formattedTime;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(_icon(type)),
          title: Text(type.label),
          subtitle: Text(reminder.enabled ? 'Lembrete às $time' : 'Desligado'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: ValueKey('reminder-time-${type.apiValue}'),
                onPressed: enabled ? onPickTime : null,
                child: Text(
                  time,
                  semanticsLabel:
                      'Horário do ${type.label.toLowerCase()}: $time. Alterar',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Switch(
                key: ValueKey('reminder-switch-${type.apiValue}'),
                value: reminder.enabled,
                onChanged: enabled ? onToggle : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({required this.permission, required this.onAllow});

  final PushPermission permission;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (text, canAllow) = switch (permission) {
      PushPermission.denied => (
          'As notificações estão desativadas. Sem elas os lembretes não '
              'aparecem no seu celular.',
          true,
        ),
      PushPermission.permanentlyDenied => (
          'As notificações estão bloqueadas. Ative-as nas configurações do '
              'aparelho para receber os lembretes.',
          false,
        ),
      _ => (
          'Notificações indisponíveis neste aparelho. Os horários ficam '
              'salvos, mas os lembretes não chegam aqui.',
          false,
        ),
    };

    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ),
              ],
            ),
            if (canAllow)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onAllow,
                  child: const Text('Permitir notificações'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar de novo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
