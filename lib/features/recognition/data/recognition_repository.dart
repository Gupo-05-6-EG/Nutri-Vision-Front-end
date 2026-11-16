import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../meals/data/local_meal_store.dart';
import '../../meals/domain/local_meal_record.dart';
import '../../meals/domain/meal_type.dart';
import '../domain/detected_item.dart';
import '../domain/nutrition_estimate.dart';

/// Calculo e registro da refeicao revisada (RF02.1, RF02.3, RF03, RNF07).
class RecognitionRepository {
  const RecognitionRepository(this._client, {LocalMealStore? localStore})
      : _localStore = localStore;

  final ApiClient _client;
  final LocalMealStore? _localStore;

  /// Tabela nutricional dos [items] como estao agora (classe, preparo e
  /// gramas). Nao grava nada.
  Future<NutritionEstimate> calculate(List<DetectedItem> items) async {
    final result = await _client.post('/calculo-nutricional', {
      'itens': [for (final item in items) item.toCalculationJson()],
    });
    return NutritionEstimate.fromJson(result as Map<String, dynamic>);
  }

  /// Registra a refeicao com os itens calculados e o [type] escolhido (RF19).
  ///
  /// Quando ha [LocalMealStore] e a rede falha no momento do envio, salva o
  /// registro localmente com `is_synced = false` para sincronizacao automatica
  /// em lote assim que a internet voltar (Task 2.3, RNF07).
  Future<void> saveMeal({
    required int patientId,
    required DateTime consumedAt,
    required MealType type,
    required NutritionEstimate estimate,
  }) async {
    final store = _localStore;
    LocalMealRecord? localRecord;
    if (store != null) {
      localRecord = await store.saveMeal(
        patientId: patientId,
        consumedAt: consumedAt,
        type: type,
        items: [
          for (final item in estimate.items) MealItemDraft.fromEstimated(item),
        ],
        isSynced: false,
      );
    }

    try {
      final response = await _client.post('/refeicoes', {
        'paciente_id': patientId,
        'consumida_em': consumedAt.toUtc().toIso8601String(),
        'tipo': type.apiValue,
        'itens': [for (final item in estimate.items) item.toMealItemJson()],
      });
      if (store != null && localRecord != null) {
        final remoteId =
            response is Map ? (response['id'] as num?)?.toInt() : null;
        await store.markAsSynced(localRecord.localId, remoteId: remoteId);
      }
    } on ApiException catch (error) {
      if (store != null && error.statusCode == null) {
        // Sem conexao: a refeicao ja ficou salva localmente com is_synced=false.
        return;
      }
      rethrow;
    }
  }
}
