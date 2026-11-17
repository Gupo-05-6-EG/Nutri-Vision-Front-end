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
import 'package:nutri_vision/features/foods/data/food_repository.dart';
import 'package:nutri_vision/features/home/presentation/home_placeholder_page.dart';
import 'package:nutri_vision/features/plan/data/plan_repository.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/recognition/presentation/photo_analysis_page.dart';
import 'package:nutri_vision/features/reminders/application/push_service.dart';
import 'package:nutri_vision/features/reminders/data/reminder_repository.dart';
import 'package:nutri_vision/features/screening/data/screening_repository.dart';

/// Entrada do registro por foto na home.

class _MemoryStorage implements TokenStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

Future<void> _pumpHome(WidgetTester tester, {required bool withPhoto}) async {
  tester.view.physicalSize = const Size(900, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final client = ApiClient(
    baseUrl: 'http://api.test',
    httpClient: MockClient(
      (_) async => http.Response(
        jsonEncode({
          'access_token': 'token-do-paciente',
          'token_type': 'bearer',
          'usuario': {'id': 7, 'nome': 'Alex', 'perfil': 'paciente'},
        }),
        200,
      ),
    ),
  );
  final auth = AuthController(
    client: client,
    repository: AuthRepository(client),
    storage: _MemoryStorage(),
  );
  await auth.login(email: 'alex@email.com', password: 'senha-forte-123');

  await tester.pumpWidget(
    MaterialApp(
      home: HomePlaceholderPage(
        auth: auth,
        screening: ScreeningRepository(client),
        plans: PlanRepository(client),
        reminders: ReminderRepository(client),
        push: const DisabledPushService(),
        recognition: withPhoto ? RecognitionRepository(client) : null,
        tacoFoods: withPhoto ? FoodRepository(client) : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => dotenv.testLoad(fileInput: 'API_URL=http://api.test'));

  testWidgets('botao da home abre o registro por foto', (tester) async {
    await _pumpHome(tester, withPhoto: true);

    await tester.tap(find.text('Registrar refeição por foto'));
    await tester.pumpAndSettle();

    final page = tester.widget<PhotoAnalysisPage>(
      find.byType(PhotoAnalysisPage),
    );
    expect(page.patientId, 7);
    expect(page.foods, isNotNull);
    expect(find.text('Tirar foto'), findsOneWidget);
    expect(find.text('Escolher da galeria'), findsOneWidget);
  });

  testWidgets('sem o repositorio da IA o botao nao aparece', (tester) async {
    await _pumpHome(tester, withPhoto: false);

    expect(find.text('Registrar refeição por foto'), findsNothing);
  });
}
