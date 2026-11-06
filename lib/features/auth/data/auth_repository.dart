import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_models.dart';

/// Chamadas de autenticacao da API (Task 1.2 [Back] e Task 1.4 [Back]).
class AuthRepository {
  AuthRepository(this._client);

  static const loginPath = '/auth/login';
  static const registerPatientPath = '/auth/cadastro/paciente';
  static const linkPath = '/link';

  static String triagemPath(int patientId) => '/pacientes/$patientId/triagem';

  final ApiClient _client;

  /// Login e cadastro devolvem o mesmo `TokenOut`.
  AuthResult _readAuth(dynamic data) {
    final token = data is Map ? data['access_token'] : null;
    final user = data is Map ? data['usuario'] : null;
    final id = user is Map ? user['id'] : null;

    if (token is! String || token.isEmpty || id is! int) {
      throw const ApiException('Resposta de autenticacao sem token.');
    }
    return AuthResult(token: token, userId: id);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final data = await _client.post(loginPath, {
      'email': email,
      'senha': password,
    });
    return _readAuth(data);
  }

  /// Cadastra o paciente e ja devolve o token.
  Future<AuthResult> registerPatient(PatientSignup signup) async {
    final data = await _client.post(registerPatientPath, signup.toJson());
    return _readAuth(data);
  }

  /// Envia os dados corporais do paciente (gera o teto calorico).
  Future<void> submitTriagem(int patientId, Map<String, dynamic> body) =>
      _client.post(triagemPath(patientId), body);

  /// Resgata o codigo de vinculo. Exige o token do paciente ja em uso.
  Future<LinkedProfessional> linkProfessional(String code) async {
    final data = await _client.post(linkPath, {'codigo': code});

    final professional = data is Map ? data['nutricionista'] : null;
    if (professional is! Map) {
      throw const ApiException('Resposta inesperada ao usar o codigo.');
    }
    final id = professional['id'];
    final photo = professional['foto_url'];
    return LinkedProfessional(
      id: id is int ? id : null,
      name: (professional['nome'] ?? '').toString(),
      photoUrl: photo is String && photo.isNotEmpty ? photo : null,
      status: (data is Map ? data['status'] : null)?.toString() ??
          LinkedProfessional.pendingStatus,
    );
  }

  static String acceptLinkPath(int professionalId) =>
      '$linkPath/$professionalId/aceitar';

  static String refuseLinkPath(int professionalId) =>
      '$linkPath/$professionalId/recusar';

  /// O paciente aceita o vinculo pendente com o nutricionista.
  Future<void> acceptLink(int professionalId) =>
      _client.post(acceptLinkPath(professionalId), const {});

  /// O paciente recusa o vinculo pendente com o nutricionista.
  Future<void> refuseLink(int professionalId) =>
      _client.post(refuseLinkPath(professionalId), const {});
}
