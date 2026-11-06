import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_models.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';

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

String _jwt(DateTime exp) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final payload = {'exp': exp.millisecondsSinceEpoch ~/ 1000};
  return '${enc({'alg': 'HS256'})}.${enc(payload)}.assinatura';
}

/// Resposta no formato do `TokenOut` da API.
http.Response _tokenOut(String token, {int status = 200}) => http.Response(
  jsonEncode({
    'access_token': token,
    'token_type': 'bearer',
    'usuario': {'id': 7, 'nome': 'Alex', 'perfil': 'paciente'},
  }),
  status,
);

AuthController _controller(
  http.Client httpClient,
  _MemoryStorage storage,
  ApiClient Function(ApiClient) onClient,
) {
  final client = onClient(
    ApiClient(baseUrl: 'http://api.test', httpClient: httpClient),
  );
  return AuthController(
    client: client,
    repository: AuthRepository(client),
    storage: storage,
  );
}

void main() {
  final validToken = _jwt(DateTime.now().add(const Duration(days: 1)));
  final expiredToken = _jwt(DateTime.now().subtract(const Duration(days: 1)));

  group('AuthController', () {
    test('login guarda o token, injeta no client e autentica', () async {
      final storage = _MemoryStorage();
      late ApiClient client;
      final auth = _controller(
        MockClient((request) async {
          expect(request.url.path, AuthRepository.loginPath);
          expect(jsonDecode(request.body), {
            'email': 'a@b.com',
            'senha': '12345678',
          });
          return _tokenOut(validToken);
        }),
        storage,
        (c) => client = c,
      );

      await auth.login(email: 'a@b.com', password: '12345678');

      expect(auth.status, AuthStatus.authenticated);
      expect(storage.value, validToken);
      expect(client.authToken, validToken);
    });

    test('login com credenciais erradas lanca e nao autentica', () async {
      final storage = _MemoryStorage();
      final auth = _controller(
        MockClient((request) async => http.Response('{"detail":"x"}', 401)),
        storage,
        (c) => c,
      );

      await expectLater(
        auth.login(email: 'a@b.com', password: 'errada'),
        throwsA(isA<ApiException>()),
      );

      expect(auth.status, isNot(AuthStatus.authenticated));
      expect(storage.value, isNull);
    });

    test('restoreSession sem token vai para nao autenticado', () async {
      final auth = _controller(
        MockClient((request) async => http.Response('{}', 200)),
        _MemoryStorage(),
        (c) => c,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.notice, isNull);
    });

    test('restoreSession com token expirado limpa e avisa', () async {
      final storage = _MemoryStorage(expiredToken);
      final auth = _controller(
        MockClient((request) async => http.Response('{}', 200)),
        storage,
        (c) => c,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.notice, AuthController.sessionExpiredMessage);
      expect(storage.value, isNull);
    });

    test('restoreSession com token valido autentica', () async {
      late ApiClient client;
      final auth = _controller(
        MockClient((request) async => http.Response('{}', 200)),
        _MemoryStorage(validToken),
        (c) => client = c,
      );

      await auth.restoreSession();

      expect(auth.status, AuthStatus.authenticated);
      expect(client.authToken, validToken);
    });

    test('401 em requisicao autenticada encerra a sessao', () async {
      final storage = _MemoryStorage();
      late ApiClient client;
      final auth = _controller(
        MockClient((request) async {
          if (request.url.path == AuthRepository.loginPath) {
            return _tokenOut(validToken);
          }
          return http.Response('expirou', 401);
        }),
        storage,
        (c) => client = c,
      );
      await auth.login(email: 'a@b.com', password: '12345678');

      await expectLater(client.get('/privado'), throwsA(isA<ApiException>()));
      await pumpEventQueue();

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.notice, AuthController.sessionExpiredMessage);
      expect(client.authToken, isNull);
      expect(storage.value, isNull);
    });

    test('registerPatient cadastra e entra com o token do cadastro', () async {
      final paths = <String>[];
      Map<String, dynamic>? corpoCadastro;
      final auth = _controller(
        MockClient((request) async {
          paths.add(request.url.path);
          corpoCadastro = jsonDecode(request.body) as Map<String, dynamic>;
          return _tokenOut(validToken, status: 201);
        }),
        _MemoryStorage(),
        (c) => c,
      );

      await auth.registerPatient(
        const PatientSignup(
          name: 'Alex Silva',
          email: 'alex@email.com',
          password: '12345678',
        ),
      );

      // Sem dados corporais (fluxo "Tenho nutricionista"): nao chama triagem.
      expect(paths, [AuthRepository.registerPatientPath]);
      expect(corpoCadastro, {
        'nome': 'Alex Silva',
        'email': 'alex@email.com',
        'senha': '12345678',
      });
      expect(auth.status, AuthStatus.authenticated);
    });

    test('registerPatient autonomo envia a triagem do paciente', () async {
      final paths = <String>[];
      Map<String, dynamic>? corpoTriagem;
      final auth = _controller(
        MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path == AuthRepository.triagemPath(7)) {
            corpoTriagem = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response('{}', 200);
          }
          return _tokenOut(validToken, status: 201);
        }),
        _MemoryStorage(),
        (c) => c,
      );

      await auth.registerPatient(
        const PatientSignup(
          name: 'Alex Silva',
          email: 'alex@email.com',
          password: '12345678',
          age: 25,
          gender: 'masculino',
          heightCm: 175,
          weightKg: 70.5,
          activityLevel: 'moderado',
        ),
      );

      expect(paths, [
        AuthRepository.registerPatientPath,
        AuthRepository.triagemPath(7),
      ]);
      expect(corpoTriagem, {
        'peso_kg': 70.5,
        'altura_cm': 175.0,
        'idade': 25,
        'genero': 'masculino',
        'nivel_atividade': 'moderado',
      });
    });

    test('falha na triagem nao desfaz o cadastro', () async {
      final auth = _controller(
        MockClient((request) async {
          if (request.url.path == AuthRepository.triagemPath(7)) {
            return http.Response('{"detail":[]}', 422);
          }
          return _tokenOut(validToken, status: 201);
        }),
        _MemoryStorage(),
        (c) => c,
      );

      await auth.registerPatient(
        const PatientSignup(
          name: 'Alex Silva',
          email: 'alex@email.com',
          password: '12345678',
          age: 25,
          gender: 'outro',
          heightCm: 175,
          weightKg: 70.5,
          activityLevel: 'moderado',
        ),
      );

      expect(auth.status, AuthStatus.authenticated);
    });

    test('linkProfessional resgata o codigo e devolve o nome', () async {
      Map<String, dynamic>? corpo;
      final auth = _controller(
        MockClient((request) async {
          expect(request.url.path, AuthRepository.linkPath);
          corpo = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'nutricionista': {'id': 1, 'nome': 'Dra. Camila Mendes'},
              'vinculado_em': '2026-11-05T12:00:00Z',
            }),
            200,
          );
        }),
        _MemoryStorage(),
        (c) => c,
      );

      final professional = await auth.linkProfessional('123456');

      expect(corpo, {'codigo': '123456'});
      expect(professional.name, 'Dra. Camila Mendes');
    });

    test('linkProfessional le id, foto e status pendente', () async {
      final auth = _controller(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'nutricionista': {
                'id': 4,
                'nome': 'Dra. Camila Mendes',
                'foto_url': 'http://img.test/c.png',
              },
              'vinculado_em': '2026-11-05T12:00:00Z',
              'status': 'pendente',
            }),
            200,
          );
        }),
        _MemoryStorage(),
        (c) => c,
      );

      final professional = await auth.linkProfessional('123456');

      expect(professional.id, 4);
      expect(professional.photoUrl, 'http://img.test/c.png');
      expect(professional.isPending, isTrue);
    });

    test('acceptLink e refuseLink chamam as rotas do vinculo', () async {
      final paths = <String>[];
      final auth = _controller(
        MockClient((request) async {
          expect(request.method, 'POST');
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'vinculo_id': 1,
              'paciente_id': 7,
              'nutricionista_id': 4,
              'status': 'ativo',
            }),
            200,
          );
        }),
        _MemoryStorage(),
        (c) => c,
      );

      await auth.acceptLink(4);
      await auth.refuseLink(4);

      expect(paths, ['/link/4/aceitar', '/link/4/recusar']);
    });

    test(
      'acceptLink propaga o erro quando o vinculo nao esta pendente',
      () async {
        final auth = _controller(
          MockClient((request) async {
            return http.Response(
              jsonEncode({'detail': 'Vinculo nao esta pendente'}),
              409,
            );
          }),
          _MemoryStorage(),
          (c) => c,
        );

        expect(
          auth.acceptLink(4),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );
      },
    );
  });
}
