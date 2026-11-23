import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/recognition/data/photo_picker.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';

void main() {
  Future<String> sentBody(PlateType? plate) async {
    late String body;
    final client = ApiClient(
      baseUrl: 'http://api.test',
      httpClient: MockClient((request) async {
        body = utf8.decode(request.bodyBytes, allowMalformed: true);
        return http.Response(
          jsonEncode(
            {'id': 'a1', 'status': 'NOT_ESTIMATED', 'motivo': 'bad_photo'},
          ),
          202,
        );
      }),
    );
    await RecognitionRepository(client).analyzePhoto(
      Uint8List.fromList([1, 2, 3]),
      filename: 'refeicao.jpg',
      plateType: plate,
    );
    return body;
  }

  test('envia o tipo de prato escolhido na camera', () async {
    final body = await sentBody(PlateType.deep);

    expect(body, contains('name="tipo_prato"'));
    expect(body, contains('fundo'));
    expect(body, contains('name="file"'));
  });

  test('sem tipo de prato nao manda o campo', () async {
    expect(await sentBody(null), isNot(contains('tipo_prato')));
  });
}
