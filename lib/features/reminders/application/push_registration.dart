import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../auth/application/auth_controller.dart';
import '../../meals/domain/meal_type.dart';
import '../data/reminder_repository.dart';
import '../domain/meal_reminder.dart';
import 'push_service.dart';

/// Liga a sessao do paciente ao push dos lembretes de refeicao (RF26).
///
/// - Ao entrar (login, cadastro ou sessao restaurada no boot), registra o token
///   FCM do aparelho na API, e de novo sempre que o FCM trocar o token.
/// - Ao sair (logout ou 401), invalida o token. A API nao tem rota para
///   remover o aparelho: sem isso ele seguiria recebendo os lembretes da conta
///   anterior. Com o token invalido, o job do back-end apaga o registro.
/// - Converte os pushes de lembrete em [MealType] para o app reagir: tocados
///   ([openedReminders]) e recebidos com o app aberto ([foregroundReminders]).
///
/// A permissao de notificacao nao e pedida aqui, e sim na tela de lembretes,
/// quando o paciente liga um lembrete.
class PushRegistration {
  PushRegistration({
    required AuthController auth,
    required ReminderRepository repository,
    required PushService push,
  })  : _auth = auth,
        _repository = repository,
        _push = push;

  final AuthController _auth;
  final ReminderRepository _repository;
  final PushService _push;

  final _opened = StreamController<MealType>.broadcast();
  final _foreground = StreamController<MealType>.broadcast();
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// Paciente com o token registrado neste aparelho.
  int? _registeredFor;

  /// Lembrete tocado antes de a sessao ser restaurada (app aberto pelo push).
  MealType? _pendingOpened;

  /// Registro e remocao do token rodam em fila, na ordem dos eventos.
  Future<void> _queue = Future.value();

  bool _started = false;

  /// Lembretes tocados pelo paciente (app em segundo plano ou fechado).
  Stream<MealType> get openedReminders => _opened.stream;

  /// Lembretes recebidos com o app aberto (o sistema nao os exibe).
  Stream<MealType> get foregroundReminders => _foreground.stream;

  /// Conclui quando as operacoes de token em andamento terminam.
  @visibleForTesting
  Future<void> get idle => _queue;

  Future<void> start() async {
    if (_started || !_push.isAvailable) return;
    _started = true;

    _auth.addListener(_onAuthChanged);
    _subscriptions
      ..add(_push.onTokenRefresh.listen(_onTokenRefresh))
      ..add(_push.onMessageOpened.listen(_onOpened))
      ..add(_push.onForegroundMessage.listen(_onForeground));
    _onAuthChanged();

    try {
      final initial = await _push.initialMessage();
      if (initial != null && _started) _onOpened(initial);
    } catch (error) {
      debugPrint('Push: falha ao ler a notificacao que abriu o app ($error).');
    }
  }

  void _onAuthChanged() {
    switch (_auth.status) {
      case AuthStatus.authenticated:
        final userId = _auth.userId;
        if (userId != null && userId != _registeredFor) {
          _registeredFor = userId;
          _enqueue(() => _register(userId));
        }
        final pending = _pendingOpened;
        _pendingOpened = null;
        if (pending != null) _opened.add(pending);
      case AuthStatus.unauthenticated:
        _pendingOpened = null;
        if (_registeredFor != null) {
          _registeredFor = null;
          _enqueue(_push.deleteToken);
        }
      case AuthStatus.unknown:
        break;
    }
  }

  Future<void> _register(int userId) async {
    final token = await _push.getToken();
    // A sessao pode ter mudado enquanto o token era gerado.
    if (token == null || _registeredFor != userId) return;
    await _repository.registerDevice(userId, token);
  }

  void _onTokenRefresh(String token) {
    final userId = _registeredFor;
    if (userId == null) return;
    _enqueue(() async {
      if (_registeredFor != userId) return;
      await _repository.registerDevice(userId, token);
    });
  }

  /// Falha no push nunca derruba a sessao: so fica no log. O registro e
  /// refeito no proximo login ou abertura do app.
  void _enqueue(Future<void> Function() operation) {
    _queue = _queue.then((_) async {
      try {
        await operation();
      } catch (error) {
        debugPrint('Push: falha ao atualizar o token do aparelho ($error).');
      }
    });
  }

  void _onOpened(Map<String, dynamic> data) {
    final type = MealReminderMessage.fromData(data);
    if (type == null) return;
    switch (_auth.status) {
      case AuthStatus.authenticated:
        _opened.add(type);
      case AuthStatus.unknown:
        _pendingOpened = type;
      case AuthStatus.unauthenticated:
        // Sem sessao nao ha historico para abrir.
        break;
    }
  }

  void _onForeground(Map<String, dynamic> data) {
    final type = MealReminderMessage.fromData(data);
    if (type != null && _auth.status == AuthStatus.authenticated) {
      _foreground.add(type);
    }
  }

  Future<void> dispose() async {
    if (_started) _auth.removeListener(_onAuthChanged);
    _started = false;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _opened.close();
    await _foreground.close();
  }
}
