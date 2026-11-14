import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/connectivity_service.dart';
import '../../auth/application/auth_controller.dart';
import '../data/meal_repository.dart';

/// Listener de conectividade que dispara o lote de refeicoes pendentes
/// (`is_synced == false`) para a API quando ha internet (Task 2.3, RNF07).
class MealSyncService extends ChangeNotifier {
  MealSyncService({
    required MealRepository repository,
    required ConnectivityService connectivity,
    AuthController? auth,
    int? patientId,
  })  : _repository = repository,
        _connectivity = connectivity,
        _auth = auth,
        _fixedPatientId = patientId;

  final MealRepository _repository;
  final ConnectivityService _connectivity;
  final AuthController? _auth;
  final int? _fixedPatientId;

  final _syncedController = StreamController<int>.broadcast();
  StreamSubscription<bool>? _connectivitySubscription;

  Future<void> _queue = Future.value();
  bool _started = false;
  bool _disposed = false;
  bool _isSyncing = false;
  int _pendingCount = 0;

  /// `true` enquanto um lote de refeicoes pendentes esta sendo enviado.
  bool get isSyncing => _isSyncing;

  /// Quantidade de refeicoes locais com `is_synced == false`.
  int get pendingCount => _pendingCount;

  /// Emite a quantidade de refeicoes sincronizadas a cada lote concluido.
  Stream<int> get onSynced => _syncedController.stream;

  /// Conclui quando as operacoes de sincronizacao em fila terminam.
  @visibleForTesting
  Future<void> get idle => _queue;

  int? get _effectivePatientId => _fixedPatientId ?? _auth?.userId;

  Future<void> start() async {
    if (_started || _disposed) return;
    _started = true;

    _auth?.addListener(_onAuthChanged);
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    await refreshPendingCount();
    if (await _connectivity.isConnected()) {
      _enqueueSync();
    }
  }

  void _onAuthChanged() {
    if (_disposed) return;
    final auth = _auth;
    if (auth == null) return;
    if (auth.status == AuthStatus.authenticated) {
      _enqueue(() async {
        await _updatePendingCount();
        if (await _connectivity.isConnected()) {
          await _performSync();
        }
      });
    } else if (auth.status == AuthStatus.unauthenticated) {
      _pendingCount = 0;
      _notifySafely();
    }
  }

  void _onConnectivityChanged(bool isConnected) {
    if (_disposed || !isConnected) return;
    _enqueueSync();
  }

  /// Atualiza [pendingCount] consultando o armazenamento local.
  Future<int> refreshPendingCount({int? patientId}) async {
    return _updatePendingCount(patientId: patientId);
  }

  /// Dispara imediatamente a sincronizacao das refeicoes pendentes em fila.
  Future<int> syncNow({int? patientId}) {
    final completer = Completer<int>();
    _queue = _queue.then((_) async {
      try {
        final count = await _performSync(patientId: patientId);
        if (!completer.isCompleted) completer.complete(count);
      } catch (error) {
        debugPrint('Sync: falha ao sincronizar refeicoes pendentes ($error).');
        if (!completer.isCompleted) completer.complete(0);
      }
    });
    return completer.future;
  }

  void _enqueueSync() {
    _enqueue(() => _performSync());
  }

  void _enqueue(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (error) {
        debugPrint('Sync: falha na fila de sincronizacao ($error).');
      }
    });
  }

  Future<int> _performSync({int? patientId}) async {
    if (_disposed) return 0;
    final auth = _auth;
    if (auth != null &&
        patientId == null &&
        _fixedPatientId == null &&
        auth.status != AuthStatus.authenticated) {
      return 0;
    }

    final targetPatientId = patientId ?? _effectivePatientId;
    final pendingBefore = await _updatePendingCount(patientId: targetPatientId);
    if (pendingBefore == 0) return 0;

    _isSyncing = true;
    _notifySafely();

    try {
      final synced = await _repository.syncPendingMeals(
        patientId: targetPatientId,
      );
      await _updatePendingCount(patientId: targetPatientId);
      if (synced > 0 && !_syncedController.isClosed) {
        _syncedController.add(synced);
      }
      return synced;
    } finally {
      _isSyncing = false;
      _notifySafely();
    }
  }

  Future<int> _updatePendingCount({int? patientId}) async {
    final store = _repository.localStore;
    if (store == null) {
      _pendingCount = 0;
      _notifySafely();
      return 0;
    }
    final targetPatientId = patientId ?? _effectivePatientId;
    final pending = await store.pendingMeals(patientId: targetPatientId);
    _pendingCount = pending.length;
    _notifySafely();
    return _pendingCount;
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (_started) {
      _auth?.removeListener(_onAuthChanged);
    }
    _disposed = true;
    _started = false;
    final sub = _connectivitySubscription;
    _connectivitySubscription = null;
    if (sub != null) {
      unawaited(sub.cancel());
    }
    unawaited(_syncedController.close());
    super.dispose();
  }
}
