import 'dart:typed_data';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../meals/data/local_meal_store.dart';
import '../../meals/domain/local_meal_record.dart';
import '../../meals/domain/meal_type.dart';
import '../domain/detected_item.dart';
import '../domain/nutrition_estimate.dart';

/// A analise demorou mais que o limite de espera.
class AnalysisTimeout implements Exception {
  const AnalysisTimeout();
}

/// Analise da foto pela IA, calculo e registro da refeicao revisada
/// (RF02.1, RF02.3, RF03, RNF07).
class RecognitionRepository {
  const RecognitionRepository(
    this._client, {
    LocalMealStore? localStore,
    this.pollInterval = const Duration(seconds: 2),
    this.analysisTimeout = const Duration(minutes: 2),
  }) : _localStore = localStore;

  static const String analysesPath = '/analises';

  final ApiClient _client;
  final LocalMealStore? _localStore;

  /// Intervalo entre as consultas do andamento da analise.
  final Duration pollInterval;

  /// Quanto esperar a IA antes de desistir ([AnalysisTimeout]).
  final Duration analysisTimeout;

  /// Envia a foto para a IA e espera o resultado: consulta
  /// `GET /analises/{id}` ate o status sair de `QUEUED`/`PROCESSING`.
  /// [onProgress] recebe cada andamento (ex.: para mostrar "na fila").
  Future<PhotoAnalysis> analyzePhoto(
    Uint8List bytes, {
    required String filename,
    void Function(AnalysisStatus status)? onProgress,
  }) async {
    final created = await _client.postFile(
      analysesPath,
      field: 'file',
      bytes: bytes,
      filename: filename,
      contentType: imageContentType(filename),
    );
    var analysis = PhotoAnalysis.fromJson(created as Map<String, dynamic>);
    final deadline = DateTime.now().add(analysisTimeout);
    while (analysis.status.isPending) {
      onProgress?.call(analysis.status);
      if (DateTime.now().isAfter(deadline)) throw const AnalysisTimeout();
      await Future<void>.delayed(pollInterval);
      final result = await _client.get('$analysesPath/${analysis.id}');
      analysis = PhotoAnalysis.fromJson(result as Map<String, dynamic>);
    }
    return analysis;
  }

  /// Tabela nutricional dos [items] como estao agora (alimento da TACO e
  /// gramas). So aceita itens que estao na TACO. Nao grava nada.
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

/// Tipo MIME da foto pela extensao do arquivo (a IA so aceita `image/*`).
String imageContentType(String filename) {
  final name = filename.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}
