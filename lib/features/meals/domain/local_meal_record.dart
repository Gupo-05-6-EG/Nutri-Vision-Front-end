import '../../foods/domain/food.dart';
import '../../recognition/domain/nutrition_estimate.dart';
import 'meal.dart';
import 'meal_type.dart';

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// Item de refeicao preparado para persistencia local e envio para a API.
class MealItemDraft {
  const MealItemDraft({
    required this.name,
    required this.grams,
    required this.totals,
    this.id,
  });

  /// Calcula calorias e macros proporcionalmente a porcao de 100 g da TACO.
  factory MealItemDraft.fromPortion(FoodPortion portion) {
    final factor = portion.grams / 100.0;
    return MealItemDraft(
      name: portion.food.name,
      grams: _round2(portion.grams),
      totals: NutritionTotals(
        kcal: _round2(portion.food.kcalPer100g * factor),
        protein: _round2(portion.food.proteinPer100g * factor),
        carbs: _round2(portion.food.carbsPer100g * factor),
        fat: _round2(portion.food.fatPer100g * factor),
      ),
    );
  }

  factory MealItemDraft.fromEstimated(EstimatedItem item) {
    return MealItemDraft(
      name: item.tacoName,
      grams: _round2(item.grams),
      totals: NutritionTotals(
        kcal: _round2(item.kcal),
        protein: _round2(item.protein),
        carbs: _round2(item.carbs),
        fat: _round2(item.fat),
      ),
    );
  }

  factory MealItemDraft.fromMealItem(MealItem item) {
    return MealItemDraft(
      id: item.id,
      name: item.name,
      grams: _round2(item.grams),
      totals: item.totals,
    );
  }

  factory MealItemDraft.fromMap(Map<dynamic, dynamic> map) {
    final json = Map<String, dynamic>.from(map);
    return MealItemDraft(
      id: (json['id'] as num?)?.toInt(),
      name: json['nome_alimento'] as String,
      grams: (json['quantidade_g'] as num).toDouble(),
      totals: NutritionTotals.fromJson(json),
    );
  }

  final int? id;
  final String name;
  final double grams;
  final NutritionTotals totals;

  Map<String, Object?> toHiveMap() => {
        if (id != null) 'id': id,
        'nome_alimento': name,
        'quantidade_g': _round2(grams),
        ...totals.toJson(),
      };

  Map<String, Object> toApiJson() => {
        'nome_alimento': name,
        'quantidade_g': _round2(grams),
        ...totals.toJson(),
      };

  MealItem toMealItem(int fallbackId) => MealItem(
        id: id ?? fallbackId,
        name: name,
        grams: _round2(grams),
        totals: totals,
      );
}

/// Registro local de refeicao armazenado no Hive com flag `is_synced` (Task 2.3, RNF07).
class LocalMealRecord {
  const LocalMealRecord({
    required this.localId,
    required this.patientId,
    required this.consumedAt,
    required this.type,
    required this.items,
    required this.isSynced,
    this.remoteId,
    this.note,
  });

  factory LocalMealRecord.fromMeal({
    required int patientId,
    required Meal meal,
    String? localId,
  }) {
    final resolvedType = MealType.fromApi(meal.type) ??
        MealType.suggestedAt(meal.consumedAt.toLocal());
    return LocalMealRecord(
      localId: localId ?? 'remote_${meal.id}',
      remoteId: meal.id,
      patientId: patientId,
      consumedAt: meal.consumedAt.toUtc(),
      type: resolvedType,
      note: meal.note,
      items: meal.items.map(MealItemDraft.fromMealItem).toList(),
      isSynced: meal.isSynced,
    );
  }

  factory LocalMealRecord.fromHiveMap(Map<dynamic, dynamic> map) {
    final json = Map<String, dynamic>.from(map);
    final rawType = json['tipo'] as String?;
    final consumedAt = DateTime.parse(json['consumida_em'] as String).toUtc();
    final type =
        MealType.fromApi(rawType) ?? MealType.suggestedAt(consumedAt.toLocal());
    final rawItems = (json['itens'] as List<dynamic>? ?? const []);
    return LocalMealRecord(
      localId: json['local_id'] as String,
      remoteId: (json['remote_id'] as num?)?.toInt(),
      patientId: (json['paciente_id'] as num).toInt(),
      consumedAt: consumedAt,
      type: type,
      note: json['observacao'] as String?,
      items: [
        for (final item in rawItems)
          MealItemDraft.fromMap(item as Map<dynamic, dynamic>),
      ],
      isSynced: (json['is_synced'] as bool?) ?? false,
    );
  }

  final String localId;
  final int? remoteId;
  final int patientId;
  final DateTime consumedAt;
  final MealType type;
  final String? note;
  final List<MealItemDraft> items;

  /// Flag `is_synced` persistida no Hive (`false` enquanto aguarda envio).
  final bool isSynced;

  NutritionTotals get totals =>
      NutritionTotals.sum(items.map((item) => item.totals));

  Map<String, Object?> toHiveMap() => {
        'local_id': localId,
        'remote_id': remoteId,
        'paciente_id': patientId,
        'consumida_em': consumedAt.toUtc().toIso8601String(),
        'tipo': type.apiValue,
        'observacao': note,
        'itens': [for (final item in items) item.toHiveMap()],
        'is_synced': isSynced,
      };

  /// Corpo esperado por `POST /refeicoes` e `POST /refeicoes/batch`.
  Map<String, Object?> toApiCreateJson() => {
        'paciente_id': patientId,
        'consumida_em': consumedAt.toUtc().toIso8601String(),
        'tipo': type.apiValue,
        if (note != null && note!.trim().isNotEmpty) 'observacao': note!.trim(),
        'itens': [for (final item in items) item.toApiJson()],
      };

  LocalMealRecord markSynced({int? remoteId}) => LocalMealRecord(
        localId: localId,
        remoteId: remoteId ?? this.remoteId,
        patientId: patientId,
        consumedAt: consumedAt,
        type: type,
        note: note,
        items: items,
        isSynced: true,
      );

  Meal toMeal() {
    final baseId = remoteId ?? -(localId.hashCode.abs() + 1);
    return Meal(
      id: baseId,
      consumedAt: consumedAt.toUtc(),
      type: type.apiValue,
      note: note,
      items: [
        for (var i = 0; i < items.length; i++)
          items[i].toMealItem(baseId * 10 - i),
      ],
      totals: totals,
      isSynced: isSynced,
      localId: localId,
    );
  }
}
