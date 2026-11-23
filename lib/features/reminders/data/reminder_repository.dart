import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/meal_reminder.dart';

/// Lembretes de refeicao e token de push na API (Task 2.8 [Back], RF26).
class ReminderRepository {
  ReminderRepository(this._client);

  static String remindersPath(int patientId) =>
      '/pacientes/$patientId/lembretes-refeicao';

  static String devicePath(int patientId) =>
      '/pacientes/$patientId/dispositivos-push';

  final ApiClient _client;

  /// Os 4 lembretes do paciente: os salvos e, para os tipos que ainda nao
  /// foram configurados, os padroes desligados.
  Future<List<MealReminder>> fetch(int patientId) async =>
      _parse(await _client.get(remindersPath(patientId)));

  /// Salva todos os [reminders] e devolve o que a API passou a ter.
  Future<List<MealReminder>> save(
    int patientId,
    List<MealReminder> reminders,
  ) async {
    final response = await _client.put(remindersPath(patientId), {
      'lembretes': [for (final reminder in reminders) reminder.toJson()],
    });
    return _parse(response);
  }

  /// Registra o token FCM deste aparelho para o paciente (idempotente).
  Future<void> registerDevice(int patientId, String token) =>
      _client.put(devicePath(patientId), {'token': token});

  List<MealReminder> _parse(Object? response) {
    final list =
        response is Map<String, dynamic> ? response['lembretes'] : null;
    if (list is! List) {
      throw const ApiException('Resposta inesperada dos lembretes.');
    }
    try {
      return MealReminder.withDefaults([
        for (final item in list)
          MealReminder.fromJson(Map<String, dynamic>.from(item as Map)),
      ]);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    } on TypeError {
      throw const ApiException('Resposta inesperada dos lembretes.');
    }
  }
}
