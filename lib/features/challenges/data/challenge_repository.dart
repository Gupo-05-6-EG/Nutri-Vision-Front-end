import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/challenge.dart';

/// Acesso aos endpoints de desafios entre amigos e placares (Task 4.4 [Back], RF05.2, RF05.3).
class ChallengeRepository {
  const ChallengeRepository(this._client);

  static const String challengesPath = '/challenges';
  static const String friendsPath = '/amizades';

  static String invitesPath(int challengeId) =>
      '$challengesPath/$challengeId/invites';

  static String responsePath(int challengeId) =>
      '$challengesPath/$challengeId/response';

  static String leaderboardPath(int challengeId) =>
      '$challengesPath/$challengeId/leaderboard';

  final ApiClient _client;

  /// Lista todos os desafios e convites do paciente autenticado.
  Future<List<Challenge>> listChallenges() async {
    final response = await _client.get(challengesPath);
    if (response is! List) {
      throw const ApiException('Resposta inesperada da lista de desafios.');
    }
    try {
      return [
        for (final item in response)
          Challenge.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on FormatException catch (error) {
      throw ApiException(error.message);
    } on TypeError {
      throw const ApiException('Resposta inesperada da lista de desafios.');
    }
  }

  /// Cria um novo desafio e envia os convites iniciais (`POST /challenges`).
  Future<Challenge> createChallenge(ChallengeDraft draft) async {
    final response = await _client.post(challengesPath, draft.toJson());
    if (response is! Map) {
      throw const ApiException('Resposta inesperada ao criar desafio.');
    }
    try {
      return Challenge.fromJson(Map<String, dynamic>.from(response));
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  /// Convida novos amigos para um desafio existente (`POST /challenges/{id}/invites`).
  Future<List<ChallengeParticipant>> inviteFriends(
    int challengeId,
    List<int> patientIds,
  ) async {
    final response = await _client.post(invitesPath(challengeId), {
      'pacientes': patientIds,
    });
    if (response is! List) {
      throw const ApiException('Resposta inesperada ao enviar convites.');
    }
    try {
      return [
        for (final item in response)
          ChallengeParticipant.fromJson(Map<String, dynamic>.from(item as Map)),
      ];
    } on FormatException catch (error) {
      throw ApiException(error.message);
    } on TypeError {
      throw const ApiException('Resposta inesperada ao enviar convites.');
    }
  }

  /// Aceita ou recusa um convite de desafio (`POST /challenges/{id}/response`).
  Future<ChallengeParticipant> respondInvite(
    int challengeId, {
    required bool accept,
  }) async {
    final response = await _client.post(responsePath(challengeId), {
      'aceitar': accept,
    });
    if (response is! Map) {
      throw const ApiException('Resposta inesperada ao responder convite.');
    }
    try {
      return ChallengeParticipant.fromJson(
        Map<String, dynamic>.from(response),
      );
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  /// Obtem o placar atualizado do desafio (`GET /challenges/{id}/leaderboard`).
  Future<ChallengeLeaderboard> fetchLeaderboard(int challengeId) async {
    final response = await _client.get(leaderboardPath(challengeId));
    if (response is! Map) {
      throw const ApiException('Resposta inesperada do placar.');
    }
    try {
      return ChallengeLeaderboard.fromJson(
        Map<String, dynamic>.from(response),
      );
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }

  /// Lista os amigos aceitos do paciente para facilitar o convite nos desafios.
  ///
  /// Se o modulo social nao estiver disponivel ou falhar, devolve lista vazia
  /// para que o paciente ainda possa convidar pelo ID.
  Future<List<FriendSummary>> listFriends(int patientId) async {
    try {
      final response = await _client.get(
        friendsPath,
        query: {'paciente_id': patientId, 'status': 'aceito'},
      );
      if (response is! List) return const [];
      return [
        for (final item in response)
          if (item is Map && item['paciente_id'] is num)
            FriendSummary.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return const [];
    }
  }
}
