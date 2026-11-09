import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/features/auth/data/jwt_utils.dart';

String _jwt(Map<String, dynamic> payload) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc(payload)}.assinatura';
}

void main() {
  group('JwtUtils', () {
    final exp = DateTime.utc(2030, 1, 1);
    final token = _jwt({'sub': '1', 'exp': exp.millisecondsSinceEpoch ~/ 1000});

    test('le o exp do token', () {
      expect(JwtUtils.expiresAt(token), exp);
    });

    test('devolve null sem exp ou com token malformado', () {
      expect(JwtUtils.expiresAt(_jwt({'sub': '1'})), isNull);
      expect(JwtUtils.expiresAt('nao-e-um-jwt'), isNull);
      expect(JwtUtils.expiresAt('a.b.c'), isNull);
    });

    test('isExpired compara com o instante atual', () {
      expect(JwtUtils.isExpired(token, now: DateTime.utc(2029, 12, 31)), false);
      expect(JwtUtils.isExpired(token, now: DateTime.utc(2030, 1, 2)), true);
    });

    test('sem exp nao considera expirado', () {
      expect(JwtUtils.isExpired(_jwt({'sub': '1'})), isFalse);
    });

    test('subject le o id do usuario do claim sub', () {
      expect(JwtUtils.subject(token), 1);
      expect(JwtUtils.subject(_jwt({'sub': 42})), 42);
    });

    test('subject devolve null sem sub valido ou com token malformado', () {
      expect(JwtUtils.subject(_jwt({'exp': 1})), isNull);
      expect(JwtUtils.subject(_jwt({'sub': 'abc'})), isNull);
      expect(JwtUtils.subject('nao-e-um-jwt'), isNull);
    });
  });
}
