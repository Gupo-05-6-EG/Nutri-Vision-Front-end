import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';

/// Ajudantes compartilhados pelos testes das telas novas (sessao ja logada).
class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> save(String token) async => value = token;

  @override
  Future<void> clear() async => value = null;
}

String fakeJwt({int userId = 7, Duration validFor = const Duration(days: 1)}) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final exp = DateTime.now().add(validFor).millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'HS256'})}.${enc({'sub': '$userId', 'exp': exp})}.x';
}

/// Cliente da API de testes e uma sessao autenticada como [userId].
Future<(ApiClient, AuthController)> loggedSession(
  http.Client httpClient, {
  int userId = 7,
}) async {
  final client = ApiClient(baseUrl: 'http://api.test', httpClient: httpClient);
  final auth = AuthController(
    client: client,
    repository: AuthRepository(client),
    storage: MemoryTokenStorage(fakeJwt(userId: userId)),
  );
  await auth.restoreSession();
  return (client, auth);
}

/// Resposta JSON em UTF-8 (os textos da API tem acentos).
http.Response jsonResponse(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Perfil devolvido por `GET /pacientes/{id}/perfil`, com valores do prototipo.
Map<String, Object?> profileJson({
  int id = 7,
  String name = 'Alex Silva',
  double? kcal = 2000,
  String? source = 'triagem',
  int xp = 520,
  int streak = 12,
  String division = 'Ouro',
  int meals = 36,
  Map<String, Object?>? nutritionist,
}) =>
    {
      'paciente_id': id,
      'nome': name,
      'email': 'alex@email.com',
      'membro_desde': '2024-02-10T12:00:00Z',
      'idade': 27,
      'genero': 'masculino',
      'peso_kg': 78.4,
      'altura_cm': 178,
      'imc': 24.7,
      'classificacao_imc': 'Eutrófico',
      'tmb_kcal': 1820,
      'nivel_atividade': 'moderado',
      'fator_atividade': 1.55,
      'meta': {
        'kcal': kcal,
        'proteinas_g': kcal == null ? null : 120,
        'carboidratos_g': kcal == null ? null : 200,
        'gorduras_g': kcal == null ? null : 60,
        'origem': source,
      },
      'gamificacao': {
        'xp': xp,
        'ofensiva': streak,
        'bloqueios': 0,
        'divisao': division,
        'proxima_divisao': 'Diamante',
        'xp_para_proxima': 980,
        'refeicoes_registradas': meals,
      },
      'nutricionista': nutritionist,
      'plano_ativo': null,
    };
