import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/core/network/connectivity_service.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/auth/data/auth_repository.dart';
import 'package:nutri_vision/features/auth/data/token_storage.dart';
import 'package:nutri_vision/features/foods/domain/food.dart';
import 'package:nutri_vision/features/meals/application/meal_sync_service.dart';
import 'package:nutri_vision/features/meals/data/local_meal_store.dart';
import 'package:nutri_vision/features/meals/data/meal_repository.dart';
import 'package:nutri_vision/features/meals/domain/local_meal_record.dart';
import 'package:nutri_vision/features/meals/domain/meal.dart';
import 'package:nutri_vision/features/meals/domain/meal_type.dart';
import 'package:nutri_vision/features/meals/presentation/meal_history_page.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/recognition/domain/nutrition_estimate.dart';

class _FakeConnectivityService implements ConnectivityService {
  _FakeConnectivityService({this.connected = false});

  bool connected;
  final controller = StreamController<bool>.broadcast(sync: true);

  @override
  Future<bool> isConnected() async => connected;

  @override
  Stream<bool> get onConnectivityChanged => controller.stream;

  void setOnline(bool value) {
    connected = value;
    controller.add(value);
  }

  Future<void> dispose() async {
    unawaited(controller.close());
  }
}

class _MemoryTokenStorage implements TokenStorage {
  _MemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> save(String value) async => token = value;

  @override
  Future<void> clear() async => token = null;
}

String _jwt({int sub = 7}) {
  String enc(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final exp = DateTime.now().add(const Duration(days: 1));
  final payload = {'sub': '$sub', 'exp': exp.millisecondsSinceEpoch ~/ 1000};
  return '${enc({'alg': 'HS256'})}.${enc(payload)}.assinatura';
}

const _arrozFood = Food(
  id: 1,
  name: 'Arroz, tipo 1, cozido',
  category: 'Cereais e derivados',
  kcalPer100g: 128,
  carbsPer100g: 28.1,
  proteinPer100g: 2.5,
  fatPer100g: 0.2,
);

final _arrozDraft = MealItemDraft.fromPortion(
  const FoodPortion(food: _arrozFood, grams: 150),
);

const _bananaDraft = MealItemDraft(
  name: 'Banana, prata, crua',
  grams: 100,
  totals: NutritionTotals(kcal: 98, protein: 1.3, carbs: 26, fat: 0.1),
);

http.Response _json(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('HiveMealStore e LocalMealRecord', () {
    late Directory tempDir;
    late HiveMealStore store;
    late Box<Map<dynamic, dynamic>> rawBox;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('nutri_vision_hive_test');
      Hive.init(tempDir.path);
      rawBox = await Hive.openBox<Map<dynamic, dynamic>>('meals_test_box');
      store = HiveMealStore.fromBox(rawBox);
    });

    tearDown(() async {
      await store.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('salva refeicao local no Hive com flag is_synced = false', () async {
      final consumedAt = DateTime.utc(2026, 10, 20, 12, 30);
      final record = await store.saveMeal(
        patientId: 7,
        consumedAt: consumedAt,
        type: MealType.lunch,
        items: [_arrozDraft],
        note: 'Sem sal',
      );

      expect(record.isSynced, isFalse);
      final raw = rawBox.get(record.localId)!;
      expect(raw['is_synced'], isFalse);
      expect(raw['paciente_id'], 7);
      expect(raw['tipo'], 'almoco');
      expect(raw['observacao'], 'Sem sal');

      final pending = await store.pendingMeals(patientId: 7);
      expect(pending, hasLength(1));
      expect(pending.single.localId, record.localId);
      expect(pending.single.totals.kcal, 192);
    });

    test('markBatchAsSynced altera is_synced para true e grava remote_id',
        () async {
      final first = await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 9),
        type: MealType.breakfast,
        items: [_bananaDraft],
      );
      final second = await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      await store.markBatchAsSynced(
        [first.localId, second.localId],
        remoteIds: [101, 102],
      );

      expect(await store.pendingMeals(patientId: 7), isEmpty);
      expect(rawBox.get(first.localId)!['is_synced'], isTrue);
      expect(rawBox.get(first.localId)!['remote_id'], 101);
      expect(rawBox.get(second.localId)!['is_synced'], isTrue);
      expect(rawBox.get(second.localId)!['remote_id'], 102);

      final dayMeals = await store.mealsForDay(
        patientId: 7,
        day: DateTime.utc(2026, 10, 20),
      );
      expect(dayMeals, hasLength(2));
      expect(dayMeals.every((m) => m.isSynced), isTrue);
    });

    test('cacheRemoteMeals guarda refeicoes da API sem apagar pendentes',
        () async {
      final pending = await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 16),
        type: MealType.snack,
        items: [_bananaDraft],
      );

      await store.cacheRemoteMeals(7, [
        Meal(
          id: 50,
          consumedAt: DateTime.utc(2026, 10, 20, 8),
          type: 'cafe_da_manha',
          items: const [
            MealItem(
              id: 500,
              name: 'Pão francês',
              grams: 50,
              totals:
                  NutritionTotals(kcal: 150, protein: 4, carbs: 29, fat: 1.5),
            ),
          ],
          totals:
              const NutritionTotals(kcal: 150, protein: 4, carbs: 29, fat: 1.5),
        ),
      ]);

      final dayRecords = await store.mealsForDay(
        patientId: 7,
        day: DateTime.utc(2026, 10, 20),
      );
      expect(dayRecords, hasLength(2));
      expect(dayRecords.first.isSynced, isTrue);
      expect(dayRecords.last.localId, pending.localId);
      expect(dayRecords.last.isSynced, isFalse);
    });
  });

  group('MealRepository - modo offline e sincronizacao em lote', () {
    test('salva localmente com is_synced=false quando sem internet', () async {
      final store = InMemoryMealStore();
      final repository = MealRepository(
        ApiClient(
          baseUrl: 'http://api.test/api/v1',
          httpClient: MockClient((_) async {
            throw http.ClientException('Sem internet');
          }),
        ),
        localStore: store,
      );

      final meal = await repository.registerMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      expect(meal.isSynced, isFalse);
      expect(meal.totals.kcal, 192);
      final pending = await store.pendingMeals(patientId: 7);
      expect(pending, hasLength(1));
      expect(pending.single.isSynced, isFalse);
    });

    test('marca is_synced=true imediatamente quando ha internet no registro',
        () async {
      final store = InMemoryMealStore();
      final repository = MealRepository(
        ApiClient(
          baseUrl: 'http://api.test/api/v1',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/api/v1/refeicoes');
            return _json({'id': 42}, status: 201);
          }),
        ),
        localStore: store,
      );

      final meal = await repository.registerMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      expect(meal.isSynced, isTrue);
      expect(meal.id, 42);
      expect(await store.pendingMeals(patientId: 7), isEmpty);
    });

    test(
        'syncPendingMeals dispara lote para POST /refeicoes/batch e marca is_synced=true apos 200 OK',
        () async {
      final store = InMemoryMealStore();
      await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 8, 30),
        type: MealType.breakfast,
        items: [_bananaDraft],
      );
      await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      Map<String, dynamic>? batchBody;
      String? calledPath;
      final repository = MealRepository(
        ApiClient(
          baseUrl: 'http://api.test/api/v1',
          httpClient: MockClient((request) async {
            calledPath = request.url.path;
            batchBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(
              {
                'ids': [201, 202],
              },
              status: 200,
            );
          }),
        ),
        localStore: store,
      );

      final count = await repository.syncPendingMeals(patientId: 7);

      expect(count, 2);
      expect(calledPath, '/api/v1/refeicoes/batch');
      expect(batchBody!['paciente_id'], 7);
      final sentMeals = batchBody!['refeicoes'] as List<dynamic>;
      expect(sentMeals, hasLength(2));
      expect(
        (sentMeals.first as Map)['consumida_em'],
        '2026-10-20T08:30:00.000Z',
      );
      expect(await store.pendingMeals(patientId: 7), isEmpty);

      final dayMeals = await store.mealsForDay(
        patientId: 7,
        day: DateTime.utc(2026, 10, 20),
      );
      expect(dayMeals.map((m) => m.remoteId), [201, 202]);
      expect(dayMeals.every((m) => m.isSynced), isTrue);
    });

    test(
        'syncPendingMeals faz fallback para /refeicoes/lote e /refeicoes quando necessario',
        () async {
      final store = InMemoryMealStore();
      await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      final calledPaths = <String>[];
      final repository = MealRepository(
        ApiClient(
          baseUrl: 'http://api.test/api/v1',
          httpClient: MockClient((request) async {
            calledPaths.add(request.url.path);
            if (request.url.path.endsWith('/batch') ||
                request.url.path.endsWith('/lote')) {
              return _json({'detail': 'Not Found'}, status: 404);
            }
            return _json({'id': 305}, status: 201);
          }),
        ),
        localStore: store,
      );

      final synced = await repository.syncPendingMeals(patientId: 7);

      expect(synced, 1);
      expect(calledPaths, [
        '/api/v1/refeicoes/batch',
        '/api/v1/refeicoes/lote',
        '/api/v1/refeicoes',
      ]);
      expect(await store.pendingMeals(patientId: 7), isEmpty);
    });

    test('dailyConsumption usa registros locais quando offline', () async {
      final store = InMemoryMealStore();
      await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        items: [_arrozDraft],
        isSynced: false,
      );

      final repository = MealRepository(
        ApiClient(
          baseUrl: 'http://api.test/api/v1',
          httpClient: MockClient((_) async {
            throw http.ClientException('Sem rede');
          }),
        ),
        localStore: store,
      );

      final consumption = await repository.dailyConsumption(
        patientId: 7,
        day: DateTime.utc(2026, 10, 20),
      );

      expect(consumption.meals, hasLength(1));
      expect(consumption.meals.single.isSynced, isFalse);
      expect(consumption.totals.kcal, 192);
    });
  });

  group('MealSyncService e listener de conectividade', () {
    test(
        'dispara lote automaticamente assim que a conectividade e restabelecida',
        () async {
      final store = InMemoryMealStore();
      await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 9),
        type: MealType.breakfast,
        items: [_bananaDraft],
      );
      await store.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 13),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      final connectivity = _FakeConnectivityService(connected: false);
      var batchCalls = 0;
      final repository = MealRepository(
        ApiClient(
          baseUrl: 'http://api.test/api/v1',
          httpClient: MockClient((request) async {
            if (request.url.path == '/api/v1/refeicoes/batch') {
              batchCalls++;
              return _json(
                {
                  'ids': [11, 12],
                },
                status: 200,
              );
            }
            return _json({}, status: 404);
          }),
        ),
        localStore: store,
      );

      final syncedEvents = <int>[];
      final syncService = MealSyncService(
        repository: repository,
        connectivity: connectivity,
        patientId: 7,
      );
      final sub = syncService.onSynced.listen(syncedEvents.add);

      await syncService.start();
      await syncService.idle;

      // Offline no inicio: nada enviado, 2 pendentes.
      expect(batchCalls, 0);
      expect(syncService.pendingCount, 2);

      // Conectividade restabelecida: dispara o lote!
      connectivity.setOnline(true);
      await pumpEventQueue();
      await syncService.idle;
      await pumpEventQueue();

      expect(batchCalls, 1);
      expect(syncService.pendingCount, 0);
      expect(syncedEvents, [2]);
      expect(await store.pendingMeals(patientId: 7), isEmpty);

      await sub.cancel();
      await syncService.dispose();
      await connectivity.dispose();
    });

    test('sincroniza ao restaurar sessao autenticada quando online', () async {
      final store = InMemoryMealStore();
      await store.saveMeal(
        patientId: 9,
        consumedAt: DateTime.utc(2026, 10, 20, 12),
        type: MealType.lunch,
        items: [_arrozDraft],
      );

      final connectivity = _FakeConnectivityService(connected: true);
      var batchCalls = 0;
      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/refeicoes/batch') {
            batchCalls++;
            return _json(
              {
                'ids': [99],
              },
              status: 200,
            );
          }
          return _json({}, status: 200);
        }),
      );
      final auth = AuthController(
        client: client,
        repository: AuthRepository(client),
        storage: _MemoryTokenStorage(_jwt(sub: 9)),
      );
      final repository = MealRepository(client, localStore: store);
      final syncService = MealSyncService(
        repository: repository,
        connectivity: connectivity,
        auth: auth,
      );

      await syncService.start();
      await auth.restoreSession();
      await pumpEventQueue();
      await syncService.idle;

      expect(batchCalls, 1);
      expect(syncService.pendingCount, 0);

      await syncService.dispose();
      auth.dispose();
      await connectivity.dispose();
    });

    test('ConnectivityPlusService.hasNetwork interpreta lista de resultados',
        () {
      expect(ConnectivityPlusService.hasNetwork(const []), isFalse);
      expect(
        ConnectivityPlusService.hasNetwork(const [ConnectivityResult.none]),
        isFalse,
      );
      expect(
        ConnectivityPlusService.hasNetwork(
          const [ConnectivityResult.none, ConnectivityResult.wifi],
        ),
        isTrue,
      );
    });
  });

  group('Integracao RecognitionRepository + MealHistoryPage offline -> online',
      () {
    testWidgets(
        'salva refeicao offline, exibe indicador pendente e atualiza ao sincronizar',
        (tester) async {
      final store = InMemoryMealStore();
      final connectivity = _FakeConnectivityService(connected: false);
      var isOffline = true;
      final remoteMeals = <Map<String, dynamic>>[];

      final client = ApiClient(
        baseUrl: 'http://api.test/api/v1',
        httpClient: MockClient((request) async {
          if (isOffline) throw http.ClientException('offline');

          if (request.url.path == '/api/v1/refeicoes/batch') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            final list =
                (body['refeicoes'] as List).cast<Map<String, dynamic>>();
            for (final item in list) {
              remoteMeals.add({
                'id': remoteMeals.length + 1,
                'paciente_id': item['paciente_id'],
                'consumida_em': item['consumida_em'],
                'tipo': item['tipo'],
                'observacao': item['observacao'],
                'criada_em': item['consumida_em'],
                'atualizada_em': item['consumida_em'],
                'itens': [
                  for (final (idx, i)
                      in (item['itens'] as List).cast<Map>().indexed)
                    {'id': idx + 1, ...i},
                ],
                'totais': {
                  'calorias_kcal': 192.0,
                  'proteinas_g': 3.75,
                  'carboidratos_g': 42.15,
                  'gorduras_g': 0.3,
                },
              });
            }
            return _json(
              {
                'ids': [1],
              },
              status: 200,
            );
          }

          if (request.url.path == '/api/v1/refeicoes/consumo-diario') {
            return _json({
              'paciente_id': 7,
              'data': '2026-10-20',
              'quantidade_refeicoes': remoteMeals.length,
              'totais': {
                'calorias_kcal': remoteMeals.isEmpty ? 0 : 192.0,
                'proteinas_g': remoteMeals.isEmpty ? 0 : 3.75,
                'carboidratos_g': remoteMeals.isEmpty ? 0 : 42.15,
                'gorduras_g': remoteMeals.isEmpty ? 0 : 0.3,
              },
              'refeicoes': remoteMeals,
            });
          }

          return _json({}, status: 404);
        }),
      );

      final recognitionRepo = RecognitionRepository(client, localStore: store);
      final mealRepo = MealRepository(client, localStore: store);
      final syncService = MealSyncService(
        repository: mealRepo,
        connectivity: connectivity,
        patientId: 7,
      );
      await syncService.start();

      // Paciente confirma refeicao na tela de revisao sem internet:
      await recognitionRepo.saveMeal(
        patientId: 7,
        consumedAt: DateTime.utc(2026, 10, 20, 12, 30),
        type: MealType.lunch,
        estimate: const NutritionEstimate(
          items: [
            EstimatedItem(
              tacoName: 'Arroz, tipo 1, cozido',
              grams: 150,
              kcal: 192,
              protein: 3.75,
              carbs: 42.15,
              fat: 0.3,
            ),
          ],
          totalKcal: 192,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MealHistoryPage(
            repository: mealRepo,
            patientId: 7,
            dailyGoalKcal: 2000,
            today: DateTime(2026, 10, 20, 15),
            syncService: syncService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mostra a refeicao local com o indicador "Pendente de sincronizacao":
      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
      expect(find.text('Pendente de sincronização'), findsOneWidget);
      expect(find.byKey(const Key('offline-sync-banner')), findsOneWidget);

      // Conectividade volta: listener dispara o lote e a tela atualiza!
      isOffline = false;
      connectivity.setOnline(true);
      await tester.pump();
      await syncService.idle;
      await tester.pumpAndSettle();

      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
      expect(find.text('Pendente de sincronização'), findsNothing);
      expect(find.byKey(const Key('offline-sync-banner')), findsNothing);

      await syncService.dispose();
      await connectivity.dispose();
    });
  });
}
