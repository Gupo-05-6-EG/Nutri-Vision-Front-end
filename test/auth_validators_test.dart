import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/features/auth/presentation/auth_validators.dart';

void main() {
  group('AuthValidators', () {
    test('email', () {
      expect(AuthValidators.email(''), isNotNull);
      expect(AuthValidators.email('sem-arroba'), isNotNull);
      expect(AuthValidators.email(' alex@email.com '), isNull);
    });

    test('senha nova exige 8 caracteres; login so exige preenchimento', () {
      expect(AuthValidators.newPassword('1234567'), isNotNull);
      expect(AuthValidators.newPassword('12345678'), isNull);
      expect(AuthValidators.loginPassword(''), isNotNull);
      expect(AuthValidators.loginPassword('1'), isNull);
    });

    test('codigo de vinculo tem 6 digitos', () {
      expect(AuthValidators.linkCode('12345'), isNotNull);
      expect(AuthValidators.linkCode('12345a'), isNotNull);
      expect(AuthValidators.linkCode('123456'), isNull);
    });

    test('dados corporais', () {
      expect(AuthValidators.age('9'), isNotNull);
      expect(AuthValidators.age('25'), isNull);
      expect(AuthValidators.height('99'), isNotNull);
      expect(AuthValidators.height('175'), isNull);
      expect(AuthValidators.weight('abc'), isNotNull);
      expect(AuthValidators.weight('251'), isNotNull);
      expect(AuthValidators.weight('70,5'), isNull);
    });

    test('parseDecimal aceita virgula', () {
      expect(AuthValidators.parseDecimal('70,5'), 70.5);
      expect(AuthValidators.parseDecimal('70.5'), 70.5);
    });
  });
}
