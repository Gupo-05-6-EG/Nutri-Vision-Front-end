import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../../core/ui/nv_colors.dart';
import '../../../core/ui/nv_widgets.dart';
import '../../shell/presentation/app_routes.dart';
import '../../shell/presentation/main_shell.dart';
import '../data/social_repository.dart';

/// Aba Social do protótipo: Ranking Social da semana entre amigos, convite de
/// amigos pelo e-mail, pedidos de amizade recebidos e atalhos para desafios e
/// conquistas.
class SocialTab extends StatefulWidget {
  const SocialTab({required this.services, this.active = true, super.key});

  final AppServices services;

  /// Se a aba está visível. As abas ficam vivas no `IndexedStack`, então o
  /// ranking é recarregado toda vez que o paciente volta para cá (o XP pode
  /// ter mudado em outra aba).
  final bool active;

  @override
  State<SocialTab> createState() => _SocialTabState();
}

class _SocialTabState extends State<SocialTab> {
  late final SocialRepository _repository = widget.services.social;
  List<RankingEntry>? _ranking;
  List<Friendship> _friendships = const [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(SocialTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _repository.weeklyRanking(),
        _repository.friendships(),
      ]);
      if (!mounted) return;
      setState(() {
        _ranking = results[0] as List<RankingEntry>;
        _friendships = results[1] as List<Friendship>;
        _failed = false;
      });
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _invite() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => InviteFriendSheet(repository: _repository),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Convite enviado!')),
      );
      await _load();
    }
  }

  Future<void> _respond(Friendship request, {required bool accept}) async {
    try {
      await _repository.respond(request.id, accept: accept);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível responder o pedido.')),
      );
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incoming = _friendships.where((f) => f.isIncomingRequest).toList();
    final outgoing = _friendships.where((f) => f.isOutgoingRequest).toList();
    final ranking = _ranking;
    return TabScroll(
      onRefresh: _load,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Ranking Social',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Veja quem está na liderança esta semana!',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 20),
        if (_failed && ranking == null)
          _Notice(
            text: 'Não foi possível carregar o ranking.',
            action: 'Tentar de novo',
            onAction: _load,
          )
        else if (ranking == null)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          for (final entry in ranking)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RankingCard(entry: entry),
            ),
          if (ranking.length <= 1)
            const _Notice(
              text: 'Convide amigos para disputar o ranking da semana.',
            ),
        ],
        const SizedBox(height: 8),
        NvButton(
          label: 'Convidar Amigos',
          icon: Icons.person_add_alt_1_rounded,
          onPressed: _invite,
        ),
        if (incoming.isNotEmpty) ...[
          const SizedBox(height: 24),
          const NvSectionTitle('Pedidos de amizade'),
          for (final request in incoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequestCard(
                request: request,
                onAccept: () => _respond(request, accept: true),
                onRefuse: () => _respond(request, accept: false),
              ),
            ),
        ],
        if (outgoing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Aguardando resposta: ${outgoing.map((f) => f.name).join(', ')}',
            style: theme.textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 24),
        MenuCard(
          icon: Icons.emoji_events_outlined,
          title: 'Desafios entre amigos',
          subtitle: 'Desafie seus amigos por uma semana',
          onTap: () => AppRoutes.challenges(context, widget.services),
        ),
        MenuCard(
          icon: Icons.military_tech_outlined,
          title: 'Minhas conquistas',
          onTap: () => AppRoutes.achievements(context, widget.services),
        ),
      ],
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.entry});

  final RankingEntry entry;

  static const _medals = [
    Color(0xFFFEC700),
    Color(0xFFB8BCC2),
    Color(0xFFC47A3C),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nv = NvColors.of(context);
    final me = entry.isMe;
    final top = entry.position <= 3;
    final foreground =
        me ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;
    final name = me ? 'Você' : entry.name;
    final days = entry.streak == 1 ? '1 dia' : '${entry.streak} dias';
    return NvCard(
      color: me ? theme.colorScheme.primaryContainer : null,
      stepColor: me ? nv.accentStep : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      semanticLabel: '${entry.position}º lugar: $name, '
          '${formatInt(entry.weeklyXp)} XP na semana, ofensiva de $days',
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: top
                  ? Icon(
                      Icons.workspace_premium_rounded,
                      color: _medals[entry.position - 1],
                      size: 32,
                    )
                  : Text(
                      '${entry.position}º',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            NvAvatar(name: entry.name, size: 48, highlight: me),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${formatInt(entry.weeklyXp)} XP',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: me ? foreground : theme.colorScheme.primary,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: me ? foreground : nv.streak,
                          ),
                          Text(
                            days,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color:
                                  me ? foreground : theme.colorScheme.tertiary,
                            ),
                          ),
                        ],
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

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onRefuse,
  });

  final Friendship request;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return NvCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          NvAvatar(name: request.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${request.name} quer ser seu amigo',
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Recusar ${request.name}',
            onPressed: onRefuse,
            icon: Icon(Icons.close, color: theme.colorScheme.error),
          ),
          IconButton.filled(
            tooltip: 'Aceitar ${request.name}',
            onPressed: onAccept,
            icon: const Icon(Icons.check),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Convite de amizade pelo e-mail exato do amigo (BE-09).
class InviteFriendSheet extends StatefulWidget {
  const InviteFriendSheet({required this.repository, super.key});

  final SocialRepository repository;

  @override
  State<InviteFriendSheet> createState() => _InviteFriendSheetState();
}

class _InviteFriendSheetState extends State<InviteFriendSheet> {
  final _email = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Digite um e-mail válido.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repository.invite(email);
      if (mounted) Navigator.of(context).pop(true);
    } on InviteError catch (error) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Convidar amigo', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Digite o e-mail com que seu amigo entrou no Nutri Vision. '
            'Ele recebe o pedido no app e vocês passam a competir no ranking.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              labelText: 'E-mail do amigo',
              prefixIcon: const Icon(Icons.mail_outline),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          NvButton(
            label: 'Enviar convite',
            icon: Icons.send_rounded,
            loading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
