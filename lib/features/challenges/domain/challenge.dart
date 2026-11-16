/// Modelos de dominio para desafios sociais entre amigos (Task 4.4, RF05.2, RF05.3).
library;

/// Tipos de desafio suportados pela API (`TipoDesafio` no back-end).
enum ChallengeType {
  meals(
    'refeicoes',
    'Refeições registradas',
    'Quem registrar mais refeições no período vence.',
  ),
  calorieVariation(
    'variacao_calorica',
    'Variação calórica',
    'Quem mantiver a menor variação calórica diária em relação à meta vence.',
  ),
  goalStreak(
    'sequencia_meta',
    'Sequência na meta',
    'Quem acumular mais dias consecutivos dentro da meta calórica vence.',
  );

  const ChallengeType(this.apiValue, this.label, this.defaultRule);

  final String apiValue;
  final String label;
  final String defaultRule;

  static ChallengeType fromApi(String? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    throw FormatException('Tipo de desafio desconhecido: $value');
  }
}

/// Situacao do paciente em um desafio (`StatusParticipante` no back-end).
enum ChallengeParticipantStatus {
  invited('convidado', 'Convite pendente'),
  accepted('aceito', 'Participando'),
  declined('recusado', 'Recusado');

  const ChallengeParticipantStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ChallengeParticipantStatus? fromApi(String? value) {
    if (value == null) return null;
    for (final status in values) {
      if (status.apiValue == value) return status;
    }
    return null;
  }
}

/// Um desafio social entre amigos (`DesafioOut`).
class Challenge {
  const Challenge({
    required this.id,
    required this.name,
    required this.type,
    required this.rule,
    required this.startsAt,
    required this.endsAt,
    this.status,
  });

  factory Challenge.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final nome = json['nome'];
    final tipo = json['tipo'];
    final regra = json['regra'];
    final inicioEm = json['inicio_em'];
    final fimEm = json['fim_em'];
    if (id is! num ||
        nome is! String ||
        tipo is! String ||
        regra is! String ||
        inicioEm is! String ||
        fimEm is! String) {
      throw const FormatException(' Desafio invalido na resposta da API.');
    }

    return Challenge(
      id: id.toInt(),
      name: nome,
      type: ChallengeType.fromApi(tipo),
      rule: regra,
      startsAt: DateTime.parse(inicioEm),
      endsAt: DateTime.parse(fimEm),
      status: ChallengeParticipantStatus.fromApi(json['status'] as String?),
    );
  }

  final int id;
  final String name;
  final ChallengeType type;
  final String rule;
  final DateTime startsAt;
  final DateTime endsAt;
  final ChallengeParticipantStatus? status;

  Challenge copyWith({ChallengeParticipantStatus? status}) => Challenge(
        id: id,
        name: name,
        type: type,
        rule: rule,
        startsAt: startsAt,
        endsAt: endsAt,
        status: status ?? this.status,
      );
}

/// Dados para criar um novo desafio (`DesafioCriarIn`).
class ChallengeDraft {
  const ChallengeDraft({
    required this.name,
    required this.type,
    required this.rule,
    required this.startsAt,
    required this.endsAt,
    this.invitedIds = const [],
  });

  final String name;
  final ChallengeType type;
  final String rule;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<int> invitedIds;

  Map<String, Object> toJson() => {
        'nome': name.trim(),
        'tipo': type.apiValue,
        'regra': rule.trim(),
        'inicio_em': startsAt.toUtc().toIso8601String(),
        'fim_em': endsAt.toUtc().toIso8601String(),
        'convidados': invitedIds,
      };
}

/// Participante convidado ou confirmado em um desafio (`ParticipanteOut`).
class ChallengeParticipant {
  const ChallengeParticipant({
    required this.patientId,
    required this.name,
    required this.status,
  });

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    final patientId = json['paciente_id'];
    final name = json['nome'];
    final statusRaw = json['status'];
    if (patientId is! num || name is! String || statusRaw is! String) {
      throw const FormatException('Participante invalido na resposta da API.');
    }
    final status = ChallengeParticipantStatus.fromApi(statusRaw);
    if (status == null) {
      throw FormatException('Status de participante desconhecido: $statusRaw');
    }
    return ChallengeParticipant(
      patientId: patientId.toInt(),
      name: name,
      status: status,
    );
  }

  final int patientId;
  final String name;
  final ChallengeParticipantStatus status;
}

/// Linha do placar de um desafio (`PlacarItemOut`).
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.position,
    required this.patientId,
    required this.name,
    required this.unit,
    this.score,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final position = json['posicao'];
    final patientId = json['paciente_id'];
    final name = json['nome'];
    final unit = json['unidade'];
    final rawScore = json['pontuacao'];
    if (position is! num ||
        patientId is! num ||
        name is! String ||
        unit is! String) {
      throw const FormatException('Item de placar invalido.');
    }
    return LeaderboardEntry(
      position: position.toInt(),
      patientId: patientId.toInt(),
      name: name,
      score: rawScore is num ? rawScore.toDouble() : null,
      unit: unit,
    );
  }

  final int position;
  final int patientId;
  final String name;
  final double? score;
  final String unit;
}

/// Placar completo de um desafio (`PlacarOut`).
class ChallengeLeaderboard {
  const ChallengeLeaderboard({
    required this.challengeId,
    required this.type,
    required this.entries,
  });

  factory ChallengeLeaderboard.fromJson(Map<String, dynamic> json) {
    final challengeId = json['desafio_id'];
    final tipo = json['tipo'];
    final list = json['participantes'];
    if (challengeId is! num || tipo is! String || list is! List) {
      throw const FormatException('Placar invalido na resposta da API.');
    }
    return ChallengeLeaderboard(
      challengeId: challengeId.toInt(),
      type: ChallengeType.fromApi(tipo),
      entries: [
        for (final item in list)
          LeaderboardEntry.fromJson(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  final int challengeId;
  final ChallengeType type;
  final List<LeaderboardEntry> entries;
}

/// Resumo de um amigo para selecao rapida ao convidar para um desafio.
class FriendSummary {
  const FriendSummary({
    required this.patientId,
    required this.displayName,
    this.streak = 0,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> json) {
    final patientId = (json['paciente_id'] as num).toInt();
    final rawName =
        (json['username'] as String?) ?? (json['nome'] as String?) ?? '';
    final cleanName = rawName.trim();
    return FriendSummary(
      patientId: patientId,
      displayName: cleanName.isEmpty ? 'Paciente #$patientId' : cleanName,
      streak: (json['streak'] as num?)?.toInt() ?? 0,
    );
  }

  final int patientId;
  final String displayName;
  final int streak;
}
