import '../../../core/network/api_client.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';

/// Acesso ao historico de refeicoes da API (RF04, RF12).
class MealRepository {
  const MealRepository(this._client);

  final ApiClient _client;

  /// Refeicoes e totais do paciente no [day] (so a data e usada), opcionalmente
  /// so as do [type] (RF19).
  ///
  /// `paciente_id` vai na query enquanto nao existe login; a Task 1.2 passa a
  /// tirar o paciente do token.
  Future<DailyConsumption> dailyConsumption({
    required int patientId,
    required DateTime day,
    MealType? type,
  }) async {
    final result = await _client.get(
      '/refeicoes/consumo-diario',
      query: {
        'paciente_id': patientId,
        'data': formatApiDate(day),
        if (type != null) 'tipo': type.apiValue,
      },
    );
    return DailyConsumption.fromJson(result as Map<String, dynamic>);
  }
}

/// `YYYY-MM-DD`, o formato de data da API.
String formatApiDate(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}
