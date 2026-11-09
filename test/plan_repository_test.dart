import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';
import 'package:nutri_vision/features/plan/data/plan_repository.dart';

Map<String, Object> _totals(num kcal, num protein) => {
      'calorias_kcal': kcal,
      'proteinas_g': protein,
      'carboidratos_g': 10,
      'gorduras_g': 5,
    };

PlanRepository _repository(MockClient httpClient) => PlanRepository(
      ApiClient(baseUrl: 'http://api.test', httpClient: httpClient),
    );

void main() {
  test('activePlan le o plano ativo do paciente', () async {
    final repository = _repository(
      MockClient((request) async {
        expect(request.url.path, PlanRepository.activePlanPath(7));
        return http.Response(
          jsonEncode({
            'id': 1,
            'titulo': 'Plano A',
            'observacao': null,
            'refeicoes': <Object>[],
            'totais': {'meta_kcal': 2000, 'meta_proteinas_g': 120},
          }),
          200,
        );
      }),
    );

    final plan = await repository.activePlan(7);

    expect(plan!.title, 'Plano A');
    expect(plan.goalKcal, 2000);
    expect(plan.goalProtein, 120);
  });

  test('activePlan devolve null quando o paciente nao tem plano', () async {
    final repository = _repository(
      MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Paciente sem plano ativo'}),
          404,
        );
      }),
    );

    expect(await repository.activePlan(7), isNull);
  });

  test('activePlan repassa outros erros', () async {
    final repository = _repository(
      MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Paciente nao encontrado'}),
          404,
        );
      }),
    );

    expect(repository.activePlan(7), throwsA(isA<ApiException>()));
  });

  test('weekConsumption soma de segunda ate hoje', () async {
    final dates = <String>[];
    final repository = _repository(
      MockClient((request) async {
        expect(request.url.path, '/refeicoes/consumo-diario');
        expect(request.url.queryParameters['paciente_id'], '7');
        final date = request.url.queryParameters['data']!;
        dates.add(date);
        // 19/10 -> 100 kcal, 20/10 -> 200 kcal, 21/10 (hoje) -> 300 kcal.
        final kcal = (int.parse(date.substring(8)) - 18) * 100;
        return http.Response(
          jsonEncode({
            'paciente_id': 7,
            'data': date,
            'quantidade_refeicoes': 0,
            'totais': _totals(kcal, 10),
            'refeicoes': <Object>[],
          }),
          200,
        );
      }),
    );

    final result = await repository.weekConsumption(
      patientId: 7,
      today: DateTime(2026, 10, 21),
    );

    expect(dates..sort(), ['2026-10-19', '2026-10-20', '2026-10-21']);
    expect(result.today.kcal, 300);
    expect(result.week.kcal, 600);
    expect(result.week.protein, 30);
  });
}
