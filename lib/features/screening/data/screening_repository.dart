import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/screening.dart';

/// Chamada da triagem na API (Task 1.3 [Back]).
class ScreeningRepository {
  ScreeningRepository(this._client);

  static String path(int patientId) => '/pacientes/$patientId/triagem';

  final ApiClient _client;

  /// Envia a triagem e devolve o teto calorico gerado (ja salvo no paciente).
  /// Refazer a triagem sobrescreve a meta anterior.
  Future<CalorieGoal> submit(int patientId, ScreeningData data) async {
    final response = await _client.post(path(patientId), data.toJson());
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada da triagem.');
    }
    try {
      return CalorieGoal.fromJson(response);
    } on FormatException catch (error) {
      throw ApiException(error.message);
    }
  }
}
