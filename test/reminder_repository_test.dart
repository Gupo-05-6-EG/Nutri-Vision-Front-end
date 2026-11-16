import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';
import 'package:nutri_vision/features/meals/domain/meal_type.dart';
import 'package:nutri_vision/features/reminders/data/reminder_repository.dart';
import 'package:nutri_vision/features/reminders/domain/meal_reminder.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ReminderRepository _repository(MockClientHandler handler) => ReminderRepository(
      ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient(handler),
      ),
    );

void main() {
  group('ReminderRepository', () {
    test('busca os lembretes do paciente e completa com os padroes', () async {
      http.Request? chamada;
      final repository = _repository((request) async {
        chamada = request;
        return _json({
          'paciente_id': 7,
          'lembretes': [
            {'tipo': 'almoco', 'horario': '13:00:00', 'ativo': true},
          ],
        });
      });

      final reminders = await repository.fetch(7);

      expect(chamada?.method, 'GET');
      expect(chamada?.url.path, '/api/v1/pacientes/7/lembretes-refeicao');
      expect(reminders, hasLength(4));
      expect(
        reminders[1],
        const MealReminder(
          type: MealType.lunch,
          hour: 13,
          minute: 0,
          enabled: true,
        ),
      );
      expect(reminders[0].enabled, isFalse);
    });

    test('salva os 4 lembretes com PUT e devolve o que a API respondeu',
        () async {
      http.Request? chamada;
      final repository = _repository((request) async {
        chamada = request;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'paciente_id': 7, ...body});
      });
      final reminders = [
        for (final reminder in MealReminder.defaults)
          reminder.type == MealType.dinner
              ? reminder.copyWith(hour: 21, minute: 15, enabled: true)
              : reminder,
      ];

      final saved = await repository.save(7, reminders);

      expect(chamada?.method, 'PUT');
      expect(chamada?.url.path, '/api/v1/pacientes/7/lembretes-refeicao');
      expect(jsonDecode(chamada!.body), {
        'lembretes': [
          {'tipo': 'cafe_da_manha', 'horario': '08:00', 'ativo': false},
          {'tipo': 'almoco', 'horario': '12:30', 'ativo': false},
          {'tipo': 'lanche', 'horario': '16:00', 'ativo': false},
          {'tipo': 'jantar', 'horario': '21:15', 'ativo': true},
        ],
      });
      expect(saved, reminders);
    });

    test('registra o token do aparelho', () async {
      http.Request? chamada;
      final repository = _repository((request) async {
        chamada = request;
        return http.Response('', 204);
      });

      await repository.registerDevice(7, 'token-fcm');

      expect(chamada?.method, 'PUT');
      expect(chamada?.url.path, '/api/v1/pacientes/7/dispositivos-push');
      expect(jsonDecode(chamada!.body), {'token': 'token-fcm'});
    });

    test('resposta fora do contrato vira ApiException', () async {
      final semLista = _repository((request) async => _json({'ok': true}));
      final tipoInvalido = _repository(
        (request) async => _json({
          'lembretes': [
            {'tipo': 'ceia', 'horario': '22:00:00', 'ativo': true},
          ],
        }),
      );
      final itemInvalido = _repository(
        (request) async => _json({
          'lembretes': ['almoco'],
        }),
      );

      expect(semLista.fetch(7), throwsA(isA<ApiException>()));
      expect(tipoInvalido.fetch(7), throwsA(isA<ApiException>()));
      expect(itemInvalido.fetch(7), throwsA(isA<ApiException>()));
    });

    test('propaga o erro HTTP da API', () async {
      final repository = _repository(
        (request) async => _json({'detail': 'Paciente nao encontrado'}, 404),
      );

      expect(
        repository.fetch(7),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
      );
    });
  });
}
