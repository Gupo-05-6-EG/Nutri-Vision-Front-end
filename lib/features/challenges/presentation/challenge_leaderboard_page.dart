import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../foods/domain/number_format.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';

/// Tela de detalhes e placar de um desafio entre amigos (Task 4.4, RF05.2, RF05.3).
class ChallengeLeaderboardPage extends StatefulWidget {
  const ChallengeLeaderboardPage({
    required this.repository,
    required this.challenge,
    required this.patientId,
    super.key,
  });

  final ChallengeRepository repository;
  final Challenge challenge;
  final int patientId;

  @override
  State<ChallengeLeaderboardPage> createState() =>
      _ChallengeLeaderboardPageState();
}

enum _Status { loading, success, failure }

class _ChallengeLeaderboardPageState extends State<ChallengeLeaderboardPage> {
  _Status _status = _Status.loading;
  ChallengeLeaderboard? _leaderboard;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final leaderboard =
          await widget.repository.fetchLeaderboard(widget.challenge.id);
      if (!mounted) return;
      setState(() {
        _status = _Status.success;
        _leaderboard = leaderboard;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _Status.failure;
        _errorMessage = error is ApiException && error.statusCode == null
            ? 'Sem conexão com a API. Verifique sua internet.'
            : 'Não foi possível carregar o placar do desafio.';
      });
    }
  }

  Future<void> _openInviteSheet() async {
    final invited = await showModalBottomSheet<List<ChallengeParticipant>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => InviteFriendsSheet(
        repository: widget.repository,
        challengeId: widget.challenge.id,
        patientId: widget.patientId,
      ),
    );
    if (!mounted || invited == null || invited.isEmpty) return;
    final count = invited.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 1
              ? 'Convite enviado para ${invited.first.name}.'
              : '$count convites enviados com sucesso.',
        ),
      ),
    );
    await _load();
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final challenge = widget.challenge;

    return Scaffold(
      appBar: AppBar(
        title: Text(challenge.name),
        actions: [
          IconButton(
            key: const Key('open-invite-friends'),
            tooltip: 'Convidar amigos',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _openInviteSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            challenge.type.label,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          '${_formatDate(challenge.startsAt)} – '
                          '${_formatDate(challenge.endsAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(challenge.rule, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.loading:
        return const Center(child: CircularProgressIndicator());
      case _Status.failure:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48),
                const SizedBox(height: 12),
                Text(_errorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar de novo'),
                ),
              ],
            ),
          ),
        );
      case _Status.success:
        final entries = _leaderboard!.entries;
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nenhum participante ativo no placar ainda.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: entries.length,
            itemBuilder: (context, index) => _LeaderboardTile(
              entry: entries[index],
              isCurrentUser: entries[index].patientId == widget.patientId,
            ),
          ),
        );
    }
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({
    required this.entry,
    required this.isCurrentUser,
  });

  final LeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreText = entry.score == null
        ? 'Sem pontuação'
        : '${formatNumber(entry.score!)} ${entry.unit}';
    final displayName = isCurrentUser ? '${entry.name} (Você)' : entry.name;

    return Card(
      key: Key('leaderboard-entry-${entry.patientId}'),
      color: isCurrentUser ? theme.colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${entry.position}º'),
        ),
        title: Text(
          displayName,
          style: isCurrentUser
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )
              : theme.textTheme.titleMedium,
        ),
        trailing: Text(
          scoreText,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Folha modal para convidar amigos adicionais a um desafio ja criado.
class InviteFriendsSheet extends StatefulWidget {
  const InviteFriendsSheet({
    required this.repository,
    required this.challengeId,
    required this.patientId,
    super.key,
  });

  final ChallengeRepository repository;
  final int challengeId;
  final int patientId;

  @override
  State<InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<InviteFriendsSheet> {
  final _idController = TextEditingController();
  List<FriendSummary> _friends = const [];
  final Set<int> _selectedIds = {};
  bool _sending = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final friends = await widget.repository.listFriends(widget.patientId);
    if (!mounted) return;
    setState(() => _friends = friends);
  }

  void _addTypedId() {
    final id = int.tryParse(_idController.text.trim());
    if (id == null || id <= 0 || id == widget.patientId) {
      setState(() => _errorText = 'Informe o ID numérico de um amigo.');
      return;
    }
    setState(() {
      _selectedIds.add(id);
      _idController.clear();
      _errorText = null;
    });
  }

  Future<void> _sendInvites() async {
    if (_selectedIds.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _errorText = null;
    });
    try {
      final invited = await widget.repository.inviteFriends(
        widget.challengeId,
        _selectedIds.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(invited);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorText = 'Não foi possível enviar os convites.';
      });
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Convidar amigos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (_friends.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final friend in _friends)
                    FilterChip(
                      key: Key('sheet-friend-chip-${friend.patientId}'),
                      label: Text(friend.displayName),
                      selected: _selectedIds.contains(friend.patientId),
                      onSelected: (_) {
                        setState(() {
                          if (_selectedIds.contains(friend.patientId)) {
                            _selectedIds.remove(friend.patientId);
                          } else {
                            _selectedIds.add(friend.patientId);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('sheet-friend-id-input'),
                    controller: _idController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'ID do amigo',
                      errorText: _errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    key: const Key('sheet-add-friend-button'),
                    onPressed: _addTypedId,
                    child: const Text('Adicionar'),
                  ),
                ),
              ],
            ),
            if (_selectedIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in _selectedIds)
                    InputChip(
                      label: Text('Amigo #$id'),
                      onDeleted: () => setState(() => _selectedIds.remove(id)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('sheet-send-invites-button'),
                onPressed:
                    _selectedIds.isNotEmpty && !_sending ? _sendInvites : null,
                child: const Text('Enviar convites'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
