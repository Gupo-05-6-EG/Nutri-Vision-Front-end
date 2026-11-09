/// Plano alimentar prescrito pelo nutricionista
/// (`GET /pacientes/{id}/planos/ativo`).
library;

double _number(Object? value) => (value as num).toDouble();

/// Um alimento previsto em uma refeicao do plano.
class PlanFood {
  const PlanFood({required this.name, required this.grams});

  factory PlanFood.fromJson(Map<String, dynamic> json) {
    return PlanFood(
      name: json['nome_alimento'] as String,
      grams: _number(json['quantidade_g']),
    );
  }

  final String name;
  final double grams;
}

/// Uma refeicao do plano (ex.: "Cafe da manha") com suas metas.
class PlanMeal {
  const PlanMeal({
    required this.name,
    required this.goalKcal,
    required this.goalProtein,
    required this.foods,
    this.time,
    this.note,
  });

  factory PlanMeal.fromJson(Map<String, dynamic> json) {
    final foods = (json['alimentos'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return PlanMeal(
      name: json['nome'] as String,
      time: _hourMinute(json['horario'] as String?),
      goalKcal: _number(json['meta_kcal']),
      goalProtein: _number(json['meta_proteinas_g']),
      note: json['observacao'] as String?,
      foods: foods.map(PlanFood.fromJson).toList(),
    );
  }

  final String name;

  /// `HH:MM`, quando o nutricionista definiu um horario.
  final String? time;
  final double goalKcal;
  final double goalProtein;
  final String? note;
  final List<PlanFood> foods;
}

/// Plano ativo do paciente, com as metas do dia (soma dos blocos).
class MealPlan {
  const MealPlan({
    required this.title,
    required this.goalKcal,
    required this.goalProtein,
    required this.meals,
    this.note,
  });

  factory MealPlan.fromJson(Map<String, dynamic> json) {
    final totals = json['totais'] as Map<String, dynamic>;
    final meals = (json['refeicoes'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return MealPlan(
      title: json['titulo'] as String,
      note: json['observacao'] as String?,
      goalKcal: _number(totals['meta_kcal']),
      goalProtein: _number(totals['meta_proteinas_g']),
      meals: meals.map(PlanMeal.fromJson).toList(),
    );
  }

  final String title;
  final String? note;

  /// Meta de calorias do dia.
  final double goalKcal;

  /// Meta de proteina do dia (o plano nao define metas de carboidrato e
  /// gordura).
  final double goalProtein;
  final List<PlanMeal> meals;
}

/// A API devolve `HH:MM:SS`; a tela mostra so `HH:MM`.
String? _hourMinute(String? time) {
  if (time == null || time.length < 5) return time;
  return time.substring(0, 5);
}
