import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/config/app_theme.dart';
import 'package:nutri_vision/features/linking/presentation/linking_page.dart';

import 'support/session.dart';

void main() {
  testWidgets('QR Code lido preenche o codigo e busca o nutricionista',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final bodies = <String>[];
    final (_, auth) = await loggedSession(
      MockClient((request) async {
        if (request.url.path == '/link') {
          bodies.add(request.body);
          return jsonResponse({
            'nutricionista': {'id': 3, 'nome': 'Dra. Camila Mendes'},
            'vinculado_em': '2026-11-19T12:00:00Z',
            'status': 'pendente',
          }, 201);
        }
        return http.Response('', 404);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LinkingPage(auth: auth, scanCode: (_) async => '482913'),
      ),
    );
    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();

    expect(jsonDecode(bodies.single), {'codigo': '482913'});
    expect(find.text('Dra. Camila Mendes'), findsOneWidget);
    expect(find.text('Confirmar vinculação'), findsOneWidget);
  });
}
