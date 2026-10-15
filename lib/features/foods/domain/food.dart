/// Alimento devolvido pela busca da API (`GET /alimentos-taco`).
///
/// Os valores nutricionais sao por 100 g, como na tabela TACO.
class Food {
  const Food({
    required this.id,
    required this.name,
    required this.category,
    required this.kcalPer100g,
    required this.carbsPer100g,
    required this.proteinPer100g,
    required this.fatPer100g,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as int,
      name: json['nome'] as String,
      category: json['categoria'] as String,
      kcalPer100g: (json['kcal_100g'] as num).toDouble(),
      carbsPer100g: (json['carbs_100g'] as num).toDouble(),
      proteinPer100g: (json['prot_100g'] as num).toDouble(),
      fatPer100g: (json['gord_100g'] as num).toDouble(),
    );
  }

  final int id;
  final String name;
  final String category;
  final double kcalPer100g;
  final double carbsPer100g;
  final double proteinPer100g;
  final double fatPer100g;
}

/// Alimento escolhido pelo paciente com a porcao consumida, em gramas.
class FoodPortion {
  const FoodPortion({required this.food, required this.grams});

  final Food food;
  final double grams;
}
