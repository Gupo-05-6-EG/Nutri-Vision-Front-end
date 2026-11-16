import 'dart:async';

import 'package:flutter/material.dart';

import 'core/config/app_theme.dart';
import 'core/config/env.dart';
import 'core/network/api_client.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/home/presentation/home_placeholder_page.dart';
import 'features/meals/data/meal_repository.dart';
import 'features/meals/domain/meal_type.dart';
import 'features/meals/presentation/meal_history_page.dart';
import 'features/plan/data/plan_repository.dart';
import 'features/privacy/data/privacy_repository.dart';
import 'features/reminders/application/push_registration.dart';
import 'features/reminders/application/push_service.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/screening/data/screening_repository.dart';

class NutriVisionApp extends StatefulWidget {
  const NutriVisionApp({this.push = const DisabledPushService(), super.key});

  /// Push dos lembretes de refeicao (RF26); desligado se o Firebase nao
  /// estiver configurado no `.env`.
  final PushService push;

  @override
  State<NutriVisionApp> createState() => _NutriVisionAppState();
}

class _NutriVisionAppState extends State<NutriVisionApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final ApiClient _client = ApiClient(baseUrl: Env.apiUrl);
  late final PrivacyRepository _privacy = PrivacyRepository(_client);
  late final AuthController _auth = AuthController(
    client: _client,
    repository: AuthRepository(_client),
    storage: SecureTokenStorage(),
    privacyRepository: _privacy,
  );
  late final ScreeningRepository _screening = ScreeningRepository(_client);
  late final PlanRepository _plans = PlanRepository(_client);
  late final MealRepository _meals = MealRepository(_client);
  late final ReminderRepository _reminders = ReminderRepository(_client);
  late final PushRegistration _pushRegistration = PushRegistration(
    auth: _auth,
    repository: _reminders,
    push: widget.push,
  );
  final _pushSubscriptions = <StreamSubscription<MealType>>[];

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _pushSubscriptions
      ..add(_pushRegistration.openedReminders.listen(_openMealHistory))
      ..add(
        _pushRegistration.foregroundReminders.listen(_showReminderSnackBar),
      );
    unawaited(_pushRegistration.start());
    unawaited(_auth.restoreSession());
  }

  // Ao perder a sessao (logout ou 401), descarta qualquer tela empilhada.
  void _onAuthChanged() {
    if (_auth.status == AuthStatus.unauthenticated) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  /// Push de lembrete tocado: abre o historico ja filtrado na refeicao.
  // TODO(Task 2.8): trocar pela tela de registro de refeicao quando existir.
  void _openMealHistory(MealType type) {
    void open() {
      final patientId = _auth.userId;
      final navigator = _navigatorKey.currentState;
      if (patientId == null || navigator == null) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => MealHistoryPage(
            repository: _meals,
            patientId: patientId,
            dailyGoalKcal: Env.dailyGoalKcal,
            initialType: type,
          ),
        ),
      );
    }

    // App aberto pelo push: o navigator pode ainda nao existir.
    if (_navigatorKey.currentState != null) {
      open();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
    }
  }

  /// Push recebido com o app aberto: o sistema nao o exibe, entao avisa aqui.
  void _showReminderSnackBar(MealType type) {
    _messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Você ainda não registrou seu ${type.label.toLowerCase()}.',
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _openMealHistory(type),
          ),
        ),
      );
  }

  @override
  void dispose() {
    for (final subscription in _pushSubscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(_pushRegistration.dispose());
    _auth.removeListener(_onAuthChanged);
    _auth.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _messengerKey,
      title: Env.appName,
      debugShowCheckedModeBanner: Env.environment != 'production',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: ListenableBuilder(
        listenable: _auth,
        builder: (context, _) => switch (_auth.status) {
          AuthStatus.unknown => const _SplashPage(),
          AuthStatus.unauthenticated =>
            WelcomePage(auth: _auth, screening: _screening),
          AuthStatus.authenticated => HomePlaceholderPage(
              auth: _auth,
              screening: _screening,
              plans: _plans,
              reminders: _reminders,
              push: widget.push,
              privacy: _privacy,
            ),
        },
      ),
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
