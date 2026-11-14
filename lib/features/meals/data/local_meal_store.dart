import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/local_meal_record.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';

/// Armazenamento local de refeicoes com controle de `is_synced` (Task 2.3, RNF07).
abstract class LocalMealStore {
  /// Salva uma refeicao localmente (por padrao com `is_synced = false`).
  Future<LocalMealRecord> saveMeal({
    required int patientId,
    required DateTime consumedAt,
    required MealType type,
    required List<MealItemDraft> items,
    String? note,
    bool isSynced = false,
    int? remoteId,
  });

  /// Atualiza o cache local com as refeicoes vindas da API (`is_synced = true`),
  /// preservando todos os registros pendentes (`is_synced = false`).
  Future<void> cacheRemoteMeals(int patientId, Iterable<Meal> meals);

  /// Todas as refeicoes com `is_synced == false`, em ordem cronologica.
  Future<List<LocalMealRecord>> pendingMeals({int? patientId});

  /// Todas as refeicoes locais de [patientId] na data [day] (sincronizadas e
  /// pendentes), opcionalmente filtradas por [type].
  Future<List<LocalMealRecord>> mealsForDay({
    required int patientId,
    required DateTime day,
    MealType? type,
  });

  /// Altera a flag `is_synced` para `true` apos confirmacao da API.
  Future<void> markAsSynced(String localId, {int? remoteId});

  /// Altera a flag `is_synced` para `true` em lote apos `200 OK` / `201 Created`.
  Future<void> markBatchAsSynced(
    List<String> localIds, {
    List<int?>? remoteIds,
  });

  Future<void> close();
}

bool _matchesDay(DateTime consumedAtUtc, DateTime day) {
  final targetYear = day.year;
  final targetMonth = day.month;
  final targetDay = day.day;

  final utc = consumedAtUtc.toUtc();
  if (utc.year == targetYear &&
      utc.month == targetMonth &&
      utc.day == targetDay) {
    return true;
  }

  final local = consumedAtUtc.toLocal();
  return local.year == targetYear &&
      local.month == targetMonth &&
      local.day == targetDay;
}

/// Implementacao persistente usando Hive (`Box<Map>`).
class HiveMealStore implements LocalMealStore {
  HiveMealStore.fromBox(this._box);

  static const String defaultBoxName = 'local_meals';
  static int _sequence = 0;

  final Box<Map<dynamic, dynamic>> _box;

  /// Inicializa o Hive e abre a box de refeicoes locais.
  static Future<HiveMealStore> open({
    String? directoryPath,
    String boxName = defaultBoxName,
  }) async {
    final path = directoryPath ?? await _resolveDirectoryPath();
    Hive.init(path);
    final box = await Hive.openBox<Map<dynamic, dynamic>>(boxName);
    return HiveMealStore.fromBox(box);
  }

  static Future<String> _resolveDirectoryPath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (_) {
      final fallback = Directory('${Directory.systemTemp.path}/nutri_vision');
      if (!fallback.existsSync()) {
        fallback.createSync(recursive: true);
      }
      return fallback.path;
    }
  }

  static String _nextLocalId() {
    _sequence++;
    return 'local_${DateTime.now().microsecondsSinceEpoch}_$_sequence';
  }

  Iterable<LocalMealRecord> _allRecords() sync* {
    for (final raw in _box.values) {
      yield LocalMealRecord.fromHiveMap(raw);
    }
  }

  @override
  Future<LocalMealRecord> saveMeal({
    required int patientId,
    required DateTime consumedAt,
    required MealType type,
    required List<MealItemDraft> items,
    String? note,
    bool isSynced = false,
    int? remoteId,
  }) async {
    final localId =
        remoteId != null && isSynced ? 'remote_$remoteId' : _nextLocalId();
    final record = LocalMealRecord(
      localId: localId,
      remoteId: remoteId,
      patientId: patientId,
      consumedAt: consumedAt.toUtc(),
      type: type,
      note: note,
      items: items,
      isSynced: isSynced,
    );
    await _box.put(localId, record.toHiveMap());
    return record;
  }

  @override
  Future<void> cacheRemoteMeals(int patientId, Iterable<Meal> meals) async {
    final updates = <String, Map<String, Object?>>{};
    for (final meal in meals) {
      final record = LocalMealRecord.fromMeal(
        patientId: patientId,
        meal: meal.copyWith(isSynced: true),
      );
      updates[record.localId] = record.toHiveMap();
    }
    if (updates.isNotEmpty) {
      await _box.putAll(updates);
    }
  }

  @override
  Future<List<LocalMealRecord>> pendingMeals({int? patientId}) async {
    final records = _allRecords().where((record) {
      if (record.isSynced) return false;
      if (patientId != null && record.patientId != patientId) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return records;
  }

  @override
  Future<List<LocalMealRecord>> mealsForDay({
    required int patientId,
    required DateTime day,
    MealType? type,
  }) async {
    final records = _allRecords().where((record) {
      if (record.patientId != patientId) return false;
      if (!_matchesDay(record.consumedAt, day)) return false;
      if (type != null && record.type != type) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return records;
  }

  @override
  Future<void> markAsSynced(String localId, {int? remoteId}) async {
    final raw = _box.get(localId);
    if (raw == null) return;
    final current = LocalMealRecord.fromHiveMap(raw);
    final synced = current.markSynced(remoteId: remoteId);
    await _box.put(localId, synced.toHiveMap());
  }

  @override
  Future<void> markBatchAsSynced(
    List<String> localIds, {
    List<int?>? remoteIds,
  }) async {
    final updates = <String, Map<String, Object?>>{};
    for (var i = 0; i < localIds.length; i++) {
      final localId = localIds[i];
      final raw = _box.get(localId);
      if (raw == null) continue;
      final current = LocalMealRecord.fromHiveMap(raw);
      final remoteId =
          remoteIds != null && i < remoteIds.length ? remoteIds[i] : null;
      final synced = current.markSynced(remoteId: remoteId);
      updates[localId] = synced.toHiveMap();
    }
    if (updates.isNotEmpty) {
      await _box.putAll(updates);
    }
  }

  @override
  Future<void> close() => _box.close();
}

/// Implementacao em memoria de [LocalMealStore] para testes rapidos.
class InMemoryMealStore implements LocalMealStore {
  final Map<String, Map<String, Object?>> _records = {};
  int _seq = 0;

  @override
  Future<LocalMealRecord> saveMeal({
    required int patientId,
    required DateTime consumedAt,
    required MealType type,
    required List<MealItemDraft> items,
    String? note,
    bool isSynced = false,
    int? remoteId,
  }) async {
    _seq++;
    final localId =
        remoteId != null && isSynced ? 'remote_$remoteId' : 'mem_$_seq';
    final record = LocalMealRecord(
      localId: localId,
      remoteId: remoteId,
      patientId: patientId,
      consumedAt: consumedAt.toUtc(),
      type: type,
      note: note,
      items: items,
      isSynced: isSynced,
    );
    _records[localId] = record.toHiveMap();
    return record;
  }

  @override
  Future<void> cacheRemoteMeals(int patientId, Iterable<Meal> meals) async {
    for (final meal in meals) {
      final record = LocalMealRecord.fromMeal(
        patientId: patientId,
        meal: meal.copyWith(isSynced: true),
      );
      _records[record.localId] = record.toHiveMap();
    }
  }

  @override
  Future<List<LocalMealRecord>> pendingMeals({int? patientId}) async {
    final list = _records.values.map(LocalMealRecord.fromHiveMap).where((r) {
      if (r.isSynced) return false;
      if (patientId != null && r.patientId != patientId) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return list;
  }

  @override
  Future<List<LocalMealRecord>> mealsForDay({
    required int patientId,
    required DateTime day,
    MealType? type,
  }) async {
    final list = _records.values.map(LocalMealRecord.fromHiveMap).where((r) {
      if (r.patientId != patientId) return false;
      if (!_matchesDay(r.consumedAt, day)) return false;
      if (type != null && r.type != type) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.consumedAt.compareTo(b.consumedAt));
    return list;
  }

  @override
  Future<void> markAsSynced(String localId, {int? remoteId}) async {
    final raw = _records[localId];
    if (raw == null) return;
    final current = LocalMealRecord.fromHiveMap(raw);
    _records[localId] = current.markSynced(remoteId: remoteId).toHiveMap();
  }

  @override
  Future<void> markBatchAsSynced(
    List<String> localIds, {
    List<int?>? remoteIds,
  }) async {
    for (var i = 0; i < localIds.length; i++) {
      final remoteId =
          remoteIds != null && i < remoteIds.length ? remoteIds[i] : null;
      await markAsSynced(localIds[i], remoteId: remoteId);
    }
  }

  @override
  Future<void> close() async {}
}
