import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/app_services.dart';
import 'package:nutri_vision/core/config/app_theme.dart';
import 'package:nutri_vision/features/achievements/data/achievement_repository.dart';
import 'package:nutri_vision/features/challenges/data/challenge_repository.dart';
import 'package:nutri_vision/features/meals/data/meal_repository.dart';
import 'package:nutri_vision/features/plan/data/plan_repository.dart';
import 'package:nutri_vision/features/privacy/data/privacy_repository.dart';
import 'package:nutri_vision/features/profile/application/profile_controller.dart';
import 'package:nutri_vision/features/profile/data/profile_repository.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/recognition/presentation/photo_analysis_page.dart';
import 'package:nutri_vision/features/reminders/application/push_service.dart';
import 'package:nutri_vision/features/reminders/data/reminder_repository.dart';
import 'package:nutri_vision/features/screening/data/screening_repository.dart';
import 'package:nutri_vision/features/shell/presentation/main_shell.dart';
import 'package:nutri_vision/features/achievements/presentation/achievements_page.dart';
import 'package:nutri_vision/features/challenges/presentation/challenges_page.dart';
import 'package:nutri_vision/features/foods/presentation/food_search_page.dart';
import 'package:nutri_vision/features/linking/presentation/linking_page.dart';
import 'package:nutri_vision/features/meals/presentation/meal_history_page.dart';
import 'package:nutri_vision/features/plan/presentation/plan_progress_page.dart';
import 'package:nutri_vision/features/privacy/presentation/privacy_settings_page.dart';
import 'package:nutri_vision/features/reminders/presentation/meal_reminders_page.dart';
import 'package:nutri_vision/features/screening/presentation/screening_page.dart';

import 'support/session.dart';

final invites = <String>[];
final responses = <String>[];

/// Monta as abas com a API falsa e um paciente (7) logado.
Future<AppServices> pumpShell(
  WidgetTester tester, {
  http.Client? api,
  int initialTab = 0,
  Map<String, Object?>? profile,
}) async {
  tester.view.physicalSize = const Size(430, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (client, auth) = await loggedSession(
    api ??
        MockClient((request) async {
          if (request.url.path == ProfileRepository.path(7)) {
            return jsonResponse(profile ?? profileJson());
          }
          if (request.url.path == MealRepository.dailyConsumptionPath) {
            return jsonResponse(consumptionJson(kcal: 1500));
          }
          if (request.url.path == '/gamificacao/conquistas') {
            return jsonResponse(achievementsJson());
          }
          if (request.url.path == '/gamificacao/leaderboard') {
            return jsonResponse(rankingJson());
          }
          if (request.url.path == '/amizades' && request.method == 'GET') {
            return jsonResponse(friendshipsJson());
          }
          if (request.url.path == '/amizades' && request.method == 'POST') {
            invites.add(request.body);
            return jsonResponse({'id': 9}, 201);
          }
          if (request.url.path.startsWith('/amizades/')) {
            responses
                .add('${request.method} ${request.url.path} ${request.body}');
            return jsonResponse({'id': 3});
          }
          return jsonResponse(<Object>[]);
        }),
  );
  final services = AppServices(
    client: client,
    auth: auth,
    profile:
        ProfileController(auth: auth, repository: ProfileRepository(client)),
    screening: ScreeningRepository(client),
    plans: PlanRepository(client),
    reminders: ReminderRepository(client),
    push: const DisabledPushService(),
    meals: MealRepository(client),
    recognition: RecognitionRepository(client),
    challenges: ChallengeRepository(client),
    achievements: AchievementRepository(client),
    privacy: PrivacyRepository(client),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: MainShell(services: services, initialTab: initialTab),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_URL=http://api.test'));

  testWidgets('barra inferior com as quatro abas do prototipo', (tester) async {
    await pumpShell(tester);

    for (final label in MainShell.tabLabels) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
    expect(find.text('Nutri Vision'), findsOneWidget);
    expect(find.text('520 XP'), findsOneWidget);
  });

  testWidgets('Inicio mostra a meta no anel, as macros e as conquistas',
      (tester) async {
    await pumpShell(tester);

    expect(find.text('Meta Diária'), findsOneWidget);
    expect(find.text('1.500'), findsOneWidget);
    expect(find.text('/ 2.000 kcal'), findsOneWidget);
    expect(find.text('Restam 500 kcal para o seu objetivo!'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Consumido hoje: 1.500 de 2.000 quilocalorias'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Proteína: 80g de 120g'), findsOneWidget);
    expect(find.bySemanticsLabel('Carbo: 150g de 200g'), findsOneWidget);
    expect(find.bySemanticsLabel('Gordura: 40g de 60g'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Suas Conquistas'), 200);
    expect(find.bySemanticsLabel('Iniciante: obtida'), findsOneWidget);
    expect(find.text('Focado'), findsOneWidget);
  });

  testWidgets('Inicio sem meta pede a triagem', (tester) async {
    await pumpShell(tester, profile: profileJson(kcal: null, source: null));

    expect(
      find.text('Faça a triagem para calcular a sua meta diária.'),
      findsOneWidget,
    );
    expect(find.text('Calcular minha meta'), findsOneWidget);
  });

  testWidgets('aba Registrar abre o registro por foto', (tester) async {
    await pumpShell(tester);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Registrar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto do prato'));
    await tester.pumpAndSettle();

    final page =
        tester.widget<PhotoAnalysisPage>(find.byType(PhotoAnalysisPage));
    expect(page.patientId, 7);
    expect(page.foods, isNotNull);
  });

  testWidgets('aba Registrar tem foto, manual e historico', (tester) async {
    await pumpShell(tester, initialTab: 1);

    expect(find.text('Foto do prato'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
    await tester.tap(find.text('Adicionar manualmente'));
    await tester.pumpAndSettle();

    expect(find.text('Nova refeição'), findsOneWidget);
    expect(find.text('Adicionar alimento'), findsOneWidget);
  });

  testWidgets('Social mostra o ranking da semana com voce em destaque',
      (tester) async {
    await pumpShell(tester, initialTab: 2);

    expect(find.text('Ranking Social'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        '1º lugar: Maria S., 1.250 XP na semana, ofensiva de 12 dias',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        '4º lugar: Você, 520 XP na semana, ofensiva de 3 dias',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Pedidos de amizade'), 200);
    expect(find.text('Carlos Mendes quer ser seu amigo'), findsOneWidget);
  });

  testWidgets('Social: convidar amigo pelo e-mail e aceitar pedido',
      (tester) async {
    invites.clear();
    responses.clear();
    await pumpShell(tester, initialTab: 2);

    await tester.tap(find.text('Convidar Amigos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'nao-e-email');
    await tester.tap(find.text('Enviar convite'));
    await tester.pump();
    expect(find.text('Digite um e-mail válido.'), findsOneWidget);
    await tester.enterText(find.byType(TextField), ' amigo@email.com ');
    await tester.tap(find.text('Enviar convite'));
    await tester.pumpAndSettle();
    expect(invites.single, contains('"email":"amigo@email.com"'));
    expect(find.text('Convite enviado!'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('Aceitar Carlos Mendes'),
      200,
    );
    await tester.tap(find.byTooltip('Aceitar Carlos Mendes'));
    await tester.pumpAndSettle();
    expect(responses.single, 'PUT /amizades/3/responder {"aceitar":true}');
  });

  testWidgets('Perfil mostra identidade, estatisticas e divisao',
      (tester) async {
    await pumpShell(tester, initialTab: 3);

    expect(find.text('Alex Silva'), findsOneWidget);
    expect(find.text('Membro desde Fevereiro de 2024'), findsOneWidget);
    expect(find.text('12 dias de ofensiva'), findsOneWidget);
    expect(find.text('Divisão Ouro'), findsOneWidget);
    expect(find.bySemanticsLabel('Ofensiva Atual: 12'), findsOneWidget);
    expect(find.bySemanticsLabel('Total de XP: 520'), findsOneWidget);
    expect(find.bySemanticsLabel('Refeições Feitas: 36'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Divisão Atual · faltam 980 XP para Diamante: Ouro',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Meta Diária de Calorias'), 200);
    expect(find.text('2.000 kcal'), findsOneWidget);
    expect(find.text('Calculada pela sua triagem'), findsOneWidget);
  });

  testWidgets('Perfil troca o modo de exibicao para escuro', (tester) async {
    final services = await pumpShell(tester, initialTab: 3);

    await tester.scrollUntilVisible(find.text('Modo de Exibição'), 200);
    expect(find.text('Sistema'), findsOneWidget);
    await tester.tap(find.text('Modo de Exibição'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(services.theme.mode, ThemeMode.dark);
    expect(find.text('Escuro'), findsOneWidget);
  });

  testWidgets('Perfil com plano do nutricionista nao deixa refazer a meta',
      (tester) async {
    await pumpShell(
      tester,
      initialTab: 3,
      profile: profileJson(
        source: 'plano',
        nutritionist: {
          'id': 3,
          'nome': 'Dra. Camila Mendes',
          'crn': 'CRN-3 4289',
        },
      ),
    );

    await tester.scrollUntilVisible(find.text('Meta Diária de Calorias'), 200);
    expect(find.text('Definida pelo seu nutricionista'), findsOneWidget);
    expect(find.text('Dra. Camila Mendes'), findsOneWidget);
    await tester.tap(find.text('Meta Diária de Calorias'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('definida pelo seu nutricionista'),
      findsOneWidget,
    );
  });

  for (final (tab, label, page) in [
    (3, 'Lembretes de Refeição', MealRemindersPage),
    (3, 'Meus Alimentos', FoodSearchPage),
    (3, 'Privacidade e Dados (LGPD)', PrivacySettingsPage),
    (3, 'Meta Diária de Calorias', ScreeningPage),
    (3, 'Vincular nutricionista', LinkingPage),
    (2, 'Desafios entre amigos', ChallengesPage),
    (2, 'Minhas conquistas', AchievementsPage),
    (1, 'Histórico de refeições', MealHistoryPage),
    (0, 'Meu progresso', PlanProgressPage),
  ]) {
    testWidgets('$label abre a tela certa', (tester) async {
      await pumpShell(tester, initialTab: tab);

      await tester.scrollUntilVisible(find.text(label), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(find.byType(page), findsOneWidget);
    });
  }

  testWidgets('aba Perfil tem o sair da conta', (tester) async {
    final services = await pumpShell(tester, initialTab: 3);

    await tester.scrollUntilVisible(find.text('Sair da conta'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da conta'));
    await tester.pump();

    expect(services.auth.userId, isNull);
  });
}

Map<String, Object?> consumptionJson({double kcal = 0}) => {
      'paciente_id': 7,
      'data': '2026-11-19',
      'quantidade_refeicoes': kcal > 0 ? 2 : 0,
      'totais': {
        'calorias_kcal': kcal,
        'proteinas_g': 80,
        'carboidratos_g': 150,
        'gorduras_g': 40,
      },
      'refeicoes': <Object>[],
    };

List<Map<String, Object?>> achievementsJson() => [
      {
        'nome': 'Iniciante',
        'progresso': 1,
        'meta': 1,
        'obtida_em': '2026-11-01T10:00:00Z',
      },
      {'nome': 'Focado', 'progresso': 3, 'meta': 30, 'obtida_em': null},
      {'nome': 'Mestre', 'progresso': 10, 'meta': 100, 'obtida_em': null},
    ];

Map<String, Object?> rankingJson() => {
      'inicio_semana': '2026-11-16T03:00:00Z',
      'fim_semana': '2026-11-23T02:59:59Z',
      'total_participantes': 4,
      'posicao_solicitante': 4,
      'ranking': [
        {
          'posicao': 1,
          'paciente_id': 1,
          'nome': 'Maria S.',
          'xp_semanal': 1250,
          'streak': 12,
          'e_voce': false,
        },
        {
          'posicao': 2,
          'paciente_id': 2,
          'nome': 'João P.',
          'xp_semanal': 980,
          'streak': 8,
          'e_voce': false,
        },
        {
          'posicao': 3,
          'paciente_id': 3,
          'nome': 'Ana C.',
          'xp_semanal': 850,
          'streak': 5,
          'e_voce': false,
        },
        {
          'posicao': 4,
          'paciente_id': 7,
          'nome': 'Alex S.',
          'xp_semanal': 520,
          'streak': 3,
          'e_voce': true,
        },
      ],
    };

List<Map<String, Object?>> friendshipsJson() => [
      {
        'id': 3,
        'paciente_id': 5,
        'nome': 'Carlos Mendes',
        'streak': 1,
        'xp': 410,
        'status': 'pendente',
        'sou_solicitante': false,
        'criado_em': '2026-11-18T10:00:00Z',
      },
      {
        'id': 4,
        'paciente_id': 1,
        'nome': 'Maria Souza',
        'streak': 12,
        'xp': 1250,
        'status': 'aceito',
        'sou_solicitante': true,
        'criado_em': '2026-11-01T10:00:00Z',
      },
    ];
