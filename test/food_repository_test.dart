import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/api_exception.dart';
import 'package:nutri_vision/features/foods/data/food_repository.dart';

const _feijao = <String, Object>{
  'id': 7,
  'nome': 'Feijão, carioca, cozido',
  'categoria': 'Leguminosas e derivados',
  'kcal_100g': 76,
  'carbs_100g': 13.6,
  'prot_100g': 4.8,
  'gord_100g': 0.5,
};

http.Response _json(Object body, [int status = 200]) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

FoodRepository _repository(MockClientHandler handler) {
  return FoodRepository(
    ApiClient(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient(handler),
    ),
  );
}

void main() {
  group('FoodRepository', () {
    test('busca por nome na TACO e converte a resposta em Food', () async {
      Uri? chamada;
      final repository = _repository((request) async {
        chamada = request.url;
        return _json([_feijao]);
      });

      final foods = await repository.search('feijao');

      expect(chamada?.path, '/api/v1/alimentos-taco');
      expect(chamada?.queryParameters, {'nome': 'feijao', 'limite': '50'});
      expect(foods, hasLength(1));
      expect(foods.first.id, 7);
      expect(foods.first.name, 'Feijão, carioca, cozido');
      expect(foods.first.kcalPer100g, 76);
    });

    test('devolve lista vazia quando nada e encontrado', () async {
      final repository = _repository((request) async => _json([]));

      expect(await repository.search('xyz'), isEmpty);
    });

    test('propaga o erro da API', () async {
      final repository = _repository(
        (request) async => http.Response('erro', 500),
      );

      expect(
        repository.search('arroz'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
