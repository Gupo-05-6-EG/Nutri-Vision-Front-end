import 'dart:async';

import 'package:nutri_vision/features/reminders/application/push_service.dart';

/// [PushService] em memoria para os testes: sem Firebase, com eventos
/// disparados pelo proprio teste.
class FakePushService implements PushService {
  FakePushService({
    this.permission = PushPermission.granted,
    this.permissionAfterRequest = PushPermission.granted,
    this.token = 'token-fcm-1',
    this.initial,
  });

  PushPermission permission;

  /// O que o "usuario" responde ao pedido de permissao.
  PushPermission permissionAfterRequest;

  String? token;
  Map<String, dynamic>? initial;

  int requestPermissionCalls = 0;
  int getTokenCalls = 0;
  int deleteTokenCalls = 0;

  final tokenRefresh = StreamController<String>.broadcast();
  final foreground = StreamController<Map<String, dynamic>>.broadcast();
  final opened = StreamController<Map<String, dynamic>>.broadcast();

  @override
  bool get isAvailable => true;

  @override
  Future<PushPermission> permissionStatus() async => permission;

  @override
  Future<PushPermission> requestPermission() async {
    requestPermissionCalls++;
    return permission = permissionAfterRequest;
  }

  @override
  Future<String?> getToken() async {
    getTokenCalls++;
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage => foreground.stream;

  @override
  Stream<Map<String, dynamic>> get onMessageOpened => opened.stream;

  @override
  Future<Map<String, dynamic>?> initialMessage() async => initial;

  @override
  Future<void> deleteToken() async => deleteTokenCalls++;
}

/// `data` de um push de lembrete, como o job do back-end envia.
Map<String, dynamic> reminderPush(String mealType) => {
      'tipo_notificacao': 'lembrete_refeicao',
      'tipo_refeicao': mealType,
    };
