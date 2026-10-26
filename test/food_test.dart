import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/features/foods/domain/food.dart';
import 'package:nutri_vision/features/foods/domain/number_format.dart';

void main() {
  group('Food', () {
    test('converte o JSON da API, inclusive numeros inteiros', () {
      final food = Food.fromJson({
        'id': 7,
        'nome': 'Arroz, tipo 1, cozido',
        'categoria': 'Cereais e derivados',
        'kcal_100g': 128,
        'carbs_100g': 28.1,
        'prot_100g': 2.5,
        'gord_100g': 0.2,
      });

      expect(food.id, 7);
      expect(food.name, 'Arroz, tipo 1, cozido');
      expect(food.category, 'Cereais e derivados');
      expect(food.kcalPer100g, 128.0);
      expect(food.carbsPer100g, 28.1);
      expect(food.proteinPer100g, 2.5);
      expect(food.fatPer100g, 0.2);
    });
  });

  group('parseDecimalInput', () {
    test('aceita virgula e ponto como separador decimal', () {
      expect(parseDecimalInput('150'), 150);
      expect(parseDecimalInput('22,5'), 22.5);
      expect(parseDecimalInput('22.5'), 22.5);
      expect(parseDecimalInput('  80 '), 80);
    });

    test('devolve null quando o texto nao e um numero valido', () {
      expect(parseDecimalInput(''), isNull);
      expect(parseDecimalInput('abc'), isNull);
      expect(parseDecimalInput('NaN'), isNull);
      expect(parseDecimalInput('Infinity'), isNull);
    });
  });

  group('formatNumber', () {
    test('omite a casa decimal quando o valor e inteiro', () {
      expect(formatNumber(45), '45');
      expect(formatNumber(0), '0');
      expect(formatNumber(128.0), '128');
    });

    test('usa uma casa decimal com virgula nos demais casos', () {
      expect(formatNumber(22.5), '22,5');
      expect(formatNumber(33.33), '33,3');
    });
  });
}
