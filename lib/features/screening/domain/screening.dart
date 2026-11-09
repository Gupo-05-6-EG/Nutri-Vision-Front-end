/// Triagem inicial do paciente (RF14): dados corporais que a API usa para
/// calcular o teto calorico diario pela equacao de Harris-Benedict.
library;

/// Genero escolhido na tela. O prototipo oferece tres opcoes, mas a equacao so
/// tem coeficientes para dois sexos biologicos (ver [CalcSex]).
enum Gender { masculino, feminino, outro }

/// Sexo biologico usado na equacao (valor aceito pela API).
enum CalcSex {
  masculino('masculino'),
  feminino('feminino');

  const CalcSex(this.apiValue);

  final String apiValue;
}

/// Nivel de atividade fisica; define o fator que multiplica a TMB.
enum ActivityLevel {
  sedentario('sedentario', 'Sedentário', 'Pouco ou nenhum exercício'),
  leve('leve', 'Leve', 'Exercício 1 a 3 dias por semana'),
  moderado('moderado', 'Moderado', 'Exercício 3 a 5 dias por semana'),
  intenso('intenso', 'Intenso', 'Exercício 6 a 7 dias por semana'),
  muitoIntenso(
    'muito_intenso',
    'Muito intenso',
    'Treino pesado todo dia ou trabalho físico',
  );

  const ActivityLevel(this.apiValue, this.label, this.description);

  final String apiValue;
  final String label;
  final String description;

  static ActivityLevel? fromApi(String? value) {
    for (final level in values) {
      if (level.apiValue == value) return level;
    }
    return null;
  }
}

/// Respostas da triagem, prontas para enviar a API.
class ScreeningData {
  const ScreeningData({
    required this.age,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
    required this.activity,
    this.calcSex,
  }) : assert(
          gender != Gender.outro || calcSex != null,
          'Com genero "outro", informe o sexo usado no calculo.',
        );

  final int age;
  final Gender gender;

  /// Obrigatorio quando [gender] e [Gender.outro].
  final CalcSex? calcSex;
  final double heightCm;
  final double weightKg;
  final ActivityLevel activity;

  /// Sexo que vai para a equacao.
  CalcSex get sexForCalculation => switch (gender) {
        Gender.masculino => CalcSex.masculino,
        Gender.feminino => CalcSex.feminino,
        Gender.outro => calcSex!,
      };

  /// Corpo do `POST /pacientes/{id}/triagem`.
  Map<String, dynamic> toJson() => {
        'peso_kg': weightKg,
        'altura_cm': heightCm,
        'idade': age,
        'genero': sexForCalculation.apiValue,
        'nivel_atividade': activity.apiValue,
      };
}

/// Resultado da triagem devolvido pela API (`TetoCaloricoOut`).
class CalorieGoal {
  const CalorieGoal({
    required this.patientId,
    required this.basalKcal,
    required this.activityFactor,
    required this.dailyKcal,
    required this.source,
  });

  factory CalorieGoal.fromJson(Map<String, dynamic> json) {
    double number(String key) {
      final value = json[key];
      if (value is num) return value.toDouble();
      throw FormatException('Campo "$key" ausente na resposta da triagem.');
    }

    final id = json['paciente_id'];
    if (id is! int) {
      throw const FormatException('Campo "paciente_id" ausente na resposta.');
    }

    return CalorieGoal(
      patientId: id,
      basalKcal: number('tmb_kcal'),
      activityFactor: number('fator_atividade'),
      dailyKcal: number('teto_calorico_kcal'),
      source: (json['origem_meta'] ?? '').toString(),
    );
  }

  final int patientId;

  /// Taxa metabolica basal (kcal/dia).
  final double basalKcal;
  final double activityFactor;

  /// Teto calorico diario inicial (kcal/dia).
  final double dailyKcal;

  /// Origem da meta (hoje sempre `harris_benedict`).
  final String source;
}
