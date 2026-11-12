import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/achievements/data/achievement_repository.dart';
import 'package:nutri_vision/features/achievements/presentation/achievements_page.dart';
import 'package:nutri_vision/features/foods/data/food_repository.dart';
import 'package:nutri_vision/features/foods/presentation/custom_food_page.dart';
import 'package:nutri_vision/features/auth/presentation/widgets/auth_widgets.dart';

void main() {
  test('busca unificada preserva origem e paciente mesmo com ids repetidos',
      () async {
    final client = ApiClient(
      baseUrl: 'http://test/api/v1',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/alimentos');
        expect(request.url.queryParameters['paciente_id'], '4');
        return http.Response(
          jsonEncode([
            for (final origin in ['taco', 'personalizado'])
              {
                'id': 1,
                'origem': origin,
                'nome': 'Arroz',
                'categoria': 'Teste',
                'kcal_100g': 100,
                'carbs_100g': 20,
                'prot_100g': 2,
                'gord_100g': 1,
              },
          ]),
          200,
        );
      }),
    );
    final foods = await FoodRepository(client, patientId: 4).search('arroz');
    expect(foods.map((f) => f.origin), ['taco', 'personalizado']);
    client.close();
  });

  testWidgets('formulario valida macros e aceita virgula decimal',
      (tester) async {
    var calls = 0;
    final client = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient((request) async {
        calls++;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['paciente_id'], 4);
        expect(body['kcal_100g'], 123.45);
        return http.Response(jsonEncode({'id': 1, ...body}), 201);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CustomFoodPage(repository: FoodRepository(client), patientId: 4),
      ),
    );
    final fields = find.byType(TextFormField);
    for (var i = 0; i < 5; i++) {
      await tester.enterText(
        fields.at(i),
        ['Meu alimento', '123,45', '80', '30', '5'][i],
      );
    }
    await tester.ensureVisible(find.text('Salvar alimento'));
    await tester.tap(find.text('Salvar alimento'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(
      find.text('A soma dos macronutrientes deve ser de até 100 g.'),
      findsOneWidget,
    );
    await tester.enterText(fields.at(2), '20');
    await tester.ensureVisible(find.text('Salvar alimento'));
    await tester.tap(find.text('Salvar alimento'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    client.close();
  });

  testWidgets('conquistas distinguem bloqueada e obtida com fonte ampliada',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final client = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'nome': 'Uma semana',
              'progresso': 7,
              'meta': 7,
              'obtida_em': '2026-11-01',
            },
            {
              'nome': 'Cem refeições',
              'progresso': 40,
              'meta': 100,
              'obtida_em': null,
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AchievementsPage(repository: AchievementRepository(client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Uma semana. Obtida. 7 de 7.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Cem refeições. Bloqueada. 40 de 100.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
    client.close();
  });

  testWidgets('erro de autenticacao e anunciado como regiao viva',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AuthMessageBanner(message: 'Tente novamente')),
      ),
    );
    final node = tester.getSemantics(find.byType(AuthMessageBanner));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });
}
