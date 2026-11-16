/// Consumo da semana e calculo de progresso contra as metas (RF25).
library;

import '../../meals/domain/meal.dart';

/// Dias da semana (segunda a domingo) em que o consumo e contado, de segunda
/// ate [today] (so a data e usada).
List<DateTime> weekDaysUntil(DateTime today) {
  // `DateTime` normaliza dias fora do mes (ex.: dia 0 vira o ultimo do mes
  // anterior), entao a conta atravessa a virada de mes sem tratamento extra.
  return [
    for (var i = today.weekday - 1; i >= 0; i--)
      DateTime(today.year, today.month, today.day - i),
  ];
}

/// Soma de varios totais nutricionais.
NutritionTotals sumTotals(Iterable<NutritionTotals> totals) {
  var kcal = 0.0;
  var protein = 0.0;
  var carbs = 0.0;
  var fat = 0.0;
  for (final item in totals) {
    kcal += item.kcal;
    protein += item.protein;
    carbs += item.carbs;
    fat += item.fat;
  }
  return NutritionTotals(kcal: kcal, protein: protein, carbs: carbs, fat: fat);
}

/// Consumo de hoje e da semana corrente (de segunda ate hoje).
class WeekConsumption {
  const WeekConsumption({required this.today, required this.week});

  final NutritionTotals today;
  final NutritionTotals week;
}

/// Fracao consumida da [goal] (0 quando nao ha meta). Pode passar de 1.
double progressRatio(double consumed, double goal) =>
    goal > 0 ? consumed / goal : 0;
