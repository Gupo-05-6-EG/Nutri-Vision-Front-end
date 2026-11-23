import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/features/meals/domain/meal.dart';
import 'package:nutri_vision/features/plan/domain/meal_plan.dart';
import 'package:nutri_vision/features/plan/domain/progress.dart';

void main() {
  group('MealPlan.fromJson', () {
    test('le titulo, metas do dia e refeicoes com alimentos', () {
      final plan = MealPlan.fromJson({
        'id': 1,
        'paciente_id': 7,
        'nutricionista_id': 3,
        'titulo': 'Hipertrofia limpa',
        'observacao': 'Beber 2 L de água',
        'ativo': true,
        'criado_em': '2026-10-20T12:00:00Z',
        'refeicoes': [
          {
            'id': 10,
            'nome': 'Café da manhã',
            'horario': '07:30:00',
            'meta_kcal': 400,
            'meta_proteinas_g': 25.5,
            'observacao': null,
            'alimentos': [
              {
                'id': 100,
                'nome_alimento': 'Ovos mexidos',
                'quantidade_g': 120,
                'alimento_taco_id': null,
              },
            ],
          },
          {
            'id': 11,
            'nome': 'Almoço',
            'horario': null,
            'meta_kcal': 600,
            'meta_proteinas_g': 40,
            'observacao': 'Sem fritura',
            'alimentos': <Map<String, Object?>>[],
          },
        ],
        'totais': {'meta_kcal': 1000, 'meta_proteinas_g': 65.5},
      });

      expect(plan.title, 'Hipertrofia limpa');
      expect(plan.note, 'Beber 2 L de água');
      expect(plan.goalKcal, 1000);
      expect(plan.goalProtein, 65.5);
      expect(plan.meals, hasLength(2));
      expect(plan.meals.first.name, 'Café da manhã');
      expect(plan.meals.first.time, '07:30');
      expect(plan.meals.first.goalKcal, 400);
      expect(plan.meals.first.foods.single.name, 'Ovos mexidos');
      expect(plan.meals.first.foods.single.grams, 120);
      expect(plan.meals.last.time, isNull);
      expect(plan.meals.last.note, 'Sem fritura');
    });
  });

  group('weekDaysUntil', () {
    test('vai da segunda ate hoje', () {
      // 21/10/2026 e uma quarta-feira.
      expect(weekDaysUntil(DateTime(2026, 10, 21, 15, 30)), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);
    });

    test('na segunda-feira so conta o proprio dia', () {
      expect(weekDaysUntil(DateTime(2026, 10, 19)), [DateTime(2026, 10, 19)]);
    });

    test('atravessa a virada de mes', () {
      // 03/11/2026 e uma terca-feira; a segunda foi 02/11.
      expect(weekDaysUntil(DateTime(2026, 11, 3)), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 3),
      ]);
      // 01/11/2026 e domingo; a semana comecou em 26/10.
      final days = weekDaysUntil(DateTime(2026, 11, 1));
      expect(days, hasLength(7));
      expect(days.first, DateTime(2026, 10, 26));
      expect(days.last, DateTime(2026, 11, 1));
    });
  });

  test('sumTotals soma calorias e macros', () {
    final total = sumTotals(const [
      NutritionTotals(kcal: 100, protein: 10, carbs: 20, fat: 5),
      NutritionTotals(kcal: 250.5, protein: 2.5, carbs: 30, fat: 1),
    ]);

    expect(total.kcal, 350.5);
    expect(total.protein, 12.5);
    expect(total.carbs, 50);
    expect(total.fat, 6);
    expect(sumTotals(const []).kcal, 0);
  });

  test('progressRatio e 0 sem meta e passa de 1 ao exceder', () {
    expect(progressRatio(500, 0), 0);
    expect(progressRatio(500, 2000), 0.25);
    expect(progressRatio(2500, 2000), 1.25);
  });
}
