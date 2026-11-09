import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';
import 'package:nutri_vision/features/screening/data/screening_repository.dart';
import 'package:nutri_vision/features/screening/domain/screening.dart';
import 'package:nutri_vision/features/screening/presentation/calorie_goal_page.dart';

const _resposta = {
  'paciente_id': 7,
  'tmb_kcal': 1864.36,
  'fator_atividade': 1.55,
  'teto_calorico_kcal': 2889.76,
  'origem_meta': 'harris_benedict',
};

void main() {
  group('ScreeningData.toJson', () {
    test('monta o corpo da triagem com os valores da API', () {
      const data = ScreeningData(
        age: 30,
        gender: Gender.masculino,
        heightCm: 180,
        weightKg: 80.5,
        activity: ActivityLevel.muitoIntenso,
      );

      expect(data.toJson(), {
        'peso_kg': 80.5,
        'altura_cm': 180.0,
        'idade': 30,
        'genero': 'masculino',
        'nivel_atividade': 'muito_intenso',
      });
    });

    test('genero "outro" envia a referencia escolhida para o calculo', () {
      const data = ScreeningData(
        age: 30,
        gender: Gender.outro,
        calcSex: CalcSex.feminino,
        heightCm: 165,
        weightKg: 60,
        activity: ActivityLevel.leve,
      );

      // A API so aceita masculino/feminino; "outro" nunca vai no corpo.
      expect(data.toJson()['genero'], 'feminino');
    });

    test('todos os niveis de atividade da API estao na tela', () {
      expect(
        ActivityLevel.values.map((level) => level.apiValue),
        ['sedentario', 'leve', 'moderado', 'intenso', 'muito_intenso'],
      );
      expect(ActivityLevel.fromApi('moderado'), ActivityLevel.moderado);
      expect(ActivityLevel.fromApi('x'), isNull);
    });
  });

  group('CalorieGoal.fromJson', () {
    test('le o TetoCaloricoOut', () {
      final goal = CalorieGoal.fromJson(_resposta);

      expect(goal.patientId, 7);
      expect(goal.basalKcal, 1864.36);
      expect(goal.activityFactor, 1.55);
      expect(goal.dailyKcal, 2889.76);
      expect(goal.source, 'harris_benedict');
    });

    test('aceita numeros inteiros', () {
      final goal = CalorieGoal.fromJson({..._resposta, 'tmb_kcal': 1800});
      expect(goal.basalKcal, 1800.0);
    });

    test('falha com campo faltando', () {
      expect(
        () =>
            CalorieGoal.fromJson({..._resposta}..remove('teto_calorico_kcal')),
        throwsFormatException,
      );
      expect(
        () => CalorieGoal.fromJson({..._resposta}..remove('paciente_id')),
        throwsFormatException,
      );
    });
  });

  group('ScreeningRepository', () {
    const data = ScreeningData(
      age: 30,
      gender: Gender.masculino,
      heightCm: 180,
      weightKg: 80,
      activity: ActivityLevel.moderado,
    );

    ScreeningRepository repo(MockClient http) => ScreeningRepository(
          ApiClient(baseUrl: 'http://api.test', httpClient: http),
        );

    test('envia para /pacientes/{id}/triagem e devolve a meta', () async {
      late http.Request enviada;
      final goal = await repo(
        MockClient((request) async {
          enviada = request;
          return http.Response(jsonEncode(_resposta), 200);
        }),
      ).submit(7, data);

      expect(enviada.method, 'POST');
      expect(enviada.url.path, '/pacientes/7/triagem');
      expect(jsonDecode(enviada.body), data.toJson());
      expect(goal.dailyKcal, 2889.76);
    });

    test('resposta fora do formato vira ApiException', () async {
      final repository = repo(
        MockClient((_) async => http.Response('{"paciente_id":7}', 200)),
      );
      await expectLater(
        repository.submit(7, data),
        throwsA(isA<ApiException>()),
      );

      final lista = repo(MockClient((_) async => http.Response('[]', 200)));
      await expectLater(lista.submit(7, data), throwsA(isA<ApiException>()));
    });

    test('propaga o erro da API com o status', () async {
      final repository = repo(
        MockClient(
          (_) async =>
              http.Response('{"detail":"Paciente nao encontrado"}', 404),
        ),
      );
      await expectLater(
        repository.submit(7, data),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });

  group('formatacao', () {
    test('formatKcal arredonda e separa milhar', () {
      expect(formatKcal(2889.76), '2.890');
      expect(formatKcal(1864.36), '1.864');
      expect(formatKcal(950), '950');
      expect(formatKcal(12345.4), '12.345');
    });

    test('formatFactor mostra so as casas necessarias', () {
      expect(formatFactor(1.2), '1,2');
      expect(formatFactor(1.375), '1,375');
      expect(formatFactor(1.55), '1,55');
      expect(formatFactor(2), '2');
    });
  });
}
