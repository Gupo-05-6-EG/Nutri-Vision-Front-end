import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/core/ui/nv_widgets.dart';
import 'package:nutri_vision/features/linking/presentation/link_code_widgets.dart';
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
import 'package:nutri_vision/app_services.dart';
import 'package:nutri_vision/features/achievements/data/achievement_repository.dart';
import 'package:nutri_vision/features/challenges/data/challenge_repository.dart';
import 'package:nutri_vision/features/meals/data/meal_repository.dart';
import 'package:nutri_vision/features/privacy/data/privacy_repository.dart';
import 'package:nutri_vision/features/profile/application/profile_controller.dart';
import 'package:nutri_vision/features/profile/data/profile_repository.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/shell/presentation/main_shell.dart';
import 'package:nutri_vision/features/plan/data/plan_repository.dart';
import 'package:nutri_vision/features/reminders/application/push_service.dart';
import 'package:nutri_vision/features/reminders/data/reminder_repository.dart';
import 'support/session.dart';
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

  AppServices services(ScreeningRepository screening) => AppServices(
        client: client,
        auth: auth,
        profile: ProfileController(
          auth: auth,
          repository: ProfileRepository(client),
        ),
        screening: screening,
        plans: PlanRepository(client),
        reminders: ReminderRepository(client),
        push: const DisabledPushService(),
        meals: MealRepository(client),
        recognition: RecognitionRepository(client),
        challenges: ChallengeRepository(client),
        achievements: AchievementRepository(client),
        privacy: PrivacyRepository(client),
      );

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
            AuthStatus.authenticated =>
              MainShell(services: services(screening)),
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
  await _tap(tester, find.widgetWithText(NvButton, 'Login'));
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

      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Informe sua senha.'), findsOneWidget);

      await tester.enterText(_field('E-mail'), 'alex@email');
      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));
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
      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));

      // Depois do login o app tambem busca o perfil (meta e XP do topo).
      final request = h.requests.first;
      expect(request.url.path, AuthRepository.loginPath);
      expect(jsonDecode(request.body), {
        'email': 'alex@email.com',
        'senha': 'senha-forte-123',
      });
      expect(h.auth.status, AuthStatus.authenticated);
      expect(h.storage.value, 'token-do-paciente');
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(MainShell), findsOneWidget);
      expect(find.text('Início'), findsWidgets);
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
      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));

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
      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));

      expect(find.textContaining('Não foi possível conectar'), findsOneWidget);
    });

    testWidgets('servidor fora do ar mostra a mensagem de indisponivel',
        (tester) async {
      final h = _Harness((_) async => http.Response('erro', 503));
      await h.pump(tester);
      await _openLogin(tester);

      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), '12345678');
      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));

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
      await tester.tap(find.widgetWithText(NvButton, 'Entrar'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final botao = tester.widget<NvButton>(find.byType(NvButton));
      expect(botao.onPressed, isNull);
      await tester.tap(find.byType(NvButton), warnIfMissed: false);
      expect(h.requests, hasLength(1));

      resposta.complete(http.Response(_tokenOut, 200));
      await tester.pumpAndSettle();
      expect(find.byType(MainShell), findsOneWidget);
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

    testWidgets('logout no perfil volta para as boas-vindas', (tester) async {
      final h = _Harness((_) async => http.Response(_tokenOut, 200));
      await h.pump(tester);
      await _openLogin(tester);
      await tester.enterText(_field('E-mail'), 'alex@email.com');
      await tester.enterText(_field('Senha'), '12345678');
      await _tap(tester, find.widgetWithText(NvButton, 'Entrar'));

      await _tap(tester, find.widgetWithText(NavigationDestination, 'Perfil'));
      await _tap(tester, find.text('Sair da conta'));

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(h.storage.value, isNull);
    });
  });

  group('LinkCodePage', () {
    testWidgets(
        'exige 6 digitos, mostra o profissional e segue para o cadastro',
        (tester) async {
      final h = _Harness(
        (request) async => request.url.path == '/linking-code/123456/previa'
            ? http.Response(
                jsonEncode({
                  'nutricionista': {'id': 3, 'nome': 'Dra. Camila Mendes'},
                  'crn': 'CRN-3 4289',
                  'expira_em': '2026-11-20T10:00:00Z',
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              )
            : http.Response('{"detail":"Codigo invalido ou expirado"}', 404),
      );
      await h.pump(tester);
      await _tap(tester, find.text('Tenho nutricionista'));

      await _tap(tester, find.widgetWithText(NvButton, 'Continuar'));
      expect(find.text('Digite o código de 6 dígitos.'), findsOneWidget);

      // So digitos e no maximo 6.
      await tester.enterText(_field('Código de 6 dígitos'), '12a3');
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await _tap(tester, find.widgetWithText(NvButton, 'Continuar'));
      expect(find.text('Digite o código de 6 dígitos.'), findsOneWidget);

      await tester.enterText(_field('Código de 6 dígitos'), '1234567');
      await tester.pump();
      expect(find.text('6'), findsOneWidget);
      expect(find.text('7'), findsNothing);
      await _tap(tester, find.widgetWithText(NvButton, 'Continuar'));

      final page = tester.widget<LinkedSignupPage>(
        find.byType(LinkedSignupPage),
      );
      expect(page.linkCode, '123456');
      expect(page.professional?.name, 'Dra. Camila Mendes');
      expect(find.text('Confirmar profissional?'), findsOneWidget);
      expect(find.text('Dra. Camila Mendes'), findsOneWidget);
      expect(find.text('+50 XP'), findsOneWidget);
      // So a previa publica: o codigo e resgatado depois do cadastro.
      expect(
        h.requests.map((r) => r.url.path),
        ['/linking-code/123456/previa'],
      );
    });

    testWidgets('voltar do aceite depois do cadastro leva ao Inicio',
        (tester) async {
      http.Response json(Object body) => http.Response(
            jsonEncode(body),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
      final h = _Harness((request) async {
        switch (request.url.path) {
          case '/linking-code/123456/previa':
            return json({
              'nutricionista': {'id': 3, 'nome': 'Dra. Camila Mendes'},
              'crn': 'CRN-3 4289',
              'expira_em': '2026-11-20T10:00:00Z',
            });
          case AuthRepository.registerPatientPath:
            return json({
              'access_token': fakeJwt(),
              'usuario': {'id': 7},
            });
          case '/privacidade/consentimento':
            return json({
              'versao_termo': 'v1.0',
              'aceito_em': '2026-11-20T10:00:00Z',
              'revogado_em': null,
            });
          case AuthRepository.linkPath:
            return json({
              'nutricionista': {'id': 3, 'nome': 'Dra. Camila Mendes'},
              'status': 'pendente',
            });
        }
        return http.Response('{"detail":"nao encontrado"}', 404);
      });
      await h.pump(tester);
      await _tap(tester, find.text('Tenho nutricionista'));
      await tester.enterText(_field('Código de 6 dígitos'), '123456');
      await _tap(tester, find.widgetWithText(NvButton, 'Continuar'));

      await tester.enterText(_field('Nome completo'), 'Ana Souza');
      await tester.enterText(_field('E-mail (para login)'), 'ana@email.com');
      await tester.enterText(_field('Criar senha'), 'Senha-forte-123');
      await _tap(tester, find.textContaining('Li e aceito'));
      await _tap(tester, find.textContaining('Consinto com o tratamento'));
      await _tap(
        tester,
        find.widgetWithText(NvButton, 'Criar conta e iniciar jornada!'),
      );
      expect(find.text('Aceitar vínculo'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(MainShell), findsOneWidget);
      expect(find.byType(LinkCodePage), findsNothing);
      expect(find.byType(LinkedSignupPage), findsNothing);
    });

    testWidgets('codigo invalido avisa e nao segue', (tester) async {
      final h = _Harness(
        (_) async => http.Response('{"detail":"Codigo invalido"}', 404),
      );
      await h.pump(tester);
      await _tap(tester, find.text('Tenho nutricionista'));

      await tester.enterText(_field('Código de 6 dígitos'), '654321');
      await _tap(tester, find.widgetWithText(NvButton, 'Continuar'));

      expect(
        find.textContaining('Código inválido ou expirado'),
        findsOneWidget,
      );
      expect(find.byType(LinkedSignupPage), findsNothing);
    });

    test('le o codigo do QR Code do painel', () {
      expect(parseLinkCode('nutrivision://vinculo?codigo=482913'), '482913');
      expect(parseLinkCode('482913'), '482913');
      expect(parseLinkCode('codigo 12345678'), isNull);
      expect(parseLinkCode(null), isNull);
    });
  });
}
