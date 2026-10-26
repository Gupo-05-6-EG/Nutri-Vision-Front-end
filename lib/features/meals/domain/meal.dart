/// Refeicoes registradas pelo paciente (`GET /refeicoes/consumo-diario`).
///
/// Instantes chegam da API em UTC com offset explicito; a conversao para a
/// hora local fica com quem exibe (`toLocal()`).
library;

double _number(Object? value) => (value as num).toDouble();

/// Soma de calorias e macros (de uma refeicao ou de um dia).
class NutritionTotals {
  const NutritionTotals({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory NutritionTotals.fromJson(Map<String, dynamic> json) {
    return NutritionTotals(
      kcal: _number(json['calorias_kcal']),
      protein: _number(json['proteinas_g']),
      carbs: _number(json['carboidratos_g']),
      fat: _number(json['gorduras_g']),
    );
  }

  static const zero = NutritionTotals(kcal: 0, protein: 0, carbs: 0, fat: 0);

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

/// Um alimento dentro de uma refeicao.
class MealItem {
  const MealItem({
    required this.id,
    required this.name,
    required this.grams,
    required this.totals,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      id: json['id'] as int,
      name: json['nome_alimento'] as String,
      grams: _number(json['quantidade_g']),
      totals: NutritionTotals.fromJson(json),
    );
  }

  final int id;
  final String name;
  final double grams;
  final NutritionTotals totals;
}

/// Uma refeicao com seus itens e totais (RF04).
class Meal {
  const Meal({
    required this.id,
    required this.consumedAt,
    required this.type,
    required this.items,
    required this.totals,
    this.note,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final items = (json['itens'] as List<dynamic>).cast<Map<String, dynamic>>();
    return Meal(
      id: json['id'] as int,
      consumedAt: DateTime.parse(json['consumida_em'] as String),
      type: json['tipo'] as String,
      note: json['observacao'] as String?,
      items: items.map(MealItem.fromJson).toList(),
      totals: NutritionTotals.fromJson(
        json['totais'] as Map<String, dynamic>,
      ),
    );
  }

  final int id;
  final DateTime consumedAt;

  /// Tipo como a API devolve: `cafe_da_manha`, `almoco`, `lanche` ou `jantar`.
  final String type;
  final String? note;
  final List<MealItem> items;
  final NutritionTotals totals;
}

/// Consumo de um dia com os totais (RF12).
class DailyConsumption {
  const DailyConsumption({required this.meals, required this.totals});

  factory DailyConsumption.fromJson(Map<String, dynamic> json) {
    final meals = (json['refeicoes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Meal.fromJson)
        .toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return DailyConsumption(
      meals: meals,
      totals: NutritionTotals.fromJson(json['totais'] as Map<String, dynamic>),
    );
  }

  /// Refeicoes em ordem cronologica.
  final List<Meal> meals;
  final NutritionTotals totals;
}

/// Rotulo em pt-BR do tipo de refeicao devolvido pela API (RF19).
String mealTypeLabel(String type) {
  switch (type) {
    case 'cafe_da_manha':
      return 'Café da manhã';
    case 'almoco':
      return 'Almoço';
    case 'lanche':
      return 'Lanche';
    case 'jantar':
      return 'Jantar';
  }
  return type;
}
