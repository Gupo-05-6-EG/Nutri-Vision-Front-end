import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Fronteira entre o app e a deteccao de conectividade de rede (Task 2.3, RNF07).
///
/// So [ConnectivityPlusService] conhece o plugin `connectivity_plus`; o
/// servico de sincronizacao e os testes falam com esta interface.
abstract class ConnectivityService {
  /// `true` quando o aparelho possui alguma interface de rede ativa (Wi-Fi,
  /// dados moveis, ethernet ou VPN).
  Future<bool> isConnected();

  /// Emite `true` quando a conexao e restabelecida e `false` quando cai.
  Stream<bool> get onConnectivityChanged;
}

/// Implementacao real usando `connectivity_plus`.
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool hasNetwork(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      results.any((result) => result != ConnectivityResult.none);

  @override
  Future<bool> isConnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return hasNetwork(results);
    } catch (error) {
      debugPrint(
        'Conectividade: falha ao consultar estado da rede ($error).',
      );
      return true;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(hasNetwork).distinct();
}

/// Implementacao passiva para ambientes sem canal nativo nos testes de widget.
class DisabledConnectivityService implements ConnectivityService {
  const DisabledConnectivityService({this.online = true});

  final bool online;

  @override
  Future<bool> isConnected() async => online;

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}
