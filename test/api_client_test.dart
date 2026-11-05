import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';

void main() {
  group('ApiClient', () {
    test('monta a URL a partir do baseUrl e decodifica o JSON', () async {
      Uri? chamada;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          chamada = request.url;
          return http.Response(
            jsonEncode({'status': 'ok'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final resultado = await client.get('/health');

      expect(chamada.toString(), 'http://api.test/api/v1/health');
      expect(resultado, {'status': 'ok'});
    });

    test('envia o Authorization quando ha token', () async {
      String? autorizacao;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          autorizacao = request.headers['Authorization'];
          return http.Response('{}', 200);
        }),
      )..authToken = 'jwt-de-teste';

      await client.get('/qualquer');

      expect(autorizacao, 'Bearer jwt-de-teste');
    });

    test('nao envia Authorization quando nao ha token', () async {
      String? autorizacao;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          autorizacao = request.headers['Authorization'];
          return http.Response('{}', 200);
        }),
      );

      await client.get('/qualquer');

      expect(autorizacao, isNull);
    });

    test('serializa o corpo do POST como JSON', () async {
      String? corpo;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          corpo = request.body;
          return http.Response('{}', 201);
        }),
      );

      await client.post('/refeicoes', {'tipo': 'almoco'});

      expect(corpo, jsonEncode({'tipo': 'almoco'}));
    });

    test('converte status de erro em ApiException', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient(
          (request) async => http.Response('nao autenticado', 401),
        ),
      );

      await expectLater(
        client.get('/privado'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.isUnauthorized, 'isUnauthorized', isTrue),
        ),
      );
    });

    test('devolve null em 204', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async => http.Response('', 204)),
      );

      expect(await client.delete('/refeicoes/1'), isNull);
    });

    test('PUT envia JSON com token e DELETE usa o metodo certo', () async {
      final chamadas = <http.Request>[];
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async {
          chamadas.add(request);
          return http.Response('{"id": 1}', 200);
        }),
      )..authToken = 'abc';

      await client.put('/refeicoes/1', {'observacao': 'sem sal'});
      await client.delete('/refeicoes/1');

      expect(chamadas.map((c) => c.method), ['PUT', 'DELETE']);
      expect(jsonDecode(chamadas.first.body), {'observacao': 'sem sal'});
      expect(chamadas.first.headers['Content-Type'], 'application/json');
      for (final chamada in chamadas) {
        expect(chamada.headers['Authorization'], 'Bearer abc');
      }
      expect(chamadas.last.headers.containsKey('Content-Type'), isFalse);
    });

    test('monta a query string com valores nao textuais', () async {
      Uri? chamada;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          chamada = request.url;
          return http.Response('[]', 200);
        }),
      );

      await client.get('/refeicoes', query: {'paciente_id': 7, 'limite': 50});

      expect(chamada!.queryParameters, {'paciente_id': '7', 'limite': '50'});
    });

    test('decodifica acentos em UTF-8 mesmo sem charset no header', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode('{"nome": "Feijão, carioca, cozido"}'),
            200,
          ),
        ),
      );

      expect(await client.get('/x'), {'nome': 'Feijão, carioca, cozido'});
    });

    test('falha de rede vira ApiException sem statusCode', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient(
          (request) async => throw http.ClientException('sem rede'),
        ),
      );

      await expectLater(
        client.post('/refeicoes', {}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.message, 'message', contains('sem rede')),
        ),
      );
    });

    test('erro sem corpo usa o status na mensagem', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        httpClient: MockClient((request) async => http.Response('', 500)),
      );

      await expectLater(
        client.get('/x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'HTTP 500')
              .having((e) => e.isUnauthorized, 'isUnauthorized', isFalse)
              .having((e) => e.toString(), 'toString', contains('500')),
        ),
      );
    });
  });
}
