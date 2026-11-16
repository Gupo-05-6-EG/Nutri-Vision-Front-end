import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/plan/data/plan_repository.dart';
import 'package:nutri_vision/features/plan/presentation/plan_progress_page.dart';

// 21/10/2026 e quarta-feira: a semana tem os dias 19, 20 e 21.
final _today = DateTime(2026, 10, 21);

Map<String, Object?> _plan() => {
      'id': 1,
      'paciente_id': 7,
      'titulo': 'Hipertrofia limpa',
      'observacao': null,
      'refeicoes': [
        {
          'id': 10,
          'nome': 'Café da manhã',
          'horario': '07:30:00',
          'meta_kcal': 500,
          'meta_proteinas_g': 30,
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
      ],
      'totais': {'meta_kcal': 2000, 'meta_proteinas_g': 100},
    };

/// 500 kcal e 40 g de proteina por dia (a API devolve o dia pedido).
Map<String, Object> _day(String date) => {
      'paciente_id': 7,
      'data': date,
      'quantidade_refeicoes': 1,
      'totais': {
        'calorias_kcal': 500,
        'proteinas_g': 40,
        'carboidratos_g': 60,
        'gorduras_g': 15,
      },
      'refeicoes': <Object>[],
    };

MockClient _api({bool hasPlan = true, bool fail = false}) {
  return MockClient((request) async {
    if (fail) return http.Response('erro', 500);
    if (request.url.path.endsWith('/planos/ativo')) {
      if (!hasPlan) {
        return http.Response(
          jsonEncode({'detail': 'Paciente sem plano ativo'}),
          404,
        );
      }
      // O plano tem acentos: sem o charset, o Response codificaria em latin1.
      return http.Response(
        jsonEncode(_plan()),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    return http.Response(
      jsonEncode(_day(request.url.queryParameters['data']!)),
      200,
    );
  });
}

Future<void> _pump(
  WidgetTester tester,
  MockClient httpClient, {
  double? fallbackGoalKcal,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: PlanProgressPage(
        repository: PlanRepository(
          ApiClient(baseUrl: 'http://api.test', httpClient: httpClient),
        ),
        patientId: 7,
        fallbackGoalKcal: fallbackGoalKcal,
        today: _today,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('com plano mostra as metas do nutricionista e o plano',
      (tester) async {
    await _pump(tester, _api());

    expect(find.text('Meta diária'), findsOneWidget);
    expect(find.text('500 / 2000 kcal'), findsOneWidget);
    expect(find.text('1500 kcal restantes'), findsOneWidget);
    expect(find.text('40 / 100 g'), findsOneWidget);
    expect(find.text('Metas do plano do seu nutricionista.'), findsOneWidget);

    // Carboidratos e gorduras nao tem meta no plano: so o consumido.
    expect(find.text('60 g'), findsOneWidget);
    expect(find.text('15 g'), findsOneWidget);
    expect(find.text('Sem meta definida'), findsNWidgets(2));

    expect(find.text('Hipertrofia limpa'), findsOneWidget);
    expect(find.text('Café da manhã'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);
    expect(find.text('Ovos mexidos'), findsOneWidget);
  });

  testWidgets('semana soma de segunda ate hoje contra 7 dias de meta',
      (tester) async {
    await _pump(tester, _api());

    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();

    expect(find.text('Meta da semana'), findsOneWidget);
    // 3 dias x 500 kcal contra 7 x 2000 kcal.
    expect(find.text('1500 / 14000 kcal'), findsOneWidget);
    // 3 dias x 40 g contra 7 x 100 g.
    expect(find.text('120 / 700 g'), findsOneWidget);
  });

  testWidgets('sem plano usa o teto calorico da triagem', (tester) async {
    await _pump(tester, _api(hasPlan: false), fallbackGoalKcal: 1800);

    expect(find.text('500 / 1800 kcal'), findsOneWidget);
    expect(
      find.textContaining('Usando o seu teto calórico diário'),
      findsOneWidget,
    );
    expect(find.text('Plano prescrito'), findsNothing);
    // Sem plano nao ha meta de proteina.
    expect(find.text('40 g'), findsOneWidget);
  });

  testWidgets('sem plano e sem teto mostra o consumo e orienta a calcular',
      (tester) async {
    await _pump(tester, _api(hasPlan: false));

    expect(find.text('500 kcal'), findsOneWidget);
    expect(find.textContaining('Calcule a sua meta'), findsOneWidget);
  });

  testWidgets('erro da API mostra mensagem e permite tentar de novo',
      (tester) async {
    await _pump(tester, _api(fail: true));

    expect(
      find.text('Não foi possível carregar o seu plano. Tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Tentar de novo'), findsOneWidget);
  });
}
