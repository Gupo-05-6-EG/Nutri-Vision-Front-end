import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/config/app_theme.dart';
import 'package:nutri_vision/features/privacy/data/privacy_repository.dart';
import 'package:nutri_vision/features/privacy/presentation/privacy_settings_page.dart';

import 'support/session.dart';

final _consent = {
  'consentimentos': [
    {
      'versao_termo': 'v1',
      'aceito_em': '2026-11-01T10:00:00Z',
      'revogado_em': null,
    },
  ],
  'consentimento_ativo': true,
};

Future<List<String>> _pump(
  WidgetTester tester, {
  SaveExport? save,
}) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = <String>[];
  final (client, auth) = await loggedSession(
    MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      return switch (request.url.path) {
        '/privacidade/consentimento' => jsonResponse(_consent),
        '/privacidade/dados' => jsonResponse({
            'usuario': {'nome': 'Alex Silva'},
            'refeicoes': <Object>[],
          }),
        '/privacidade/consentimento/revogar' => jsonResponse({
            'versao_termo': 'v1',
            'aceito_em': '2026-11-01T10:00:00Z',
            'revogado_em': '2026-11-19T10:00:00Z',
          }),
        '/privacidade/conta' => http.Response('', 204),
        _ => http.Response('', 404),
      };
    }),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PrivacySettingsPage(
        auth: auth,
        repository: PrivacyRepository(client),
        saveExport: save ?? (_, __) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('exporta os dados em JSON (B3 corrigido no back-end)',
      (tester) async {
    Uint8List? saved;
    String? name;
    final calls = await _pump(
      tester,
      save: (bytes, filename) async {
        saved = bytes;
        name = filename;
      },
    );

    await tester.tap(find.text('Exportar meus dados (JSON)'));
    await tester.pumpAndSettle();

    expect(calls, contains('GET /privacidade/dados'));
    expect(name, 'nutri-vision-dados.json');
    expect(jsonDecode(utf8.decode(saved!))['usuario']['nome'], 'Alex Silva');
    expect(find.text('Seus dados foram exportados.'), findsOneWidget);
  });

  testWidgets('revoga o consentimento depois de confirmar', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.text('Revogar consentimento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revogar').last);
    await tester.pumpAndSettle();

    expect(calls, contains('POST /privacidade/consentimento/revogar'));
  });

  testWidgets('excluir a conta pede confirmacao e encerra a sessao',
      (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.text('Excluir conta e dados'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir conta e dados?'), findsOneWidget);
    await tester.tap(find.text('Excluir permanentemente'));
    await tester.pumpAndSettle();

    expect(calls, contains('DELETE /privacidade/conta'));
  });
}
