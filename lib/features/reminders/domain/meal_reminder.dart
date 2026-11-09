import '../../meals/domain/meal_type.dart';

/// Horario de lembrete de um tipo de refeicao (RF26).
///
/// O back-end interpreta o horario como hora local de America/Sao_Paulo e so
/// envia o push se a refeicao daquele tipo ainda nao foi registrada.
class MealReminder {
  const MealReminder({
    required this.type,
    required this.hour,
    required this.minute,
    this.enabled = false,
  })  : assert(hour >= 0 && hour < 24),
        assert(minute >= 0 && minute < 60);

  final MealType type;
  final int hour;
  final int minute;
  final bool enabled;

  /// Sugestao para os tipos que o paciente ainda nao configurou. Comecam
  /// desligados: o paciente escolhe quais quer receber.
  static const defaults = [
    MealReminder(type: MealType.breakfast, hour: 8, minute: 0),
    MealReminder(type: MealType.lunch, hour: 12, minute: 30),
    MealReminder(type: MealType.snack, hour: 16, minute: 0),
    MealReminder(type: MealType.dinner, hour: 20, minute: 0),
  ];

  /// Sempre um lembrete por tipo, na ordem de [MealType.values]: os salvos
  /// prevalecem e os que faltam vem de [defaults].
  static List<MealReminder> withDefaults(Iterable<MealReminder> saved) {
    final byType = {for (final reminder in saved) reminder.type: reminder};
    return [
      for (final fallback in defaults) byType[fallback.type] ?? fallback,
    ];
  }

  /// `{"tipo": "almoco", "horario": "12:30:00", "ativo": true}`.
  factory MealReminder.fromJson(Map<String, dynamic> json) {
    final type = MealType.fromApi(json['tipo'] as String?);
    if (type == null) {
      throw FormatException('Tipo de refeicao invalido: ${json['tipo']}');
    }
    final time = _parseTime(json['horario']);
    final enabled = json['ativo'];
    if (enabled is! bool) {
      throw const FormatException('Campo "ativo" ausente no lembrete.');
    }
    return MealReminder(
      type: type,
      hour: time.$1,
      minute: time.$2,
      enabled: enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'tipo': type.apiValue,
        'horario': formattedTime,
        'ativo': enabled,
      };

  /// `HH:mm`, o formato enviado a API e exibido na tela.
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  MealReminder copyWith({int? hour, int? minute, bool? enabled}) =>
      MealReminder(
        type: type,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        enabled: enabled ?? this.enabled,
      );

  /// Aceita `HH:mm` e `HH:mm:ss` (a API devolve com segundos).
  static (int, int) _parseTime(Object? value) {
    if (value is String) {
      final match = RegExp(r'^(\d{2}):(\d{2})(:\d{2}(\.\d+)?)?$').firstMatch(
        value,
      );
      if (match != null) {
        final hour = int.parse(match.group(1)!);
        final minute = int.parse(match.group(2)!);
        if (hour < 24 && minute < 60) return (hour, minute);
      }
    }
    throw FormatException('Horario de lembrete invalido: $value');
  }

  @override
  bool operator ==(Object other) =>
      other is MealReminder &&
      other.type == type &&
      other.hour == hour &&
      other.minute == minute &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(type, hour, minute, enabled);

  @override
  String toString() => 'MealReminder(${type.apiValue}, $formattedTime, '
      '${enabled ? 'ativo' : 'inativo'})';
}

/// Conteudo (`data`) do push enviado pelo job de lembretes do back-end.
class MealReminderMessage {
  const MealReminderMessage._();

  static const kindKey = 'tipo_notificacao';
  static const kind = 'lembrete_refeicao';
  static const mealTypeKey = 'tipo_refeicao';

  /// Tipo da refeicao do lembrete, ou `null` se o push nao for um lembrete de
  /// refeicao valido.
  static MealType? fromData(Map<String, dynamic> data) {
    if (data[kindKey] != kind) return null;
    return MealType.fromApi(data[mealTypeKey] as String?);
  }
}
