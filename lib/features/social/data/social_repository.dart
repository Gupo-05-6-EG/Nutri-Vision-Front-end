import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Posição no ranking semanal entre amigos (`GET /gamificacao/leaderboard`).
class RankingEntry {
  const RankingEntry({
    required this.position,
    required this.patientId,
    required this.name,
    required this.weeklyXp,
    required this.streak,
    required this.isMe,
  });

  factory RankingEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['paciente_id'] as num).toInt();
    final name = (json['nome'] as String?)?.trim();
    final username = (json['username'] as String?)?.trim();
    return RankingEntry(
      position: (json['posicao'] as num).toInt(),
      patientId: id,
      name: (name?.isNotEmpty ?? false)
          ? name!
          : ((username?.isNotEmpty ?? false) ? username! : 'Amigo'),
      weeklyXp: (json['xp_semanal'] as num?)?.toInt() ?? 0,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      isMe: json['e_voce'] as bool? ?? false,
    );
  }

  final int position;
  final int patientId;
  final String name;
  final int weeklyXp;
  final int streak;
  final bool isMe;
}

enum FriendshipStatus { pending, accepted, refused }

/// Amigo ou pedido de amizade (`GET /amizades`).
class Friendship {
  const Friendship({
    required this.id,
    required this.patientId,
    required this.name,
    required this.status,
    required this.sentByMe,
    this.streak = 0,
    this.xp = 0,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    final name = (json['nome'] as String?)?.trim() ?? '';
    return Friendship(
      id: (json['id'] as num).toInt(),
      patientId: (json['paciente_id'] as num).toInt(),
      name: name.isEmpty ? 'Amigo' : name,
      status: switch (json['status']) {
        'aceito' => FriendshipStatus.accepted,
        'recusado' => FriendshipStatus.refused,
        _ => FriendshipStatus.pending,
      },
      sentByMe: json['sou_solicitante'] as bool? ?? false,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
      xp: (json['xp'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final int patientId;
  final String name;
  final FriendshipStatus status;
  final bool sentByMe;
  final int streak;
  final int xp;

  bool get isIncomingRequest => status == FriendshipStatus.pending && !sentByMe;
  bool get isOutgoingRequest => status == FriendshipStatus.pending && sentByMe;
}

/// Convite de amizade recusado pela API, com a mensagem para o paciente.
class InviteError implements Exception {
  const InviteError(this.message);

  final String message;
}

/// Ranking semanal e amizades (BE-01, BE-08, BE-09). Tudo em nome do paciente
/// logado: a API lê o paciente do token.
class SocialRepository {
  const SocialRepository(this._client);

  static const leaderboardPath = '/gamificacao/leaderboard';
  static const friendsPath = '/amizades';

  final ApiClient _client;

  Future<List<RankingEntry>> weeklyRanking() async {
    final response = await _client.get(leaderboardPath, query: {'limite': 20});
    final items =
        (response as Map<String, dynamic>)['ranking'] as List<dynamic>;
    return [
      for (final item in items)
        RankingEntry.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  Future<List<Friendship>> friendships() async {
    final response = await _client.get(friendsPath);
    return [
      for (final item in response as List<dynamic>)
        Friendship.fromJson(Map<String, dynamic>.from(item as Map)),
    ];
  }

  /// Convida pelo e-mail com que o amigo se cadastrou.
  Future<void> invite(String email) async {
    try {
      await _client.post(friendsPath, {'email': email.trim()});
    } on ApiException catch (error) {
      throw InviteError(
        switch (error.statusCode) {
          404 => 'Não encontramos ninguém com esse e-mail no Nutri Vision.',
          409 => _detail(error.message).contains('pendente')
              ? 'Você já enviou um convite para essa pessoa.'
              : 'Vocês já são amigos.',
          422 => _detail(error.message).contains('si mesmo')
              ? 'Esse é o seu e-mail.'
              : 'Digite um e-mail válido.',
          null => 'Sem conexão. Tente de novo.',
          _ => 'Não foi possível enviar o convite.',
        },
      );
    }
  }

  Future<void> respond(int friendshipId, {required bool accept}) =>
      _client.put('$friendsPath/$friendshipId/responder', {'aceitar': accept});

  Future<void> remove(int friendshipId) =>
      _client.delete('$friendsPath/$friendshipId');

  static String _detail(String body) {
    try {
      final detail = (jsonDecode(body) as Map<String, dynamic>)['detail'];
      return detail is String ? detail.toLowerCase() : '';
    } on Object {
      return body.toLowerCase();
    }
  }
}
