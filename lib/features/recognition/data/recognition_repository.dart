import '../../../core/network/api_client.dart';
import '../domain/detected_item.dart';
import '../domain/nutrition_estimate.dart';

/// Calculo e registro da refeicao revisada (RF02.1, RF02.3, RF03).
class RecognitionRepository {
  const RecognitionRepository(this._client);

  final ApiClient _client;

  /// Tabela nutricional dos [items] como estao agora (classe, preparo e
  /// gramas). Nao grava nada.
  Future<NutritionEstimate> calculate(List<DetectedItem> items) async {
    final result = await _client.post('/calculo-nutricional', {
      'itens': [for (final item in items) item.toCalculationJson()],
    });
    return NutritionEstimate.fromJson(result as Map<String, dynamic>);
  }

  /// Registra a refeicao com os itens calculados.
  ///
  /// O tipo nao e enviado: a API sugere pelo horario de [consumedAt]. O
  /// `paciente_id` vai no corpo ate a Task 1.2 tirar o paciente do token.
  Future<void> saveMeal({
    required int patientId,
    required DateTime consumedAt,
    required NutritionEstimate estimate,
  }) async {
    await _client.post('/refeicoes', {
      'paciente_id': patientId,
      'consumida_em': consumedAt.toUtc().toIso8601String(),
      'itens': [for (final item in estimate.items) item.toMealItemJson()],
    });
  }
}
