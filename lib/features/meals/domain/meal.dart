/// Refeicoes registradas pelo paciente (`GET /refeicoes/consumo-diario`).
///
/// Instantes chegam da API em UTC com offset explicito; a conversao para a
/// hora local fica com quem exibe (`toLocal()`).
library;

import 'meal_type.dart';

double _number(Object? value) => (value as num).toDouble();

double _round2(double value) => (value * 100).roundToDouble() / 100;

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

  static NutritionTotals sum(Iterable<NutritionTotals> items) {
    var total = zero;
    for (final item in items) {
      total = total + item;
    }
    return total;
  }

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  NutritionTotals operator +(NutritionTotals other) => NutritionTotals(
        kcal: _round2(kcal + other.kcal),
        protein: _round2(protein + other.protein),
        carbs: _round2(carbs + other.carbs),
        fat: _round2(fat + other.fat),
      );

  Map<String, Object> toJson() => {
        'calorias_kcal': _round2(kcal),
        'proteinas_g': _round2(protein),
        'carboidratos_g': _round2(carbs),
        'gorduras_g': _round2(fat),
      };
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['nome_alimento'] as String,
      grams: _number(json['quantidade_g']),
      totals: NutritionTotals.fromJson(json),
    );
  }

  final int id;
  final String name;
  final double grams;
  final NutritionTotals totals;

  Map<String, Object> toJson() => {
        'id': id,
        'nome_alimento': name,
        'quantidade_g': _round2(grams),
        ...totals.toJson(),
      };

  Map<String, Object> toCreateJson() => {
        'nome_alimento': name,
        'quantidade_g': _round2(grams),
        ...totals.toJson(),
      };
}

/// Uma refeicao com seus itens e totais (RF04, RNF07).
class Meal {
  const Meal({
    required this.id,
    required this.consumedAt,
    required this.type,
    required this.items,
    required this.totals,
    this.note,
    this.isSynced = true,
    this.localId,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final items = (json['itens'] as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final synced =
        (json['is_synced'] as bool?) ?? (json['sincronizado'] as bool?) ?? true;
    return Meal(
      id: (json['id'] as num).toInt(),
      consumedAt: DateTime.parse(json['consumida_em'] as String),
      type: json['tipo'] as String,
      note: json['observacao'] as String?,
      items: items.map(MealItem.fromJson).toList(),
      totals: NutritionTotals.fromJson(
        Map<String, dynamic>.from(json['totais'] as Map),
      ),
      isSynced: synced,
      localId: json['local_id'] as String?,
    );
  }

  final int id;
  final DateTime consumedAt;

  /// Tipo como a API devolve: `cafe_da_manha`, `almoco`, `lanche` ou `jantar`.
  final String type;
  final String? note;
  final List<MealItem> items;
  final NutritionTotals totals;

  /// `false` quando a refeicao foi salva localmente offline e ainda aguarda
  /// envio em lote para a API (Task 2.3, RNF07).
  final bool isSynced;

  /// Identificador do registro no banco local (Hive), quando aplicavel.
  final String? localId;

  Meal copyWith({
    int? id,
    bool? isSynced,
    String? localId,
  }) {
    return Meal(
      id: id ?? this.id,
      consumedAt: consumedAt,
      type: type,
      note: note,
      items: items,
      totals: totals,
      isSynced: isSynced ?? this.isSynced,
      localId: localId ?? this.localId,
    );
  }
}

/// Consumo de um dia com os totais (RF12).
class DailyConsumption {
  const DailyConsumption({required this.meals, required this.totals});

  factory DailyConsumption.fromJson(Map<String, dynamic> json) {
    final meals = (json['refeicoes'] as List<dynamic>)
        .map((item) => Meal.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return DailyConsumption(
      meals: meals,
      totals: NutritionTotals.fromJson(
        Map<String, dynamic>.from(json['totais'] as Map),
      ),
    );
  }

  /// Refeicoes em ordem cronologica.
  final List<Meal> meals;
  final NutritionTotals totals;
}

/// Rotulo em pt-BR do tipo de refeicao devolvido pela API (RF19).
String mealTypeLabel(String type) => MealType.fromApi(type)?.label ?? type;
