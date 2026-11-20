import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/patient_profile.dart';

/// Perfil do paciente na API (BE-11).
class ProfileRepository {
  ProfileRepository(this._client);

  static String path(int patientId) => '/pacientes/$patientId/perfil';

  final ApiClient _client;

  Future<PatientProfile> fetch(int patientId) async {
    final response = await _client.get(path(patientId));
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do perfil.');
    }
    try {
      return PatientProfile.fromJson(response);
    } on Object {
      throw const ApiException('Não foi possível ler o seu perfil.');
    }
  }
}
