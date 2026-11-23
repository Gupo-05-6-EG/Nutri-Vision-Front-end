import 'dart:async';

import 'package:flutter/material.dart';

import 'app_services.dart';
import 'core/config/app_theme.dart';
import 'core/config/theme_controller.dart';
import 'core/config/env.dart';
import 'core/network/api_client.dart';
import 'core/network/connectivity_service.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/token_storage.dart';
import 'features/auth/presentation/welcome_page.dart';
import 'features/challenges/data/challenge_repository.dart';
import 'features/meals/application/meal_sync_service.dart';
import 'features/meals/data/local_meal_store.dart';
import 'features/achievements/data/achievement_repository.dart';
import 'features/meals/data/meal_repository.dart';
import 'features/meals/domain/meal_type.dart';
import 'features/meals/presentation/meal_history_page.dart';
import 'features/plan/data/plan_repository.dart';
import 'features/privacy/data/privacy_repository.dart';
import 'features/profile/application/profile_controller.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/reminders/application/push_registration.dart';
import 'features/reminders/application/push_service.dart';
import 'features/recognition/data/recognition_repository.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/screening/data/screening_repository.dart';
import 'features/shell/presentation/main_shell.dart';

class NutriVisionApp extends StatefulWidget {
  const NutriVisionApp({
    this.push = const DisabledPushService(),
    this.localMealStore,
    this.connectivity = const DisabledConnectivityService(),
    super.key,
  });

  /// Push dos lembretes de refeicao (RF26); desligado se o Firebase nao
  /// estiver configurado no `.env`.
  final PushService push;

  /// Armazenamento local (Hive) de refeicoes para operacao offline (RNF07).
  final LocalMealStore? localMealStore;

  /// Listener de conectividade para envio em lote de refeicoes pendentes.
  final ConnectivityService connectivity;

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
  late final MealRepository _meals = MealRepository(
    _client,
    localStore: widget.localMealStore,
  );
  late final MealSyncService _mealSync = MealSyncService(
    repository: _meals,
    connectivity: widget.connectivity,
    auth: _auth,
  );
  late final ReminderRepository _reminders = ReminderRepository(_client);
  late final RecognitionRepository _recognition = RecognitionRepository(
    _client,
    localStore: widget.localMealStore,
  );
  late final ChallengeRepository _challenges = ChallengeRepository(_client);
  late final ProfileController _profile = ProfileController(
    auth: _auth,
    repository: ProfileRepository(_client),
    syncEvents: _mealSync.onSynced,
  );
  late final PushRegistration _pushRegistration = PushRegistration(
    auth: _auth,
    repository: _reminders,
    push: widget.push,
  );
  final ThemeController _theme = ThemeController();
  late final AppServices _services = AppServices(
    theme: _theme,
    client: _client,
    auth: _auth,
    profile: _profile,
    screening: _screening,
    plans: _plans,
    reminders: _reminders,
    push: widget.push,
    meals: _meals,
    syncService: _mealSync,
    recognition: _recognition,
    challenges: _challenges,
    achievements: AchievementRepository(_client),
    privacy: _privacy,
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
    unawaited(_mealSync.start());
    unawaited(_auth.restoreSession());
    unawaited(_theme.load());
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
            dailyGoalKcal: _profile.goal.kcal,
            initialType: type,
            syncService: _mealSync,
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
    unawaited(_mealSync.dispose());
    _auth.removeListener(_onAuthChanged);
    _profile.dispose();
    _theme.dispose();
    _auth.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) => _buildApp(context),
    );
  }

  Widget _buildApp(BuildContext context) {
    return MaterialApp(
      themeMode: _theme.mode,
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
          // A chave por paciente zera as abas ao trocar de conta.
          AuthStatus.authenticated => MainShell(
              key: ValueKey(_auth.userId),
              services: _services,
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
