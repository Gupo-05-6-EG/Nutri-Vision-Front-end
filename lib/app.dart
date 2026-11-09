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
import 'features/plan/data/plan_repository.dart';
import 'features/screening/data/screening_repository.dart';

class NutriVisionApp extends StatefulWidget {
  const NutriVisionApp({super.key});

  @override
  State<NutriVisionApp> createState() => _NutriVisionAppState();
}

class _NutriVisionAppState extends State<NutriVisionApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final ApiClient _client = ApiClient(baseUrl: Env.apiUrl);
  late final AuthController _auth = AuthController(
    client: _client,
    repository: AuthRepository(_client),
    storage: SecureTokenStorage(),
  );
  late final ScreeningRepository _screening = ScreeningRepository(_client);
  late final PlanRepository _plans = PlanRepository(_client);

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    unawaited(_auth.restoreSession());
  }

  // Ao perder a sessao (logout ou 401), descarta qualquer tela empilhada.
  void _onAuthChanged() {
    if (_auth.status == AuthStatus.unauthenticated) {
      _navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _auth.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
