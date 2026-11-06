import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/core/config/env.dart';

void main() {
  group('Env', () {
    test('le as variaveis carregadas', () {
      dotenv.testLoad(
        fileInput: '''
API_URL=http://api.test/api/v1
APP_NAME=Nutri Vision
ENVIRONMENT=development
''',
      );

      expect(Env.apiUrl, 'http://api.test/api/v1');
      expect(Env.appName, 'Nutri Vision');
      expect(Env.environment, 'development');
    });

    test('usa o padrao quando a variavel e opcional e esta ausente', () {
      dotenv.testLoad(fileInput: 'API_URL=http://api.test');

      expect(Env.appName, 'Nutri Vision');
      expect(Env.environment, 'development');
      expect(Env.patientId, 1);
      expect(Env.dailyGoalKcal, 2000);
    });

    test('le o paciente e a meta diaria', () {
      dotenv.testLoad(
        fileInput: '''
API_URL=http://api.test
PACIENTE_ID=7
META_KCAL_DIARIA=1800
''',
      );

      expect(Env.patientId, 7);
      expect(Env.dailyGoalKcal, 1800);
    });

    test('falha quando a meta diaria nao e um numero positivo', () {
      dotenv.testLoad(fileInput: 'META_KCAL_DIARIA=abc');

      expect(() => Env.dailyGoalKcal, throwsStateError);
    });

    test('falha com mensagem clara quando API_URL esta ausente', () {
      dotenv.testLoad(fileInput: 'APP_NAME=Nutri Vision');

      expect(
        () => Env.apiUrl,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cp .env.example .env'),
          ),
        ),
      );
    });
  });
}
