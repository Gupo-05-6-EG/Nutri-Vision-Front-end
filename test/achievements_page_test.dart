import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/achievements/data/achievement_repository.dart';
import 'package:nutri_vision/features/achievements/presentation/achievements_page.dart';

void main() {
  testWidgets('conquistas distinguem bloqueada e obtida com fonte ampliada',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final client = ApiClient(
      baseUrl: 'http://test',
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'nome': 'Uma semana',
              'progresso': 7,
              'meta': 7,
              'obtida_em': '2026-11-01',
            },
            {
              'nome': 'Cem refeições',
              'progresso': 40,
              'meta': 100,
              'obtida_em': null,
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: AchievementsPage(repository: AchievementRepository(client)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Uma semana. Obtida. 7 de 7.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Cem refeições. Bloqueada. 40 de 100.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
    client.close();
  });
}
