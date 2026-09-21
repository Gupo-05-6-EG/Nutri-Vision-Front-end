import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Leitura centralizada do `.env`.
///
/// Falhar no boot com uma mensagem clara e melhor do que descobrir mais tarde
/// que a API foi chamada em `null/refeicoes`.
class Env {
  const Env._();

  static Future<void> load() => dotenv.load();

  static String _required(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError(
        'Variavel $key ausente no .env. Rode: cp .env.example .env',
      );
    }
    return value;
  }

  static String get apiUrl => _required('API_URL');

  static String get appName => dotenv.maybeGet('APP_NAME') ?? 'Nutri Vision';

  static String get environment =>
      dotenv.maybeGet('ENVIRONMENT') ?? 'development';
}
