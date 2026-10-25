import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/meals/data/meal_repository.dart';
import 'package:nutri_vision/features/meals/domain/meal.dart';
import 'package:nutri_vision/features/meals/presentation/meal_history_page.dart';

Map<String, Object> _totals(num kcal, num prot, num carbs, num fat) => {
      'calorias_kcal': kcal,
      'proteinas_g': prot,
      'carboidratos_g': carbs,
      'gorduras_g': fat,
    };

Map<String, Object?> _meal({
  required int id,
  required String consumedAt,
  required String type,
  required String food,
  required num grams,
  required num kcal,
}) =>
    {
      'id': id,
      'paciente_id': 1,
      'consumida_em': consumedAt,
      'tipo': type,
      'observacao': null,
      'criada_em': consumedAt,
      'atualizada_em': consumedAt,
      'itens': [
        {
          'id': id * 10,
          'nome_alimento': food,
          'quantidade_g': grams,
          ..._totals(kcal, 10, 20, 5),
        },
      ],
      'totais': _totals(kcal, 10, 20, 5),
    };

// Chega fora de ordem de proposito: o feed tem que ser cronologico.
final _dia = <String, Object?>{
  'paciente_id': 1,
  'data': '2026-10-20',
  'quantidade_refeicoes': 2,
  'totais': _totals(1500, 20, 40, 10),
  'refeicoes': [
    _meal(
      id: 2,
      consumedAt: '2026-10-20T15:30:00Z',
      type: 'almoco',
      food: 'Arroz, tipo 1, cozido',
      grams: 150,
      kcal: 1200,
    ),
    _meal(
      id: 1,
      consumedAt: '2026-10-20T10:00:00Z',
      type: 'cafe_da_manha',
      food: 'Banana, prata, crua',
      grams: 86.5,
      kcal: 300,
    ),
  ],
};

final _diaVazio = <String, Object>{
  'paciente_id': 1,
  'data': '2026-10-19',
  'quantidade_refeicoes': 0,
  'totais': _totals(0, 0, 0, 0),
  'refeicoes': <Object>[],
};

final _today = DateTime(2026, 10, 20, 18);

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

MealRepository _repository(MockClientHandler handler) {
  return MealRepository(
    ApiClient(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient(handler),
    ),
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  MealRepository repository, {
  double goal = 2000,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MealHistoryPage(
        repository: repository,
        patientId: 1,
        dailyGoalKcal: goal,
        today: _today,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DailyConsumption.fromJson', () {
    test('le totais e itens e ordena as refeicoes pelo horario', () {
      final consumption = DailyConsumption.fromJson(_dia);

      expect(consumption.totals.kcal, 1500);
      expect(consumption.meals.map((m) => m.id), [1, 2]);
      expect(consumption.meals.first.items.single.grams, 86.5);
      expect(consumption.meals.first.consumedAt.isUtc, isTrue);
    });
  });

  test('mealTypeLabel traduz os tipos da API', () {
    expect(mealTypeLabel('cafe_da_manha'), 'Café da manhã');
    expect(mealTypeLabel('almoco'), 'Almoço');
    expect(mealTypeLabel('lanche'), 'Lanche');
    expect(mealTypeLabel('jantar'), 'Jantar');
    expect(mealTypeLabel('outro'), 'outro');
  });

  group('MealRepository', () {
    test('pede o consumo do dia com paciente e data', () async {
      late Uri requested;
      final repository = _repository((request) async {
        requested = request.url;
        return _json(_dia);
      });

      await repository.dailyConsumption(
        patientId: 3,
        day: DateTime(2026, 3, 5, 23, 59),
      );

      expect(requested.path, '/api/v1/refeicoes/consumo-diario');
      expect(requested.queryParameters, {
        'paciente_id': '3',
        'data': '2026-03-05',
      });
    });
  });

  group('MealHistoryPage', () {
    testWidgets('mostra o progresso do dia e o feed em ordem', (tester) async {
      await _pumpPage(tester, _repository((_) async => _json(_dia)));

      expect(find.text('Hoje'), findsOneWidget);
      expect(find.text('1500 de 2000 kcal'), findsOneWidget);
      expect(find.text('500 kcal restantes'), findsOneWidget);

      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 0.75);

      final breakfast = tester.getTopLeft(find.text('Café da manhã'));
      final lunch = tester.getTopLeft(find.text('Almoço'));
      expect(breakfast.dy, lessThan(lunch.dy));
      expect(find.text('Banana, prata, crua'), findsOneWidget);
      expect(find.text('86,5 g · 300 kcal'), findsOneWidget);
    });

    testWidgets('avisa quando passa da meta', (tester) async {
      await _pumpPage(
        tester,
        _repository((_) async => _json(_dia)),
        goal: 1200,
      );

      expect(find.text('300 kcal acima da meta'), findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(progress.value, 1);
    });

    testWidgets('navega para o dia anterior e nao passa de hoje', (
      tester,
    ) async {
      final days = <String?>[];
      await _pumpPage(
        tester,
        _repository((request) async {
          final day = request.url.queryParameters['data'];
          days.add(day);
          return _json(day == '2026-10-20' ? _dia : _diaVazio);
        }),
      );

      final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
      expect(tester.widget<IconButton>(next).onPressed, isNull);

      await tester.tap(find.byTooltip('Dia anterior'));
      await tester.pumpAndSettle();

      expect(days, ['2026-10-20', '2026-10-19']);
      expect(find.text('Ontem'), findsOneWidget);
      expect(find.text('Nenhuma refeição registrada neste dia.'), findsOne);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    });

    testWidgets('mostra erro e tenta de novo', (tester) async {
      var calls = 0;
      await _pumpPage(
        tester,
        _repository((_) async {
          calls++;
          if (calls == 1) throw http.ClientException('offline');
          return _json(_dia);
        }),
      );

      expect(
        find.text('Sem conexão com a API. Verifique sua internet.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('1500 de 2000 kcal'), findsOneWidget);
    });
  });
}
