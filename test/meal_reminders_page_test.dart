import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/reminders/application/push_service.dart';
import 'package:nutri_vision/features/reminders/data/reminder_repository.dart';
import 'package:nutri_vision/features/reminders/presentation/meal_reminders_page.dart';

import 'fake_push_service.dart';

/// API de lembretes em memoria: o GET devolve o que o PUT salvou.
class _FakeApi {
  _FakeApi([List<Map<String, Object>>? saved]) : saved = saved ?? [];

  List<Map<String, Object>> saved;
  final requests = <http.Request>[];
  int? failGetWith;
  int? failPutWith;

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final fail = request.method == 'GET' ? failGetWith : failPutWith;
    if (fail != null) return http.Response('', fail);
    if (request.method == 'PUT') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      saved = [
        for (final item in body['lembretes'] as List)
          Map<String, Object>.from(item as Map),
      ];
    }
    return http.Response(
      jsonEncode({'paciente_id': 7, 'lembretes': saved}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }

  List<http.Request> get puts =>
      requests.where((request) => request.method == 'PUT').toList();
}

Future<_FakeApi> _pumpPage(
  WidgetTester tester, {
  _FakeApi? api,
  PushService? push,
  TimeOfDay? pickedTime,
}) async {
  final fakeApi = api ?? _FakeApi();
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: MealRemindersPage(
        repository: ReminderRepository(
          ApiClient(
            baseUrl: 'http://api.test',
            httpClient: MockClient(fakeApi.handle),
          ),
        ),
        patientId: 7,
        push: push ?? FakePushService(),
        pickTime: (context, initial) async => pickedTime,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fakeApi;
}

Finder get _saveButton => find.widgetWithText(FilledButton, 'Salvar');

bool _canSave(WidgetTester tester) =>
    tester.widget<FilledButton>(_saveButton).onPressed != null;

Finder _switch(String type) => find.byKey(ValueKey('reminder-switch-$type'));

Finder _time(String type) => find.byKey(ValueKey('reminder-time-$type'));

void main() {
  group('MealRemindersPage', () {
    testWidgets('sem nada salvo mostra os 4 lembretes padrao desligados', (
      tester,
    ) async {
      await _pumpPage(tester);

      for (final label in ['Café da manhã', 'Almoço', 'Lanche', 'Jantar']) {
        expect(find.text(label), findsOneWidget);
      }
      for (final time in ['08:00', '12:30', '16:00', '20:00']) {
        expect(find.text(time), findsOneWidget);
      }
      expect(find.text('Desligado'), findsNWidgets(4));
      expect(_canSave(tester), isFalse);
    });

    testWidgets('mostra os lembretes salvos', (tester) async {
      await _pumpPage(
        tester,
        api: _FakeApi([
          {'tipo': 'jantar', 'horario': '19:45:00', 'ativo': true},
        ]),
      );

      expect(find.text('Lembrete às 19:45'), findsOneWidget);
      expect(tester.widget<Switch>(_switch('jantar')).value, isTrue);
      expect(find.text('Desligado'), findsNWidgets(3));
    });

    testWidgets('liga, muda o horario e salva os 4 lembretes', (tester) async {
      final push = FakePushService(permission: PushPermission.notDetermined);
      final api = await _pumpPage(
        tester,
        push: push,
        pickedTime: const TimeOfDay(hour: 13, minute: 15),
      );

      await tester.tap(_switch('almoco'));
      await tester.pumpAndSettle();
      await tester.tap(_time('almoco'));
      await tester.pumpAndSettle();

      expect(find.text('Lembrete às 13:15'), findsOneWidget);
      expect(_canSave(tester), isTrue);

      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(jsonDecode(api.puts.single.body), {
        'lembretes': [
          {'tipo': 'cafe_da_manha', 'horario': '08:00', 'ativo': false},
          {'tipo': 'almoco', 'horario': '13:15', 'ativo': true},
          {'tipo': 'lanche', 'horario': '16:00', 'ativo': false},
          {'tipo': 'jantar', 'horario': '20:00', 'ativo': false},
        ],
      });
      expect(
        api.puts.single.url.path,
        ReminderRepository.remindersPath(7),
      );
      expect(find.text('Lembretes salvos.'), findsOneWidget);
      expect(_canSave(tester), isFalse);
      // Primeiro lembrete ligado: e a hora de pedir a permissao.
      expect(push.requestPermissionCalls, 1);
    });

    testWidgets('desfazer a alteracao volta a desabilitar o salvar', (
      tester,
    ) async {
      await _pumpPage(tester);

      await tester.tap(_switch('lanche'));
      await tester.pumpAndSettle();
      expect(_canSave(tester), isTrue);

      await tester.tap(_switch('lanche'));
      await tester.pumpAndSettle();
      expect(_canSave(tester), isFalse);
    });

    testWidgets('cancelar o seletor de horario nao muda nada', (tester) async {
      await _pumpPage(tester);

      await tester.tap(_time('jantar'));
      await tester.pumpAndSettle();

      expect(find.text('20:00'), findsOneWidget);
      expect(_canSave(tester), isFalse);
    });

    testWidgets('salvar tudo desligado nao pede permissao', (tester) async {
      final push = FakePushService(permission: PushPermission.notDetermined);
      await _pumpPage(
        tester,
        push: push,
        pickedTime: const TimeOfDay(hour: 7, minute: 0),
      );

      await tester.tap(_time('cafe_da_manha'));
      await tester.pumpAndSettle();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(push.requestPermissionCalls, 0);
    });

    testWidgets('falha ao salvar avisa e mantem as alteracoes', (
      tester,
    ) async {
      final api = _FakeApi()..failPutWith = 500;
      await _pumpPage(tester, api: api);

      await tester.tap(_switch('jantar'));
      await tester.pumpAndSettle();
      await tester.tap(_saveButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'O servidor está indisponível no momento. '
          'Tente novamente em instantes.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<Switch>(_switch('jantar')).value, isTrue);
      expect(_canSave(tester), isTrue);
    });

    testWidgets('erro ao carregar permite tentar de novo', (tester) async {
      final api = _FakeApi()..failGetWith = 500;
      await _pumpPage(tester, api: api);

      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(_saveButton, findsNothing);

      api.failGetWith = null;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Almoço'), findsOneWidget);
      expect(_saveButton, findsOneWidget);
    });

    testWidgets('permissao negada mostra aviso com botao para permitir', (
      tester,
    ) async {
      final push = FakePushService(permission: PushPermission.denied);
      await _pumpPage(tester, push: push);

      expect(find.textContaining('notificações estão desativadas'), findsOne);

      await tester.tap(find.text('Permitir notificações'));
      await tester.pumpAndSettle();

      expect(push.requestPermissionCalls, 1);
      expect(
        find.textContaining('notificações estão desativadas'),
        findsNothing,
      );
    });

    testWidgets('permissao bloqueada orienta a ir nas configuracoes', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        push: FakePushService(permission: PushPermission.permanentlyDenied),
      );

      expect(find.textContaining('configurações do aparelho'), findsOne);
      expect(find.text('Permitir notificações'), findsNothing);
    });

    testWidgets('sem permissao respondida nao mostra aviso', (tester) async {
      await _pumpPage(
        tester,
        push: FakePushService(permission: PushPermission.notDetermined),
      );

      expect(find.byIcon(Icons.notifications_off_outlined), findsNothing);
    });

    testWidgets('sem push avisa que os lembretes nao chegam no aparelho', (
      tester,
    ) async {
      await _pumpPage(tester, push: const DisabledPushService());

      expect(find.textContaining('Notificações indisponíveis'), findsOne);
    });
  });
}
