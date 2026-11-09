import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'features/reminders/application/firebase_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  // Sem as chaves do Firebase no .env, o app roda sem push (RF26).
  final push = await FirebasePushService.create(Env.firebase);
  runApp(NutriVisionApp(push: push));
}
