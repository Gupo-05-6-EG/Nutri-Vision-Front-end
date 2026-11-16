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

  static double _optionalNumber(String key, double fallback) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) return fallback;
    final number = double.tryParse(value);
    if (number == null || number <= 0) {
      throw StateError('Variavel $key no .env deve ser um numero positivo.');
    }
    return number;
  }

  /// Paciente usado nas chamadas enquanto nao existe login (Task 1.2).
  static int get patientId => _optionalNumber('PACIENTE_ID', 1).toInt();

  /// Meta diaria de calorias enquanto o plano alimentar nao vem da API.
  static double get dailyGoalKcal => _optionalNumber('META_KCAL_DIARIA', 2000);

  static const _firebaseKeys = [
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_PROJECT_ID',
  ];

  /// Chaves do app Android no Firebase, usadas pelo push dos lembretes (RF26).
  ///
  /// Todas ausentes: `null` e o app roda sem push (e o caso do CI). So algumas
  /// preenchidas e erro de configuracao, entao falha com mensagem clara.
  static FirebaseConfig? get firebase {
    final values = {
      for (final key in _firebaseKeys) key: dotenv.maybeGet(key)?.trim() ?? '',
    };
    final missing = [
      for (final entry in values.entries)
        if (entry.value.isEmpty) entry.key,
    ];
    if (missing.length == _firebaseKeys.length) return null;
    if (missing.isNotEmpty) {
      throw StateError(
        'Variaveis do Firebase incompletas no .env: falta ${missing.join(', ')}. '
        'Preencha todas ou deixe todas vazias (push desligado).',
      );
    }
    return FirebaseConfig(
      apiKey: values['FIREBASE_API_KEY']!,
      appId: values['FIREBASE_APP_ID']!,
      messagingSenderId: values['FIREBASE_MESSAGING_SENDER_ID']!,
      projectId: values['FIREBASE_PROJECT_ID']!,
    );
  }
}

/// Chaves do Firebase lidas do `.env`. Ficam aqui (e nao como `FirebaseOptions`)
/// para que so o servico de push dependa dos pacotes do Firebase.
class FirebaseConfig {
  const FirebaseConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
}
