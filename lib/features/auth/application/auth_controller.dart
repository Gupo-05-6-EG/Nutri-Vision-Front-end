import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/jwt_utils.dart';
import '../data/token_storage.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Estado de sessao do app: guarda o JWT, injeta no [ApiClient] e derruba a
/// sessao quando o token expira (no boot) ou a API responde 401.
class AuthController extends ChangeNotifier {
  AuthController({
    required ApiClient client,
    required AuthRepository repository,
    required TokenStorage storage,
  })  : _client = client,
        _repository = repository,
        _storage = storage {
    _client.onUnauthorized = _handleUnauthorized;
  }

  static const sessionExpiredMessage =
      'Sua sessão expirou. Entre novamente para continuar.';

  final ApiClient _client;
  final AuthRepository _repository;
  final TokenStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  String? _notice;

  AuthStatus get status => _status;

  /// Aviso para exibir na tela inicial (ex.: sessao expirada).
  String? get notice => _notice;

  /// Le o token guardado e decide se o app abre logado ou na tela inicial.
  Future<void> restoreSession() async {
    final token = await _storage.read();

    if (token == null || token.isEmpty) {
      _setUnauthenticated();
      return;
    }

    if (JwtUtils.isExpired(token)) {
      await _storage.clear();
      _setUnauthenticated(notice: sessionExpiredMessage);
      return;
    }

    _client.authToken = token;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    final result = await _repository.login(email: email, password: password);
    await _startSession(result.token);
  }

  /// Cadastra e ja entra: a API de cadastro devolve o token.
  ///
  /// No fluxo autonomo, envia tambem os dados corporais para a triagem. A
  /// conta ja existe nesse ponto, entao uma falha na triagem nao desfaz o
  /// cadastro: o paciente refaz a triagem depois (RF14).
  Future<void> registerPatient(PatientSignup signup) async {
    final result = await _repository.registerPatient(signup);
    await _startSession(result.token);

    final triagem = signup.triagemJson();
    if (triagem == null) return;

    try {
      await _repository.submitTriagem(result.userId, triagem);
    } on ApiException {
      // Conta criada e sessao aberta; ver comentario acima.
    }
  }

  /// Resgata o codigo de vinculo do nutricionista (paciente ja logado).
  Future<LinkedProfessional> linkProfessional(String code) =>
      _repository.linkProfessional(code);

  Future<void> logout() => _endSession();

  Future<void> _startSession(String token) async {
    await _storage.save(token);
    _client.authToken = token;
    _notice = null;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  void _handleUnauthorized() {
    if (_status != AuthStatus.authenticated) return;
    unawaited(_endSession(notice: sessionExpiredMessage));
  }

  Future<void> _endSession({String? notice}) async {
    _client.authToken = null;
    _setUnauthenticated(notice: notice);
    await _storage.clear();
  }

  void _setUnauthenticated({String? notice}) {
    _notice = notice;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.onUnauthorized = null;
    super.dispose();
  }
}
