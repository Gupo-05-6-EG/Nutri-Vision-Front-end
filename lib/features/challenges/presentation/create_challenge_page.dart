import 'package:flutter/material.dart';

import '../../../core/ui/nv_widgets.dart';

import '../../../core/network/api_exception.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';

/// Tela para criar um novo desafio entre amigos, escolher o tipo e convidar
/// participantes (Task 4.4, RF05.2).
class CreateChallengePage extends StatefulWidget {
  const CreateChallengePage({
    required this.repository,
    required this.patientId,
    this.now,
    super.key,
  });

  final ChallengeRepository repository;
  final int patientId;

  /// Instante base para inicio do desafio (injetavel nos testes).
  final DateTime? now;

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  final _nameController = TextEditingController();
  late final _ruleController = TextEditingController(
    text: ChallengeType.meals.defaultRule,
  );
  final _durationController = TextEditingController(text: '7');

  ChallengeType _type = ChallengeType.meals;
  bool _ruleCustomized = false;
  bool _saving = false;

  List<FriendSummary> _friends = const [];
  final Set<int> _selectedFriendIds = {};

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ruleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final friends = await widget.repository.listFriends(widget.patientId);
    if (!mounted) return;
    setState(() => _friends = friends);
  }

  int? get _durationDays {
    final parsed = int.tryParse(_durationController.text.trim());
    if (parsed == null || parsed <= 0 || parsed > 365) return null;
    return parsed;
  }

  bool get _canSubmit =>
      !_saving &&
      _nameController.text.trim().isNotEmpty &&
      _ruleController.text.trim().isNotEmpty &&
      _durationDays != null;

  void _selectType(ChallengeType type) {
    setState(() {
      _type = type;
      if (!_ruleCustomized || _ruleController.text.trim().isEmpty) {
        _ruleController.text = type.defaultRule;
        _ruleCustomized = false;
      }
    });
  }

  void _toggleFriend(int friendId) {
    setState(() {
      if (_selectedFriendIds.contains(friendId)) {
        _selectedFriendIds.remove(friendId);
      } else {
        _selectedFriendIds.add(friendId);
      }
    });
  }

  Future<void> _submit() async {
    final days = _durationDays;
    if (!_canSubmit || days == null) return;

    setState(() => _saving = true);
    final startsAt = (widget.now ?? DateTime.now()).toUtc();
    final endsAt = startsAt.add(Duration(days: days));

    try {
      final created = await widget.repository.createChallenge(
        ChallengeDraft(
          name: _nameController.text.trim(),
          type: _type,
          rule: _ruleController.text.trim(),
          startsAt: startsAt,
          endsAt: endsAt,
          invitedIds: _selectedFriendIds.toList(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      final message = error is ApiException && error.statusCode == null
          ? 'Sem conexão com a API. Verifique sua internet.'
          : 'Não foi possível criar o desafio. Confira os dados e tente novamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Criar desafio')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('challenge-name-input'),
            controller: _nameController,
            maxLength: 120,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nome do desafio',
              hintText: 'Ex.: Semana Foco Total',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ChallengeType>(
            key: const Key('challenge-type-selector'),
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Tipo do desafio',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final type in ChallengeType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                ),
            ],
            onChanged: (type) {
              if (type != null) _selectType(type);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('challenge-rule-input'),
            controller: _ruleController,
            maxLines: 2,
            maxLength: 500,
            onChanged: (_) {
              _ruleCustomized = true;
              setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Regra do desafio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('challenge-duration-days'),
            controller: _durationController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Duração (dias)',
              suffixText: 'dias',
              errorText: _durationController.text.trim().isEmpty ||
                      _durationDays != null
                  ? null
                  : 'Use entre 1 e 365 dias.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Convidar amigos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_friends.isEmpty)
            Text(
              'Você ainda não tem amigos no app. Convide pelo e-mail na aba '
              'Social e eles aparecem aqui.',
              style: theme.textTheme.bodySmall,
            ),
          if (_friends.isNotEmpty) ...[
            Text(
              'Toque nos amigos que deseja convidar:',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final friend in _friends)
                  FilterChip(
                    key: Key('friend-chip-${friend.patientId}'),
                    avatar: NvAvatar(name: friend.displayName, size: 24),
                    label: Text(friend.displayName),
                    selected: _selectedFriendIds.contains(friend.patientId),
                    onSelected: (_) => _toggleFriend(friend.patientId),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('submit-create-challenge'),
            onPressed: _canSubmit ? _submit : null,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.emoji_events_outlined),
            label: const Text('Criar desafio'),
          ),
        ],
      ),
    );
  }
}
