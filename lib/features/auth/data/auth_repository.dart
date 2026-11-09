import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import 'auth_models.dart';

/// Chamadas de autenticacao da API (Task 1.2 [Back] e Task 1.4 [Back]).
class AuthRepository {
  AuthRepository(this._client);

  static const loginPath = '/auth/login';
  static const registerPatientPath = '/auth/cadastro/paciente';
  static const linkPath = '/link';

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

  /// Resgata o codigo de vinculo. Exige o token do paciente ja em uso.
  Future<LinkedProfessional> linkProfessional(String code) async {
    final data = await _client.post(linkPath, {'codigo': code});

    final professional = data is Map ? data['nutricionista'] : null;
    if (professional is! Map) {
      throw const ApiException('Resposta inesperada ao usar o codigo.');
    }
    return LinkedProfessional(name: (professional['nome'] ?? '').toString());
  }
}
