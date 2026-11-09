import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';
import 'package:nutri_vision/features/auth/presentation/autonomous_signup_page.dart';
import 'package:nutri_vision/features/screening/data/screening_repository.dart';
import 'package:nutri_vision/features/screening/domain/screening.dart';
import 'package:nutri_vision/features/screening/presentation/screening_page.dart';

class _MemoryStorage implements TokenStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

final _tokenOut = jsonEncode({
  'access_token': 'token-do-paciente',
  'token_type': 'bearer',
  'usuario': {'id': 7, 'nome': 'Alex', 'perfil': 'paciente'},
});

/// Resposta da triagem calculada como a API (Harris-Benedict + fator).
http.Response _triagemOk(Map<String, dynamic> body) {
  final masculino = body['genero'] == 'masculino';
  final peso = (body['peso_kg'] as num).toDouble();
  final altura = (body['altura_cm'] as num).toDouble();
  final idade = body['idade'] as int;
  final tmb = masculino
      ? 66.47 + 13.75 * peso + 5.003 * altura - 6.755 * idade
      : 655.1 + 9.563 * peso + 1.850 * altura - 4.676 * idade;
  const fatores = {
    'sedentario': 1.2,
    'leve': 1.375,
    'moderado': 1.55,
    'intenso': 1.725,
    'muito_intenso': 1.9,
  };
  final fator = fatores[body['nivel_atividade']]!;
  return http.Response(
    jsonEncode({
      'paciente_id': 7,
      'tmb_kcal': tmb,
      'fator_atividade': fator,
      'teto_calorico_kcal': tmb * fator,
      'origem_meta': 'harris_benedict',
    }),
    200,
  );
}

/// API falsa: cadastro, login e triagem. [triagem] decide a resposta.
class _Api {
  _Api({http.Response Function(Map<String, dynamic>)? triagem})
      : _triagem = triagem ?? _triagemOk;

  final http.Response Function(Map<String, dynamic>) _triagem;
  final requests = <String>[];
  final triagemBodies = <Map<String, dynamic>>[];

  late final client = ApiClient(
    baseUrl: 'http://api.test',
    httpClient: MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      switch (request.url.path) {
        case AuthRepository.registerPatientPath:
          return http.Response(_tokenOut, 201);
        case AuthRepository.loginPath:
          return http.Response(_tokenOut, 200);
        case '/pacientes/7/triagem':
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          triagemBodies.add(body);
          return _triagem(body);
      }
      return http.Response('{"detail":"sem rota"}', 404);
    }),
  );

  late final auth = AuthController(
    client: client,
    repository: AuthRepository(client),
    storage: _MemoryStorage(),
  );

  late final screening = ScreeningRepository(client);
}

/// Abre [page] por cima de uma tela inicial, como no app.
Future<void> _open(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => page),
              ),
              child: const Text('Tela inicial'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Tela inicial'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String hint, String value) async {
  await tester.enterText(find.widgetWithText(TextFormField, hint), value);
}

Future<void> _fillBody(
  WidgetTester tester, {
  String gender = 'Masculino',
}) async {
  await _type(tester, '25', '30');
  await _type(tester, '175', '180');
  await _type(tester, '70.5', '80,5');
  await _tap(tester, gender);
}

void main() {
  group('ScreeningPage', () {
    testWidgets('valida os campos do passo 1', (tester) async {
      final api = _Api();
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      expect(find.text('PASSO 1 DE 2'), findsOneWidget);
      await _tap(tester, 'Continuar');

      expect(find.text('Informe sua idade.'), findsOneWidget);
      expect(find.text('Informe sua altura em cm.'), findsOneWidget);
      expect(find.text('Informe seu peso em kg.'), findsOneWidget);
      expect(find.text('Selecione uma opção.'), findsOneWidget);
      expect(find.text('PASSO 1 DE 2'), findsOneWidget);

      await _type(tester, '25', '9');
      await _type(tester, '175', '300');
      await _type(tester, '70.5', '10');
      await _tap(tester, 'Continuar');

      expect(
        find.text('Informe uma idade entre 10 e 120 anos.'),
        findsOneWidget,
      );
      expect(
        find.text('Informe uma altura entre 100 e 250 cm.'),
        findsOneWidget,
      );
      expect(find.text('Informe um peso entre 20 e 250 kg.'), findsOneWidget);
      expect(api.requests, isEmpty);
    });

    testWidgets('triagem completa mostra a meta e como foi calculada',
        (tester) async {
      final api = _Api();
      await api.auth.login(email: 'alex@email.com', password: '12345678');
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      await _fillBody(tester);
      await _tap(tester, 'Continuar');

      expect(find.text('PASSO 2 DE 2'), findsOneWidget);
      expect(find.text('Muito intenso'), findsOneWidget);

      // Sem escolher o nivel nao envia.
      await _tap(tester, 'Calcular minha meta');
      expect(find.text('Selecione uma opção.'), findsOneWidget);
      expect(api.triagemBodies, isEmpty);

      await _tap(tester, 'Moderado');
      await _tap(tester, 'Calcular minha meta');

      expect(api.triagemBodies.single, {
        'peso_kg': 80.5,
        'altura_cm': 180.0,
        'idade': 30,
        'genero': 'masculino',
        'nivel_atividade': 'moderado',
      });

      // 66,47 + 13,75 x 80,5 + 5,003 x 180 - 6,755 x 30 = 1.871,24
      // x 1,55 = 2.900,41
      expect(find.text('Sua meta está pronta!'), findsOneWidget);
      expect(find.text('2.900'), findsOneWidget);
      expect(find.text('1.871 kcal'), findsOneWidget);
      expect(find.text('Atividade: Moderado'), findsOneWidget);
      expect(find.text('× 1,55'), findsOneWidget);
      expect(find.text('2.900 kcal'), findsOneWidget);

      await _tap(tester, 'Começar minha jornada');
      expect(find.text('Tela inicial'), findsOneWidget);
    });

    testWidgets('genero "Outro" pede a referencia usada no calculo',
        (tester) async {
      final api = _Api();
      await api.auth.login(email: 'alex@email.com', password: '12345678');
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      await _fillBody(tester, gender: 'Outro');
      expect(
        find.textContaining('referências de sexo biológico'),
        findsOneWidget,
      );

      await _tap(tester, 'Continuar');
      expect(
        find.text('Escolha qual referência usar no cálculo.'),
        findsOneWidget,
      );
      expect(find.text('PASSO 1 DE 2'), findsOneWidget);

      await _tap(tester, 'Feminina');
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Sedentário');
      await _tap(tester, 'Calcular minha meta');

      expect(api.triagemBodies.single['genero'], 'feminino');
      expect(find.text('Sua meta está pronta!'), findsOneWidget);
    });

    testWidgets('trocar "Outro" por outro genero descarta a referencia',
        (tester) async {
      final api = _Api();
      await api.auth.login(email: 'alex@email.com', password: '12345678');
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      await _fillBody(tester, gender: 'Outro');
      await _tap(tester, 'Feminina');
      await _tap(tester, 'Masculino');
      expect(find.text('Feminina'), findsNothing);

      await _tap(tester, 'Continuar');
      await _tap(tester, 'Leve');
      await _tap(tester, 'Calcular minha meta');

      expect(api.triagemBodies.single['genero'], 'masculino');
    });

    testWidgets('voltar do passo 2 mantem os dados do passo 1', (tester) async {
      final api = _Api();
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      await _fillBody(tester);
      await _tap(tester, 'Continuar');
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('PASSO 1 DE 2'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('80,5'), findsOneWidget);
    });

    testWidgets('erro da API mostra a mensagem e deixa tentar de novo',
        (tester) async {
      var falhar = true;
      final api = _Api(
        triagem: (body) =>
            falhar ? http.Response('{"detail":"erro"}', 503) : _triagemOk(body),
      );
      await api.auth.login(email: 'alex@email.com', password: '12345678');
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      await _fillBody(tester);
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Intenso');
      await _tap(tester, 'Calcular minha meta');

      expect(find.textContaining('servidor está indisponível'), findsOneWidget);
      expect(find.text('PASSO 2 DE 2'), findsOneWidget);

      falhar = false;
      await _tap(tester, 'Calcular minha meta');
      expect(find.text('Sua meta está pronta!'), findsOneWidget);
      expect(api.triagemBodies, hasLength(2));
    });

    testWidgets('sem sessao nao envia a triagem', (tester) async {
      final api = _Api();
      await _open(
        tester,
        ScreeningPage(auth: api.auth, repository: api.screening),
      );

      await _fillBody(tester);
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Leve');
      await _tap(tester, 'Calcular minha meta');

      expect(
        find.text('Entre novamente para fazer a triagem.'),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
    });
  });

  group('Cadastro autonomo + triagem', () {
    Future<void> preencherCadastro(WidgetTester tester) async {
      await _fillBody(tester, gender: 'Feminino');
      await _tap(tester, 'Continuar');
      expect(find.text('PASSO 2 DE 3'), findsOneWidget);
      await _tap(tester, 'Leve');
      await _tap(tester, 'Continuar');
      expect(find.text('PASSO 3 DE 3'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome completo'),
        'Alex Silva',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail (para login)'),
        'alex@email.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Criar senha'),
        '12345678',
      );
      await _tap(
        tester,
        'Li e aceito os Termos de Uso e a Política de Privacidade.',
      );
      await _tap(tester, 'Criar conta');
    }

    testWidgets('cria a conta, envia a triagem e mostra a meta',
        (tester) async {
      final api = _Api();
      await _open(
        tester,
        AutonomousSignupPage(auth: api.auth, screening: api.screening),
      );

      await preencherCadastro(tester);

      expect(api.requests, [
        'POST ${AuthRepository.registerPatientPath}',
        'POST /pacientes/7/triagem',
      ]);
      expect(api.triagemBodies.single, {
        'peso_kg': 80.5,
        'altura_cm': 180.0,
        'idade': 30,
        'genero': 'feminino',
        'nivel_atividade': 'leve',
      });
      expect(api.auth.status, AuthStatus.authenticated);
      expect(find.text('Sua meta está pronta!'), findsOneWidget);
      expect(find.text('Atividade: Leve'), findsOneWidget);

      // O cadastro sai da pilha: "Comecar" volta para a tela inicial.
      await _tap(tester, 'Começar minha jornada');
      expect(find.text('Tela inicial'), findsOneWidget);
    });

    testWidgets('triagem falhou: conta criada e triagem ja preenchida',
        (tester) async {
      var falhar = true;
      final api = _Api(
        triagem: (body) =>
            falhar ? http.Response('{"detail":"erro"}', 500) : _triagemOk(body),
      );
      await _open(
        tester,
        AutonomousSignupPage(auth: api.auth, screening: api.screening),
      );

      await preencherCadastro(tester);

      expect(api.auth.status, AuthStatus.authenticated);
      expect(find.textContaining('Sua conta foi criada'), findsOneWidget);
      expect(find.text('PASSO 1 DE 2'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('180'), findsOneWidget);
      expect(find.text('80,5'), findsOneWidget);

      falhar = false;
      await _tap(tester, 'Continuar');
      await _tap(tester, 'Calcular minha meta');

      expect(api.triagemBodies.last['nivel_atividade'], 'leve');
      expect(find.text('Sua meta está pronta!'), findsOneWidget);
    });

    testWidgets('erro no cadastro nao chama a triagem', (tester) async {
      final api = _Api();
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient(
          (_) async => http.Response('{"detail":"Email ja cadastrado"}', 409),
        ),
      );
      final auth = AuthController(
        client: client,
        repository: AuthRepository(client),
        storage: _MemoryStorage(),
      );
      await _open(
        tester,
        AutonomousSignupPage(auth: auth, screening: api.screening),
      );

      await preencherCadastro(tester);

      expect(find.text('Email ja cadastrado'), findsOneWidget);
      expect(find.text('PASSO 3 DE 3'), findsOneWidget);
      expect(api.triagemBodies, isEmpty);
    });
  });

  test('ScreeningData exige a referencia com genero "outro"', () {
    expect(
      () => ScreeningData(
        age: 30,
        gender: Gender.outro,
        heightCm: 170,
        weightKg: 70,
        activity: ActivityLevel.leve,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
