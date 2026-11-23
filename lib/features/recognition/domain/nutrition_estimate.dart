import 'detected_item.dart';

double _number(Object? value) => (value as num).toDouble();

/// Um item calculado por `POST /calculo-nutricional`, ja mapeado para a TACO.
class EstimatedItem {
  const EstimatedItem({
    required this.tacoName,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory EstimatedItem.fromJson(Map<String, dynamic> json) {
    return EstimatedItem(
      tacoName: json['alimento_taco'] as String,
      grams: _number(json['gramas']),
      kcal: _number(json['calorias_kcal']),
      protein: _number(json['proteinas_g']),
      carbs: _number(json['carboidratos_g']),
      fat: _number(json['gorduras_g']),
    );
  }

  /// Nome do alimento na TACO (ex.: `Arroz, tipo 1, cozido`).
  final String tacoName;
  final double grams;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  /// Item de `POST /refeicoes`.
  Map<String, Object> toMealItemJson() => {
        'nome_alimento': tacoName,
        'quantidade_g': roundTo2(grams),
        'calorias_kcal': roundTo2(kcal),
        'proteinas_g': roundTo2(protein),
        'carboidratos_g': roundTo2(carbs),
        'gorduras_g': roundTo2(fat),
      };
}

/// Tabela nutricional da refeicao revisada: um item por alimento e os totais.
class NutritionEstimate {
  const NutritionEstimate({required this.items, required this.totalKcal});

  factory NutritionEstimate.fromJson(Map<String, dynamic> json) {
    final items = (json['itens'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(EstimatedItem.fromJson)
        .toList();
    final totals = json['totais'] as Map<String, dynamic>;
    return NutritionEstimate(
      items: items,
      totalKcal: _number(totals['calorias_kcal']),
    );
  }

  /// Na mesma ordem dos itens enviados para o calculo.
  final List<EstimatedItem> items;
  final double totalKcal;
}
