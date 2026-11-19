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

import 'support/session.dart';

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
    await tester.tap(find.text('Registrar refeição por foto'));
    await tester.pumpAndSettle();

    final page =
        tester.widget<PhotoAnalysisPage>(find.byType(PhotoAnalysisPage));
    expect(page.patientId, 7);
    expect(page.foods, isNotNull);
  });

  testWidgets('aba Perfil tem o sair da conta', (tester) async {
    final services = await pumpShell(tester, initialTab: 3);

    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();

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
