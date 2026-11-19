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
