import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_models.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';
import 'package:nutri_vision/features/auth/presentation/link_confirmation_page.dart';

class _MemoryStorage implements TokenStorage {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> save(String token) async {}

  @override
  Future<void> clear() async {}
}

AuthController _auth(MockClient httpClient) {
  final client = ApiClient(baseUrl: 'http://api.test', httpClient: httpClient);
  return AuthController(
    client: client,
    repository: AuthRepository(client),
    storage: _MemoryStorage(),
  );
}

const _professional = LinkedProfessional(id: 4, name: 'Dra. Camila Mendes');

/// Abre a tela por cima de uma rota inicial, para poder ver o `popUntil`.
Future<void> _open(WidgetTester tester, AuthController auth) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => LinkConfirmationPage(
                  auth: auth,
                  professional: _professional,
                ),
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra o nutricionista e as duas opcoes', (tester) async {
    final auth = _auth(MockClient((_) async => http.Response('{}', 200)));
    await _open(tester, auth);

    expect(find.text('Dra. Camila Mendes'), findsOneWidget);
    expect(find.text('Aceitar vínculo'), findsOneWidget);
    expect(find.text('Recusar'), findsOneWidget);
  });

  testWidgets('aceitar chama a API e volta para a tela inicial', (
    tester,
  ) async {
    final paths = <String>[];
    final auth = _auth(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode({'status': 'ativo'}), 200);
      }),
    );
    await _open(tester, auth);

    await tester.tap(find.text('Aceitar vínculo'));
    await tester.pumpAndSettle();

    expect(paths, ['/link/4/aceitar']);
    expect(find.byType(LinkConfirmationPage), findsNothing);
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('recusar chama a API de recusa', (tester) async {
    final paths = <String>[];
    final auth = _auth(
      MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(jsonEncode({'status': 'recusado'}), 200);
      }),
    );
    await _open(tester, auth);

    await tester.tap(find.text('Recusar'));
    await tester.pumpAndSettle();

    expect(paths, ['/link/4/recusar']);
    expect(find.byType(LinkConfirmationPage), findsNothing);
  });

  testWidgets('erro da API fica na tela e permite tentar de novo', (
    tester,
  ) async {
    final auth = _auth(
      MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Vinculo nao esta pendente'}),
          409,
        );
      }),
    );
    await _open(tester, auth);

    await tester.tap(find.text('Aceitar vínculo'));
    await tester.pumpAndSettle();

    expect(find.byType(LinkConfirmationPage), findsOneWidget);
    expect(find.text('Vinculo nao esta pendente'), findsOneWidget);
  });
}
