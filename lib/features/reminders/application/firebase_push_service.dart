// O app usa o token de registro do FCM (`getToken`/`onTokenRefresh`/
// `deleteToken`), marcado como obsoleto no firebase_messaging 17 em favor do
// registro por Firebase Installation ID (`register`/`onRegistered`). O job do
// back-end (firebase-admin 6.6, `messaging.Message(token=...)`) envia para o
// token de registro, entao a troca precisa ser feita nos dois lados juntos.
// ignore_for_file: deprecated_member_use
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/env.dart';
import 'push_service.dart';

/// [PushService] com o Firebase Cloud Messaging (RF26).
///
/// Unico ponto do app que importa o Firebase. Ele e iniciado pelo Dart, com as
/// chaves do `.env`, e nao pelo `google-services.json`: as pastas `android/` e
/// `ios/` nao sao versionadas (o CI as recria com `flutter create`).
class FirebasePushService implements PushService {
  FirebasePushService._(this._messaging);

  final FirebaseMessaging _messaging;

  /// Inicia o Firebase. Sem [config], ou se a inicializacao falhar (ex.:
  /// emulador sem Google Play), devolve um [DisabledPushService]: o app nunca
  /// deixa de abrir por causa do push.
  static Future<PushService> create(FirebaseConfig? config) async {
    if (config == null) return const DisabledPushService();
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: config.apiKey,
          appId: config.appId,
          messagingSenderId: config.messagingSenderId,
          projectId: config.projectId,
        ),
      );
      return FirebasePushService._(FirebaseMessaging.instance);
    } catch (error) {
      debugPrint('Push desligado: falha ao iniciar o Firebase ($error).');
      return const DisabledPushService();
    }
  }

  @override
  bool get isAvailable => true;

  static PushPermission _map(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied => PushPermission.denied,
        AuthorizationStatus.deniedPermanently =>
          PushPermission.permanentlyDenied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<PushPermission> permissionStatus() async =>
      _map(await _messaging.getNotificationSettings());

  @override
  Future<PushPermission> requestPermission() async =>
      _map(await _messaging.requestPermission());

  @override
  Future<String?> getToken() async {
    final token = await _messaging.getToken();
    // Facilita testar pelo Firebase Console ("Enviar mensagem de teste").
    if (token != null && Env.environment != 'production') {
      debugPrint('Token FCM: $token');
    }
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      FirebaseMessaging.onMessage.map((message) => message.data);

  @override
  Stream<Map<String, dynamic>> get onMessageOpened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);

  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      (await _messaging.getInitialMessage())?.data;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();
}
