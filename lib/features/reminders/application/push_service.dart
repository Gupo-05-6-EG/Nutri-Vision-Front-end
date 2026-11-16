/// Situacao da permissao de notificacao no aparelho.
enum PushPermission {
  granted,

  /// Negada, mas o sistema ainda pode mostrar o pedido de novo.
  denied,

  /// Negada de vez: so pelas configuracoes do aparelho (Android 13+).
  permanentlyDenied,

  notDetermined,

  /// Push desligado: Firebase nao configurado no `.env` ou falhou ao iniciar.
  unavailable,
}

/// Fronteira entre o app e o Firebase Cloud Messaging (RF26).
///
/// So `FirebasePushService` conhece o Firebase; o resto do app (e os testes)
/// fala com esta interface.
abstract class PushService {
  /// `false` quando o push esta desligado (ver [DisabledPushService]).
  bool get isAvailable;

  Future<PushPermission> permissionStatus();

  /// Mostra o pedido de permissao do sistema (Android 13+ / iOS), se ainda
  /// nao foi respondido, e devolve a situacao final.
  Future<PushPermission> requestPermission();

  /// Token FCM deste aparelho, ou `null` se nao der para obter.
  Future<String?> getToken();

  /// Novo token sempre que o FCM trocar o atual.
  Stream<String> get onTokenRefresh;

  /// `data` dos pushes recebidos com o app aberto (o sistema nao os exibe).
  Stream<Map<String, dynamic>> get onForegroundMessage;

  /// `data` do push tocado com o app em segundo plano.
  Stream<Map<String, dynamic>> get onMessageOpened;

  /// `data` do push que abriu o app quando ele estava fechado, se houver.
  Future<Map<String, dynamic>?> initialMessage();

  /// Invalida o token deste aparelho: pushes enviados a ele deixam de chegar.
  Future<void> deleteToken();
}

/// Push desligado: nao recebe nada e nao pede permissao.
class DisabledPushService implements PushService {
  const DisabledPushService();

  @override
  bool get isAvailable => false;

  @override
  Future<PushPermission> permissionStatus() async => PushPermission.unavailable;

  @override
  Future<PushPermission> requestPermission() async =>
      PushPermission.unavailable;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMessageOpened => const Stream.empty();

  @override
  Future<Map<String, dynamic>?> initialMessage() async => null;

  @override
  Future<void> deleteToken() async {}
}
