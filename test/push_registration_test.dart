import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';
import 'package:nutri_vision/features/meals/domain/meal_type.dart';
import 'package:nutri_vision/features/reminders/application/push_registration.dart';
import 'package:nutri_vision/features/reminders/application/push_service.dart';
import 'package:nutri_vision/features/reminders/data/reminder_repository.dart';

import 'fake_push_service.dart';

class _MemoryStorage implements TokenStorage {
  _MemoryStorage([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

String _jwt({int sub = 7}) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 1));
  final payload = {'sub': '$sub', 'exp': exp.millisecondsSinceEpoch ~/ 1000};
  return '${enc({'alg': 'HS256'})}.${enc(payload)}.assinatura';
}

/// App sem tela: AuthController + PushRegistration falando com uma API falsa.
class _Harness {
  _Harness({
    FakePushService? push,
    String? storedToken,
    this.deviceStatus = 204,
  })  : push = push ?? FakePushService(),
        storage = _MemoryStorage(storedToken) {
    client = ApiClient(
      baseUrl: 'http://api.test',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == AuthRepository.loginPath) {
          return http.Response(
            jsonEncode({
              'access_token': _jwt(sub: 9),
              'token_type': 'bearer',
              'usuario': {'id': 9, 'nome': 'Alex', 'perfil': 'paciente'},
            }),
            200,
          );
        }
        return http.Response('', deviceStatus);
      }),
    );
    auth = AuthController(
      client: client,
      repository: AuthRepository(client),
      storage: storage,
    );
    registration = PushRegistration(
      auth: auth,
      repository: ReminderRepository(client),
      push: this.push,
    );
    registration.openedReminders.listen(opened.add);
    registration.foregroundReminders.listen(foreground.add);
  }

  final FakePushService push;
  final _MemoryStorage storage;
  int deviceStatus;
  final requests = <http.Request>[];
  final opened = <MealType>[];
  final foreground = <MealType>[];
  late final ApiClient client;
  late final AuthController auth;
  late final PushRegistration registration;

  /// Registros de token enviados a API: (caminho, token).
  List<(String, Object?)> get deviceRegistrations => [
        for (final request in requests)
          if (request.url.path.endsWith('/dispositivos-push'))
            (request.url.path, jsonDecode(request.body)['token']),
      ];

  Future<void> settle() async {
    await pumpEventQueue();
    await registration.idle;
    await pumpEventQueue();
  }

  Future<void> boot() async {
    await registration.start();
    await auth.restoreSession();
    await settle();
  }
}

void main() {
  group('PushRegistration', () {
    test('sessao restaurada no boot registra o token do aparelho', () async {
      final h = _Harness(storedToken: _jwt(sub: 7));

      await h.boot();

      expect(h.deviceRegistrations, [
        ('/pacientes/7/dispositivos-push', 'token-fcm-1'),
      ]);
      expect(h.push.requestPermissionCalls, 0);
    });

    test('login registra o token com o id do paciente logado', () async {
      final h = _Harness();
      await h.boot();
      expect(h.deviceRegistrations, isEmpty);

      await h.auth.login(email: 'a@b.com', password: '12345678');
      await h.settle();

      expect(h.deviceRegistrations, [
        ('/pacientes/9/dispositivos-push', 'token-fcm-1'),
      ]);
    });

    test('token trocado pelo FCM e registrado de novo', () async {
      final h = _Harness(storedToken: _jwt(sub: 7));
      await h.boot();

      h.push.tokenRefresh.add('token-fcm-2');
      await h.settle();

      expect(
        h.deviceRegistrations.last,
        ('/pacientes/7/dispositivos-push', 'token-fcm-2'),
      );
    });

    test('logout invalida o token e ignora trocas de token depois', () async {
      final h = _Harness(storedToken: _jwt(sub: 7));
      await h.boot();

      await h.auth.logout();
      await h.settle();
      h.push.tokenRefresh.add('token-fcm-2');
      await h.settle();

      expect(h.push.deleteTokenCalls, 1);
      expect(h.deviceRegistrations, hasLength(1));
    });

    test('sem token do FCM nao chama a API', () async {
      final h = _Harness(
        push: FakePushService(token: null),
        storedToken: _jwt(sub: 7),
      );

      await h.boot();

      expect(h.push.getTokenCalls, 1);
      expect(h.deviceRegistrations, isEmpty);
    });

    test('falha ao registrar nao derruba a sessao', () async {
      final h = _Harness(storedToken: _jwt(sub: 7), deviceStatus: 500);

      await h.boot();

      expect(h.auth.status, AuthStatus.authenticated);
      expect(h.push.deleteTokenCalls, 0);
    });

    test('401 ao registrar encerra a sessao e invalida o token', () async {
      final h = _Harness(storedToken: _jwt(sub: 7), deviceStatus: 401);

      await h.boot();

      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(h.push.deleteTokenCalls, 1);
    });

    test('push que abriu o app espera a sessao para abrir o lembrete',
        () async {
      final h = _Harness(
        push: FakePushService(initial: reminderPush('almoco')),
        storedToken: _jwt(sub: 7),
      );

      await h.registration.start();
      expect(h.opened, isEmpty);

      await h.auth.restoreSession();
      await h.settle();

      expect(h.opened, [MealType.lunch]);
    });

    test('push que abriu o app sem sessao e descartado', () async {
      final h = _Harness(
        push: FakePushService(initial: reminderPush('almoco')),
      );

      await h.boot();
      await h.auth.login(email: 'a@b.com', password: '12345678');
      await h.settle();

      expect(h.opened, isEmpty);
    });

    test('repassa lembretes tocados e recebidos com o app aberto', () async {
      final h = _Harness(storedToken: _jwt(sub: 7));
      await h.boot();

      h.push.opened.add(reminderPush('jantar'));
      h.push.foreground.add(reminderPush('cafe_da_manha'));
      h.push.opened.add({'tipo_notificacao': 'outra_coisa'});
      await h.settle();

      expect(h.opened, [MealType.dinner]);
      expect(h.foreground, [MealType.breakfast]);
    });

    test('push desligado nao registra nada', () async {
      final storage = _MemoryStorage(_jwt(sub: 7));
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('', 204);
        }),
      );
      final auth = AuthController(
        client: client,
        repository: AuthRepository(client),
        storage: storage,
      );
      final registration = PushRegistration(
        auth: auth,
        repository: ReminderRepository(client),
        push: const DisabledPushService(),
      );

      await registration.start();
      await auth.restoreSession();
      await registration.idle;

      expect(requests, isEmpty);
    });
  });
}
