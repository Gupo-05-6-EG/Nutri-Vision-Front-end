import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/local_meal_record.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';
import 'local_meal_store.dart';

/// Acesso ao historico, registro local e sincronizacao em lote de refeicoes
/// (RF04, RF12, RNF07).
class MealRepository {
  const MealRepository(this._client, {LocalMealStore? localStore})
      : _localStore = localStore;

  static const String mealsPath = '/refeicoes';
  static const String batchPath = '/refeicoes/batch';
  static const String lotePath = '/refeicoes/lote';
  static const String dailyConsumptionPath = '/refeicoes/consumo-diario';

  final ApiClient _client;
  final LocalMealStore? _localStore;

  LocalMealStore? get localStore => _localStore;

  /// Refeicoes e totais do paciente no [day] (so a data e usada), opcionalmente
  /// so as do [type] (RF19).
  ///
  /// Quando ha [localStore] configurado:
  /// - Com internet: atualiza o cache local com as refeicoes da API e mescla
  ///   eventuais refeicoes locais ainda nao sincronizadas (`is_synced == false`).
  /// - Sem internet: devolve os registros locais salvos para aquele dia.
  Future<DailyConsumption> dailyConsumption({
    required int patientId,
    required DateTime day,
    MealType? type,
  }) async {
    final store = _localStore;
    try {
      final result = await _client.get(
        dailyConsumptionPath,
        query: {
          'paciente_id': patientId,
          'data': formatApiDate(day),
          if (type != null) 'tipo': type.apiValue,
        },
      );
      final remote = DailyConsumption.fromJson(result as Map<String, dynamic>);
      if (store == null) return remote;

      await store.cacheRemoteMeals(patientId, remote.meals);
      final localRecords = await store.mealsForDay(
        patientId: patientId,
        day: day,
        type: type,
      );
      final pendingMeals = [
        for (final record in localRecords)
          if (!record.isSynced) record.toMeal(),
      ];
      if (pendingMeals.isEmpty) return remote;

      final combinedMeals = [...remote.meals, ...pendingMeals]
        ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
      final combinedTotals = remote.totals +
          NutritionTotals.sum(pendingMeals.map((meal) => meal.totals));
      return DailyConsumption(meals: combinedMeals, totals: combinedTotals);
    } on ApiException catch (error) {
      if (store != null && error.statusCode == null) {
        final localRecords = await store.mealsForDay(
          patientId: patientId,
          day: day,
          type: type,
        );
        if (localRecords.isNotEmpty) {
          final meals = [for (final record in localRecords) record.toMeal()];
          final totals = NutritionTotals.sum(meals.map((meal) => meal.totals));
          return DailyConsumption(meals: meals, totals: totals);
        }
      }
      rethrow;
    }
  }

  /// Registra uma refeicao (Task 2.3, RNF07).
  ///
  /// Com [localStore], grava primeiro localmente com `is_synced = false` e
  /// tenta enviar para a API. Se houver internet e a API responder 200/201,
  /// marca `is_synced = true`. Se estiver sem conexao (`statusCode == null`),
  /// mantem o registro local com `is_synced = false` para envio posterior em
  /// lote quando a conectividade voltar.
  Future<Meal> registerMeal({
    required int patientId,
    required DateTime consumedAt,
    required MealType type,
    required List<MealItemDraft> items,
    String? note,
  }) async {
    final store = _localStore;
    if (store == null) {
      final record = LocalMealRecord(
        localId: 'temp',
        patientId: patientId,
        consumedAt: consumedAt.toUtc(),
        type: type,
        note: note,
        items: items,
        isSynced: true,
      );
      final response = await _client.post(mealsPath, record.toApiCreateJson());
      return _mealFromResponse(response, record);
    }

    final localRecord = await store.saveMeal(
      patientId: patientId,
      consumedAt: consumedAt,
      type: type,
      items: items,
      note: note,
      isSynced: false,
    );

    try {
      final response = await _client.post(
        mealsPath,
        localRecord.toApiCreateJson(),
      );
      final remoteId = _extractRemoteId(response);
      await store.markAsSynced(localRecord.localId, remoteId: remoteId);
      return _mealFromResponse(
        response,
        localRecord.markSynced(remoteId: remoteId),
      );
    } on ApiException catch (error) {
      if (error.statusCode == null) {
        return localRecord.toMeal();
      }
      rethrow;
    }
  }

  /// Consulta todas as refeicoes locais com `is_synced == false` e dispara o
  /// envio em lote para o FastAPI, alterando `is_synced` para `true` apos
  /// confirmacao de sucesso (Task 2.3, RNF07).
  Future<int> syncPendingMeals({int? patientId}) async {
    final store = _localStore;
    if (store == null) return 0;

    final pending = await store.pendingMeals(patientId: patientId);
    if (pending.isEmpty) return 0;

    final byPatient = <int, List<LocalMealRecord>>{};
    for (final record in pending) {
      byPatient.putIfAbsent(record.patientId, () => []).add(record);
    }

    var syncedCount = 0;
    for (final entry in byPatient.entries) {
      syncedCount += await _syncBatchForPatient(
        store: store,
        patientId: entry.key,
        records: entry.value,
      );
    }
    return syncedCount;
  }

  Future<int> _syncBatchForPatient({
    required LocalMealStore store,
    required int patientId,
    required List<LocalMealRecord> records,
  }) async {
    final payload = {
      'paciente_id': patientId,
      'refeicoes': [for (final record in records) record.toApiCreateJson()],
    };

    try {
      final response = await _postBatchWithFallback(payload);
      final remoteIds = _extractBatchRemoteIds(response, records.length);
      await store.markBatchAsSynced(
        [for (final record in records) record.localId],
        remoteIds: remoteIds,
      );
      return records.length;
    } on _BatchEndpointUnavailable {
      var synced = 0;
      for (final record in records) {
        final response = await _client.post(
          mealsPath,
          record.toApiCreateJson(),
        );
        final remoteId = _extractRemoteId(response);
        await store.markAsSynced(record.localId, remoteId: remoteId);
        synced++;
      }
      return synced;
    }
  }

  Future<Object?> _postBatchWithFallback(Map<String, Object?> payload) async {
    try {
      return await _client.post(batchPath, payload);
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) rethrow;
    }

    try {
      return await _client.post(lotePath, payload);
    } on ApiException catch (error) {
      if (error.statusCode != 404 && error.statusCode != 405) rethrow;
      throw const _BatchEndpointUnavailable();
    }
  }

  static int? _extractRemoteId(Object? response) {
    if (response is Map) {
      final id = response['id'];
      if (id is num) return id.toInt();
    }
    return null;
  }

  static List<int?>? _extractBatchRemoteIds(Object? response, int expected) {
    List<dynamic>? list;
    if (response is List) {
      list = response;
    } else if (response is Map) {
      if (response['refeicoes'] is List) {
        list = response['refeicoes'] as List<dynamic>;
      } else if (response['ids'] is List) {
        list = response['ids'] as List<dynamic>;
      }
    }
    if (list == null || list.length != expected) return null;

    return [
      for (final item in list)
        if (item is num)
          item.toInt()
        else if (item is Map && item['id'] is num)
          (item['id'] as num).toInt()
        else
          null,
    ];
  }

  static Meal _mealFromResponse(Object? response, LocalMealRecord fallback) {
    if (response is Map<String, dynamic> &&
        response['id'] is num &&
        response['consumida_em'] is String &&
        response['tipo'] is String &&
        response['itens'] is List &&
        response['totais'] is Map) {
      return Meal.fromJson(response).copyWith(
        isSynced: true,
        localId: fallback.localId,
      );
    }
    return fallback.toMeal();
  }
}

class _BatchEndpointUnavailable implements Exception {
  const _BatchEndpointUnavailable();
}

/// `YYYY-MM-DD`, o formato de data da API.
String formatApiDate(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}
