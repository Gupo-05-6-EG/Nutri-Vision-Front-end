import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_services.dart';
import '../../achievements/presentation/achievements_page.dart';
import '../../challenges/presentation/challenges_page.dart';
import '../../foods/presentation/food_search_page.dart';
import '../../linking/presentation/linking_page.dart';
import '../../meals/domain/meal_type.dart';
import '../../meals/presentation/meal_history_page.dart';
import '../../plan/presentation/plan_progress_page.dart';
import '../../privacy/presentation/privacy_settings_page.dart';
import '../../profile/domain/patient_profile.dart';
import '../../recognition/presentation/photo_analysis_page.dart';
import '../../reminders/presentation/meal_reminders_page.dart';
import '../../screening/presentation/screening_page.dart';

/// Telas abertas a partir das abas, num lugar so.
class AppRoutes {
  const AppRoutes._();

  static Future<T?> _push<T>(BuildContext context, Widget page) =>
      Navigator.of(context).push<T>(MaterialPageRoute<T>(builder: (_) => page));

  static Future<void> plan(BuildContext context, AppServices s) async {
    final patientId = s.patientId;
    if (patientId == null) return;
    final goal = s.profile.goal;
    await _push<void>(
      context,
      PlanProgressPage(
        repository: s.plans,
        patientId: patientId,
        fallbackGoalKcal:
            goal.source == GoalSource.screening ? goal.kcal : null,
      ),
    );
  }

  static Future<void> history(
    BuildContext context,
    AppServices s, {
    MealType? type,
  }) async {
    final patientId = s.patientId;
    if (patientId == null) return;
    await _push<void>(
      context,
      MealHistoryPage(
        repository: s.meals,
        patientId: patientId,
        dailyGoalKcal: s.profile.goal.kcal,
        syncService: s.syncService,
        initialType: type,
      ),
    );
    unawaited(s.profile.refresh());
  }

  /// Registro por foto. Devolve `true` quando a refeicao foi registrada.
  static Future<bool> photoMeal(BuildContext context, AppServices s) async {
    final patientId = s.patientId;
    if (patientId == null) return false;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await _push<bool>(
      context,
      PhotoAnalysisPage(
        repository: s.recognition,
        patientId: patientId,
        foods: s.tacoFoods,
      ),
    );
    if (saved == true) {
      unawaited(s.profile.refresh());
      messenger.showSnackBar(
        const SnackBar(content: Text('Refeição registrada.')),
      );
      return true;
    }
    return false;
  }

  static Future<void> reminders(BuildContext context, AppServices s) async {
    final patientId = s.patientId;
    if (patientId == null) return;
    await _push<void>(
      context,
      MealRemindersPage(
        repository: s.reminders,
        patientId: patientId,
        push: s.push,
      ),
    );
  }

  static Future<void> challenges(BuildContext context, AppServices s) async {
    final patientId = s.patientId;
    if (patientId == null) return;
    await _push<void>(
      context,
      ChallengesPage(repository: s.challenges, patientId: patientId),
    );
  }

  static Future<void> achievements(BuildContext context, AppServices s) =>
      _push<void>(context, AchievementsPage(repository: s.achievements));

  static Future<void> foods(BuildContext context, AppServices s) => _push<void>(
        context,
        FoodSearchPage(repository: s.patientFoods(), selectPortion: false),
      );

  static Future<void> linking(BuildContext context, AppServices s) async {
    await _push<void>(context, LinkingPage(auth: s.auth));
    unawaited(s.profile.refresh());
  }

  static Future<void> privacy(BuildContext context, AppServices s) =>
      _push<void>(
        context,
        PrivacySettingsPage(auth: s.auth, repository: s.privacy),
      );

  static Future<void> screening(BuildContext context, AppServices s) async {
    await _push<void>(
      context,
      ScreeningPage(auth: s.auth, repository: s.screening),
    );
    unawaited(s.profile.refresh());
  }
}
