import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';
import 'package:nutri_vision/features/privacy/data/privacy_repository.dart';

void main() {
  group('PrivacyRepository', () {
    test('consulta o histórico e converte consentimentos', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/privacidade/consentimento');
          return http.Response(
            jsonEncode({
              'consentimento_ativo': false,
              'consentimentos': [
                {
                  'versao_termo': '1.0',
                  'aceito_em': '2026-10-01T12:00:00Z',
                  'revogado_em': '2026-10-02T12:00:00Z',
                },
              ],
            }),
            200,
          );
        }),
      );

      final status = await PrivacyRepository(client).getConsentStatus();

      expect(status.isActive, isFalse);
      expect(status.consents, hasLength(1));
      expect(status.consents.single.version, '1.0');
      expect(status.consents.single.isActive, isFalse);
      expect(
        status.consents.single.acceptedAt.toUtc(),
        DateTime.utc(2026, 10, 1, 12),
      );
      expect(
        status.consents.single.revokedAt!.toUtc(),
        DateTime.utc(2026, 10, 2, 12),
      );
    });

    test('registra e revoga o consentimento usando os contratos da API',
        () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'versao_termo': '1.0',
              'aceito_em': '2026-10-01T12:00:00Z',
              'revogado_em': request.url.path.endsWith('/revogar')
                  ? '2026-10-02T12:00:00Z'
                  : null,
            }),
            201,
          );
        }),
      )..authToken = 'jwt-test';

      final repository = PrivacyRepository(client);
      final accepted = await repository.acceptConsent();
      final revoked = await repository.revokeConsent();

      expect(accepted.isActive, isTrue);
      expect(revoked.isActive, isFalse);
      expect(requests.map((request) => request.method), ['POST', 'POST']);
      expect(
        requests.map((request) => request.url.path),
        [
          '/api/v1/privacidade/consentimento',
          '/api/v1/privacidade/consentimento/revogar',
        ],
      );
      expect(jsonDecode(requests.first.body), {'versao_termo': '1.0'});
      expect(requests.last.headers['Authorization'], 'Bearer jwt-test');
    });

    test('exporta os dados e solicita exclusão permanente', () async {
      final requests = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.method == 'DELETE') {
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode({
              'usuario': {'nome': 'Ana'},
              'refeicoes': [],
            }),
            200,
          );
        }),
      );
      final repository = PrivacyRepository(client);

      expect(await repository.exportData(), {
        'usuario': {'nome': 'Ana'},
        'refeicoes': [],
      });
      await repository.deleteAccount();

      expect(requests.map((request) => request.method), ['GET', 'DELETE']);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/privacidade/dados',
        '/api/v1/privacidade/conta',
      ]);
    });

    test('rejeita respostas inválidas para o histórico e exportação', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async => http.Response('[]', 200)),
      );
      final repository = PrivacyRepository(client);

      await expectLater(
        repository.getConsentStatus(),
        throwsA(isA<ApiException>()),
      );
      await expectLater(repository.exportData(), throwsA(isA<ApiException>()));
    });
  });
}
