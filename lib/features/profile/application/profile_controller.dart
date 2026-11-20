import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';
import '../domain/patient_profile.dart';

/// Perfil do paciente logado, compartilhado pelas telas (Inicio, Perfil,
/// historico, plano). E a fonte unica da meta diaria e do XP no topo.
///
/// Recarrega ao entrar na conta, quando alguma tela registra uma refeicao
/// ([refresh]) e quando o envio offline em lote termina ([syncEvents]).
class ProfileController extends ChangeNotifier {
  ProfileController({
    required this.auth,
    required ProfileRepository repository,
    Stream<Object?>? syncEvents,
  }) : _repository = repository {
    auth.addListener(_onAuthChanged);
    _syncSubscription = syncEvents?.listen((_) => unawaited(refresh()));
    _onAuthChanged();
  }

  final AuthController auth;
  final ProfileRepository _repository;
  StreamSubscription<Object?>? _syncSubscription;

  PatientProfile? _profile;
  bool _loading = false;
  String? _error;
  int? _loadedFor;
  Future<void>? _inFlight;

  PatientProfile? get profile => _profile;
  bool get loading => _loading;
  String? get error => _error;

  /// Meta do dia (nula enquanto o perfil nao carregou ou nao ha meta).
  DailyGoal get goal => _profile?.goal ?? const DailyGoal();

  int get xp => _profile?.gamification.xp ?? 0;

  void _onAuthChanged() {
    final userId = auth.userId;
    if (auth.status != AuthStatus.authenticated || userId == null) {
      if (_profile != null || _error != null) {
        _profile = null;
        _error = null;
        _loadedFor = null;
        notifyListeners();
      }
      return;
    }
    if (_loadedFor != userId || _linkSeen != auth.linkChanges) {
      _linkSeen = auth.linkChanges;
      unawaited(refresh());
    }
  }

  /// Ultima mudanca de vinculo ja refletida no perfil.
  int _linkSeen = 0;

  /// Busca o perfil de novo. Chamadas simultaneas compartilham a mesma busca.
  Future<void> refresh() {
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    final userId = auth.userId;
    if (userId == null) return;
    _loading = true;
    notifyListeners();
    try {
      final profile = await _repository.fetch(userId);
      // A sessao pode ter mudado enquanto a resposta chegava.
      if (auth.userId != userId) return;
      _profile = profile;
      _loadedFor = userId;
      _error = null;
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    unawaited(_syncSubscription?.cancel());
    super.dispose();
  }
}
