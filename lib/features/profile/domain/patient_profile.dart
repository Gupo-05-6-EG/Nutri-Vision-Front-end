/// Perfil do paciente devolvido por `GET /pacientes/{id}/perfil` (BE-11).
///
/// `goal` e a meta diaria unica que todas as telas usam: plano ativo do
/// nutricionista, senao a meta da triagem (A4).
class PatientProfile {
  const PatientProfile({
    required this.patientId,
    required this.name,
    required this.email,
    required this.memberSince,
    required this.goal,
    required this.gamification,
    this.age,
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.bmiClass,
    this.bmrKcal,
    this.activityLevel,
    this.nutritionist,
    this.pendingNutritionist,
    this.activePlan,
  });

  factory PatientProfile.fromJson(Map<String, dynamic> json) {
    final nutritionist = json['nutricionista'];
    final pending = json['vinculo_pendente'];
    final plan = json['plano_ativo'];
    return PatientProfile(
      patientId: (json['paciente_id'] as num).toInt(),
      name: json['nome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      memberSince: DateTime.parse(json['membro_desde'] as String).toLocal(),
      age: (json['idade'] as num?)?.toInt(),
      weightKg: _number(json['peso_kg']),
      heightCm: _number(json['altura_cm']),
      bmi: _number(json['imc']),
      bmiClass: json['classificacao_imc'] as String?,
      bmrKcal: _number(json['tmb_kcal']),
      activityLevel: json['nivel_atividade'] as String?,
      goal:
          DailyGoal.fromJson(json['meta'] as Map<String, dynamic>? ?? const {}),
      gamification: Gamification.fromJson(
        json['gamificacao'] as Map<String, dynamic>? ?? const {},
      ),
      nutritionist: nutritionist is Map<String, dynamic>
          ? ProfileNutritionist.fromJson(nutritionist)
          : null,
      pendingNutritionist: pending is Map<String, dynamic>
          ? ProfileNutritionist.fromJson(pending)
          : null,
      activePlan: plan is Map<String, dynamic>
          ? ActivePlanSummary.fromJson(plan)
          : null,
    );
  }

  final int patientId;
  final String name;
  final String email;
  final DateTime memberSince;
  final int? age;
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final String? bmiClass;
  final double? bmrKcal;
  final String? activityLevel;
  final DailyGoal goal;
  final Gamification gamification;
  final ProfileNutritionist? nutritionist;

  /// Convite de vínculo resgatado e ainda não aceito.
  final ProfileNutritionist? pendingNutritionist;
  final ActivePlanSummary? activePlan;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

/// Meta diaria e de onde ela veio.
class DailyGoal {
  const DailyGoal({
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.source,
  });

  factory DailyGoal.fromJson(Map<String, dynamic> json) => DailyGoal(
        kcal: _number(json['kcal']),
        proteinG: _number(json['proteinas_g']),
        carbsG: _number(json['carboidratos_g']),
        fatG: _number(json['gorduras_g']),
        source: GoalSource.fromApi(json['origem'] as String?),
      );

  final double? kcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final GoalSource? source;

  bool get isSet => kcal != null && kcal! > 0;
}

enum GoalSource {
  /// Plano prescrito pelo nutricionista: a meta so muda pelo painel.
  plan,

  /// Calculada na triagem (Harris-Benedict): o paciente pode refazer.
  screening;

  static GoalSource? fromApi(String? value) => switch (value) {
        'plano' => GoalSource.plan,
        'triagem' => GoalSource.screening,
        _ => null,
      };

  String get label => switch (this) {
        GoalSource.plan => 'Definida pelo seu nutricionista',
        GoalSource.screening => 'Calculada pela sua triagem',
      };
}

class Gamification {
  const Gamification({
    this.xp = 0,
    this.streak = 0,
    this.freezes = 0,
    this.division = 'Bronze',
    this.nextDivision,
    this.xpToNext,
    this.mealsLogged = 0,
  });

  factory Gamification.fromJson(Map<String, dynamic> json) => Gamification(
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        streak: (json['ofensiva'] as num?)?.toInt() ?? 0,
        freezes: (json['bloqueios'] as num?)?.toInt() ?? 0,
        division: json['divisao'] as String? ?? 'Bronze',
        nextDivision: json['proxima_divisao'] as String?,
        xpToNext: (json['xp_para_proxima'] as num?)?.toInt(),
        mealsLogged: (json['refeicoes_registradas'] as num?)?.toInt() ?? 0,
      );

  final int xp;
  final int streak;
  final int freezes;
  final String division;
  final String? nextDivision;
  final int? xpToNext;
  final int mealsLogged;
}

class ProfileNutritionist {
  const ProfileNutritionist({
    required this.id,
    required this.name,
    required this.crn,
  });

  factory ProfileNutritionist.fromJson(Map<String, dynamic> json) =>
      ProfileNutritionist(
        id: (json['id'] as num).toInt(),
        name: json['nome'] as String? ?? '',
        crn: json['crn'] as String? ?? '',
      );

  final int id;
  final String name;
  final String crn;
}

class ActivePlanSummary {
  const ActivePlanSummary({
    required this.id,
    required this.title,
    required this.version,
  });

  factory ActivePlanSummary.fromJson(Map<String, dynamic> json) =>
      ActivePlanSummary(
        id: (json['id'] as num).toInt(),
        title: json['titulo'] as String? ?? '',
        version: (json['versao'] as num?)?.toInt() ?? 1,
      );

  final int id;
  final String title;
  final int version;
}

double? _number(Object? value) => value is num ? value.toDouble() : null;
