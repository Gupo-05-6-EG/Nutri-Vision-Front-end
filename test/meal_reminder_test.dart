import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/features/meals/domain/meal_type.dart';
import 'package:nutri_vision/features/reminders/domain/meal_reminder.dart';

void main() {
  group('MealReminder', () {
    test('le o horario com segundos, como a API devolve', () {
      final reminder = MealReminder.fromJson({
        'tipo': 'almoco',
        'horario': '12:30:00',
        'ativo': true,
      });

      expect(reminder.type, MealType.lunch);
      expect(reminder.hour, 12);
      expect(reminder.minute, 30);
      expect(reminder.enabled, isTrue);
    });

    test('le o horario sem segundos', () {
      final reminder = MealReminder.fromJson({
        'tipo': 'cafe_da_manha',
        'horario': '07:05',
        'ativo': false,
      });

      expect(reminder.formattedTime, '07:05');
      expect(reminder.enabled, isFalse);
    });

    test('envia horario HH:mm e o tipo no formato da API', () {
      const reminder = MealReminder(
        type: MealType.dinner,
        hour: 8,
        minute: 5,
        enabled: true,
      );

      expect(reminder.toJson(), {
        'tipo': 'jantar',
        'horario': '08:05',
        'ativo': true,
      });
    });

    test('recusa tipo, horario ou ativo invalidos', () {
      expect(
        () => MealReminder.fromJson({
          'tipo': 'ceia',
          'horario': '22:00:00',
          'ativo': true,
        }),
        throwsFormatException,
      );
      expect(
        () => MealReminder.fromJson({
          'tipo': 'jantar',
          'horario': '25:00:00',
          'ativo': true,
        }),
        throwsFormatException,
      );
      expect(
        () => MealReminder.fromJson({
          'tipo': 'jantar',
          'horario': '20h',
          'ativo': true,
        }),
        throwsFormatException,
      );
      expect(
        () => MealReminder.fromJson({'tipo': 'jantar', 'horario': '20:00'}),
        throwsFormatException,
      );
    });

    test('sem nada salvo, devolve os 4 padroes desligados em ordem', () {
      final reminders = MealReminder.withDefaults(const []);

      expect(reminders.map((r) => r.type), MealType.values);
      expect(reminders.map((r) => r.formattedTime), [
        '08:00',
        '12:30',
        '16:00',
        '20:00',
      ]);
      expect(reminders.any((r) => r.enabled), isFalse);
    });

    test('mantem os salvos e completa os que faltam, na ordem dos tipos', () {
      const jantar = MealReminder(
        type: MealType.dinner,
        hour: 19,
        minute: 45,
        enabled: true,
      );

      final reminders = MealReminder.withDefaults([jantar]);

      expect(reminders.map((r) => r.type), MealType.values);
      expect(reminders.last, jantar);
      expect(reminders.first, MealReminder.defaults.first);
    });
  });

  group('MealReminderMessage', () {
    test('extrai o tipo de um push de lembrete', () {
      expect(
        MealReminderMessage.fromData({
          'tipo_notificacao': 'lembrete_refeicao',
          'tipo_refeicao': 'lanche',
        }),
        MealType.snack,
      );
    });

    test('ignora outros pushes e tipos invalidos', () {
      expect(
        MealReminderMessage.fromData({
          'tipo_notificacao': 'conquista',
          'tipo_refeicao': 'lanche',
        }),
        isNull,
      );
      expect(
        MealReminderMessage.fromData({
          'tipo_notificacao': 'lembrete_refeicao',
          'tipo_refeicao': 'ceia',
        }),
        isNull,
      );
      expect(MealReminderMessage.fromData(const {}), isNull);
    });
  });
}
