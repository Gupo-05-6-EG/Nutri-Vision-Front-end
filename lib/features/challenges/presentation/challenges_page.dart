import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';
import 'challenge_leaderboard_page.dart';
import 'create_challenge_page.dart';

/// Tela principal de desafios entre amigos (Task 4.4, RF05.2, RF05.3).
///
/// Lista os convites pendentes para aceitar/recusar, os desafios ativos para
/// acompanhar o placar e permite abrir o fluxo de criacao de novo desafio.
class ChallengesPage extends StatefulWidget {
  const ChallengesPage({
    required this.repository,
    required this.patientId,
    super.key,
  });

  final ChallengeRepository repository;
  final int patientId;

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

enum _Status { loading, success, failure }

class _ChallengesPageState extends State<ChallengesPage> {
  _Status _status = _Status.loading;
  List<Challenge> _challenges = const [];
  final Set<int> _respondingIds = {};
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _Status.loading);
    try {
      final challenges = await widget.repository.listChallenges();
      if (!mounted) return;
      setState(() {
        _status = _Status.success;
        _challenges = challenges;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _Status.failure;
        _errorMessage = error is ApiException && error.statusCode == null
            ? 'Sem conexão com a API. Verifique sua internet.'
            : 'Não foi possível carregar os desafios.';
      });
    }
  }

  Future<void> _respondInvite(
    Challenge challenge, {
    required bool accept,
  }) async {
    if (_respondingIds.contains(challenge.id)) return;
    setState(() => _respondingIds.add(challenge.id));
    try {
      await widget.repository.respondInvite(challenge.id, accept: accept);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Você entrou no desafio "${challenge.name}"!'
                : 'Convite para "${challenge.name}" recusado.',
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível responder ao convite.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _respondingIds.remove(challenge.id));
      }
    }
  }

  Future<void> _openCreateChallenge() async {
    final created = await Navigator.of(context).push<Challenge>(
      MaterialPageRoute<Challenge>(
        builder: (_) => CreateChallengePage(
          repository: widget.repository,
          patientId: widget.patientId,
        ),
      ),
    );
    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Desafio "${created.name}" criado!')),
    );
    await _load();
  }

  Future<void> _openLeaderboard(Challenge challenge) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeLeaderboardPage(
          repository: widget.repository,
          challenge: challenge,
          patientId: widget.patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Desafios entre amigos')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('open-create-challenge'),
        onPressed: _openCreateChallenge,
        icon: const Icon(Icons.add),
        label: const Text('Novo desafio'),
      ),
      body: _buildBody(),
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
        final invites = _challenges
            .where((c) => c.status == ChallengeParticipantStatus.invited)
            .toList(growable: false);
        final active = _challenges
            .where(
              (c) =>
                  c.status == ChallengeParticipantStatus.accepted ||
                  c.status == null,
            )
            .toList(growable: false);

        if (invites.isEmpty && active.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Você ainda não participa de nenhum desafio.\n'
                'Crie um novo desafio para competir com seus amigos!',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final theme = Theme.of(context);
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: [
              if (invites.isNotEmpty) ...[
                Text(
                  'Convites pendentes (${invites.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final invite in invites)
                  _InviteCard(
                    challenge: invite,
                    busy: _respondingIds.contains(invite.id),
                    onAccept: () => _respondInvite(invite, accept: true),
                    onDecline: () => _respondInvite(invite, accept: false),
                  ),
                const SizedBox(height: 16),
              ],
              if (active.isNotEmpty) ...[
                Text(
                  'Meus desafios (${active.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final challenge in active)
                  _ChallengeCard(
                    challenge: challenge,
                    onTap: () => _openLeaderboard(challenge),
                  ),
              ],
            ],
          ),
        );
    }
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.challenge,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final Challenge challenge;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('invite-card-${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(challenge.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${challenge.type.label} · ${challenge.rule}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: Key('decline-challenge-${challenge.id}'),
                  onPressed: busy ? null : onDecline,
                  child: const Text('Recusar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: Key('accept-challenge-${challenge.id}'),
                  onPressed: busy ? null : onAccept,
                  child: const Text('Aceitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.onTap,
  });

  final Challenge challenge;
  final VoidCallback onTap;

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: Key('challenge-card-${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.emoji_events_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(challenge.name),
        subtitle: Text(
          '${challenge.type.label} · '
          '${_formatDate(challenge.startsAt)} a ${_formatDate(challenge.endsAt)}',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
