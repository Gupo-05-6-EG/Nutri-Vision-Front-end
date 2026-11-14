import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/network/connectivity_service.dart';
import 'features/meals/data/local_meal_store.dart';
import 'features/reminders/application/firebase_push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  // Sem as chaves do Firebase no .env, o app roda sem push (RF26).
  final push = await FirebasePushService.create(Env.firebase);
  final localMealStore = await HiveMealStore.open();
  runApp(
    NutriVisionApp(
      push: push,
      localMealStore: localMealStore,
      connectivity: ConnectivityPlusService(),
    ),
  );
}
