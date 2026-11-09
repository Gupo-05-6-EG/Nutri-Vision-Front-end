import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';
import 'package:nutri_vision/features/auth/presentation/link_code_page.dart';
import 'package:nutri_vision/features/auth/presentation/linked_signup_page.dart';
import 'package:nutri_vision/features/auth/presentation/login_page.dart';
import 'package:nutri_vision/features/auth/presentation/welcome_page.dart';
import 'package:nutri_vision/features/home/presentation/home_placeholder_page.dart';
import 'package:nutri_vision/features/plan/data/plan_repository.dart';
import 'package:nutri_vision/features/screening/data/screening_repository.dart';

/// Testes de widget da entrada do app (Task 7.4, parte 3/4): boas-vindas,
/// login e codigo de vinculo, com a raiz trocando entre area publica e logada
/// como em `app.dart`.

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

class _Harness {
  _Harness(Future<http.Response> Function(http.Request) handler)
      : storage = _MemoryStorage() {
    client = ApiClient(
      baseUrl: 'http://api.test',
      httpClient: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    );
    auth = AuthController(
      client: client,
      repository: AuthRepository(client),
      storage: storage,
    );
  }

  final _MemoryStorage storage;
  final requests = <http.Request>[];
  late final ApiClient client;
  late final AuthController auth;

  /// Mesma troca de raiz do `NutriVisionApp`, sem o `.env` e o storage seguro.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final screening = ScreeningRepository(client);
    await tester.pumpWidget(
      MaterialApp(
        home: ListenableBuilder(
          listenable: auth,
          builder: (context, _) => switch (auth.status) {
            AuthStatus.authenticated => HomePlaceholderPage(
                auth: auth,
                screening: screening,
                plans: PlanRepository(client),
              ),
            _ => WelcomePage(auth: auth, screening: screening),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _openLogin(WidgetTester tester) async {
  await _tap(tester, find.widgetWithText(FilledButton, 'Login'));
  expect(find.byType(LoginPage), findsOneWidget);
}

void main() {
  // A home le o nome do app do `.env`.
  setUpAll(() => dotenv.testLoad(fileInput: 'API_URL=http://api.test'));

  group('WelcomePage', () {
    testWidgets('leva para login, codigo de vinculo e cadastro autonomo',
        (tester) async {
      final h = _Harness((_) async => http.Response('{}', 200));
      await h.pump(tester);

      expect(find.text('Nutri Vision!'), findsOneWidget);

      await _openLogin(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Tenho nutricionista'));
      expect(find.byType(LinkCodePage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Vou seguir sozinho'));
      expect(find.text('PASSO 1 DE 3'), findsOneWidget);
      expect(h.requests, isEmpty);
    });

    testWidgets('mostra o aviso de sessao expirada', (tester) async {
      final h = _Harness((_) async => http.Response('{}', 200));
      // Token com `exp` no passado: o boot descarta e avisa.
      String enc(Object v) =>
          base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
      h.storage.value =
          '${enc({'alg': 'HS256'})}.${enc({'sub': '7', 'exp': 1})}.x';
      await h.auth.restoreSession();
      await h.pump(tester);

      expect(find.text(AuthController.sessionExpiredMessage), findsOneWidget);
    });
  });

  group('LoginPage', () {
    testWidgets('valida e-mail e senha antes de chamar a API', (tester) async {
      final h = _Harness((_) async => http.Response(_tokenOut, 200));
      await h.pump(tester);
      await _openLogin(tester);

      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);

      await tester.enterText(_field('E-mail'), 'alex@email');
      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(find.text('E-mail inválido.'), findsOneWidget);

      expect(h.requests, isEmpty);
    });

    testWidgets('login certo envia as credenciais e abre a area logada',
        (tester) async {
      final h = _Harness((_) async => http.Response(_tokenOut, 200));
      await h.pump(tester);
      await _openLogin(tester);

      await tester.enterText(_field('E-mail'), '  alex@email.com ');
      await tester.enterText(_field('Senha'), 'senha-forte-123');
      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));

      final request = h.requests.single;
      expect(request.url.path, AuthRepository.loginPath);
      expect(jsonDecode(request.body), {
        'email': 'alex@email.com',
        'senha': 'senha-forte-123',
      });
      expect(h.auth.status, AuthStatus.authenticated);
      expect(h.storage.value, 'token-do-paciente');
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(HomePlaceholderPage), findsOneWidget);
      expect(find.text('Calcular minha meta diária'), findsOneWidget);
    });

    testWidgets('senha errada mostra a mensagem e continua no login',
        (tester) async {
      final h = _Harness(
        (_) async =>
            http.Response('{"detail":"Email ou senha invalidos"}', 401),
      );
      await h.pump(tester);
      await _openLogin(tester);

      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), 'errada');
      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(h.auth.status, isNot(AuthStatus.authenticated));
      expect(h.storage.value, isNull);
    });

    testWidgets('sem conexao mostra a mensagem de rede', (tester) async {
      final h = _Harness((_) async => throw http.ClientException('offline'));
      await h.pump(tester);
      await _openLogin(tester);

      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), '12345678');
      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));

      expect(find.textContaining('Não foi possível conectar'), findsOneWidget);
    });

    testWidgets('servidor fora do ar mostra a mensagem de indisponivel',
        (tester) async {
      final h = _Harness((_) async => http.Response('erro', 503));
      await h.pump(tester);
      await _openLogin(tester);

      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), '12345678');
      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));

      expect(find.textContaining('servidor está indisponível'), findsOneWidget);
    });

    testWidgets('desabilita o botao enquanto entra (sem envio duplo)',
        (tester) async {
      final resposta = Completer<http.Response>();
      final h = _Harness((_) => resposta.future);
      await h.pump(tester);
      await _openLogin(tester);

      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), '12345678');
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final botao = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(botao.onPressed, isNull);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(h.requests, hasLength(1));

      resposta.complete(http.Response(_tokenOut, 200));
      await tester.pumpAndSettle();
      expect(find.byType(HomePlaceholderPage), findsOneWidget);
    });

    testWidgets('botao do olho mostra e esconde a senha', (tester) async {
      final h = _Harness((_) async => http.Response('{}', 200));
      await h.pump(tester);
      await _openLogin(tester);

      bool obscured() => tester
          .widget<EditableText>(
            find.descendant(
              of: _field('Senha'),
              matching: find.byType(EditableText),
            ),
          )
          .obscureText;

      expect(obscured(), isTrue);
      await _tap(tester, find.byTooltip('Mostrar senha'));
      expect(obscured(), isFalse);
      await _tap(tester, find.byTooltip('Ocultar senha'));
      expect(obscured(), isTrue);
    });

    testWidgets('logout na home volta para as boas-vindas', (tester) async {
      final h = _Harness((_) async => http.Response(_tokenOut, 200));
      await h.pump(tester);
      await _openLogin(tester);
      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), '12345678');
      await _tap(tester, find.widgetWithText(FilledButton, 'Entrar'));

      await _tap(tester, find.byTooltip('Sair da conta'));

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(h.storage.value, isNull);
    });
  });

  group('LinkCodePage', () {
    testWidgets('exige 6 digitos e segue para o cadastro com o codigo',
        (tester) async {
      final h = _Harness((_) async => http.Response('{}', 200));
      await h.pump(tester);
      await _tap(tester, find.text('Tenho nutricionista'));

      await _tap(tester, find.widgetWithText(FilledButton, 'Continuar'));
      expect(find.text('Digite o código de 6 dígitos.'), findsOneWidget);

      // So digitos e no maximo 6.
      await tester.enterText(_field('Código de 6 dígitos'), '12a3');
      await tester.pump();
      expect(find.text('123'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Continuar'));
      expect(find.text('Digite o código de 6 dígitos.'), findsOneWidget);

      await tester.enterText(_field('Código de 6 dígitos'), '1234567');
      await tester.pump();
      expect(find.text('123456'), findsOneWidget);
      await _tap(tester, find.widgetWithText(FilledButton, 'Continuar'));

      final page = tester.widget<LinkedSignupPage>(
        find.byType(LinkedSignupPage),
      );
      expect(page.linkCode, '123456');
      // O codigo so e resgatado depois do cadastro (precisa do token).
      expect(h.requests, isEmpty);
    });
  });
}
