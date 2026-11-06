import 'package:flutter/material.dart';

import 'core/config/app_theme.dart';
import 'core/config/env.dart';
import 'core/network/api_client.dart';
import 'features/linking/presentation/linking_page.dart';

class NutriVisionApp extends StatefulWidget {
  const NutriVisionApp({super.key});

  @override
  State<NutriVisionApp> createState() => _NutriVisionAppState();
}

class _NutriVisionAppState extends State<NutriVisionApp> {
  late final ApiClient _client = ApiClient(baseUrl: Env.apiUrl);

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Env.appName,
      debugShowCheckedModeBanner: Env.environment != 'production',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: LinkingPage(client: _client),
    );
  }
}
