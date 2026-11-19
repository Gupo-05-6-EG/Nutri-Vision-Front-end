import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../achievements/data/achievement_repository.dart';
import '../../achievements/presentation/achievements_page.dart';
import '../../auth/application/auth_controller.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../challenges/presentation/challenges_page.dart';
import '../../meals/application/meal_sync_service.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/presentation/meal_history_page.dart';
import '../../foods/data/food_repository.dart';
import '../../foods/presentation/food_search_page.dart';
import '../../linking/presentation/linking_page.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/presentation/plan_progress_page.dart';
import '../../privacy/data/privacy_repository.dart';
import '../../privacy/presentation/privacy_settings_page.dart';
import '../../profile/application/profile_controller.dart';
import '../../profile/domain/patient_profile.dart';
import '../../recognition/data/recognition_repository.dart';
import '../../recognition/presentation/photo_analysis_page.dart';
import '../../reminders/application/push_service.dart';
import '../../reminders/data/reminder_repository.dart';
import '../../reminders/presentation/meal_reminders_page.dart';
import '../../screening/data/screening_repository.dart';
import '../../screening/presentation/screening_page.dart';

/// Destino temporario depois do login. A home real (meta diaria, registro de
/// refeicoes etc.) entra em outras tasks e substitui esta tela.
class HomePlaceholderPage extends StatelessWidget {
  const HomePlaceholderPage({
    required this.auth,
    required this.screening,
    required this.plans,
    required this.reminders,
    required this.push,
    this.challenges,
    this.meals,
    this.syncService,
    this.achievements,
    this.foods,
    this.privacy,
    this.recognition,
    this.tacoFoods,
    this.profile,
    super.key,
  });

  final AuthController auth;
  final ScreeningRepository screening;
  final PlanRepository plans;
  final ReminderRepository reminders;
  final PushService push;
  final ChallengeRepository? challenges;
  final MealRepository? meals;
  final MealSyncService? syncService;
  final AchievementRepository? achievements;
  final FoodRepository? foods;
  final PrivacyRepository? privacy;

  /// Analise da foto pela IA e registro da refeicao revisada.
  final RecognitionRepository? recognition;

  /// Busca so na TACO, para trocar um alimento na revisao da foto.
  final FoodRepository? tacoFoods;

  /// Perfil do paciente: fonte unica da meta diaria (A4).
  final ProfileController? profile;

  /// Meta da triagem, quando e ela que vale (sem plano do nutricionista).
  double? get _screeningGoal {
    final goal = profile?.goal;
    return goal != null && goal.source == GoalSource.screening
        ? goal.kcal
        : null;
  }

  void _openPlan(BuildContext context, int patientId) {
    final ceiling = _screeningGoal;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanProgressPage(
          repository: plans,
          patientId: patientId,
          fallbackGoalKcal: ceiling,
        ),
      ),
    );
  }

  void _openMeals(BuildContext context, int patientId) {
    final mealRepository = meals;
    if (mealRepository == null) return;
    final dailyGoal = profile?.goal.kcal;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MealHistoryPage(
          repository: mealRepository,
          patientId: patientId,
          dailyGoalKcal: dailyGoal,
          syncService: syncService,
        ),
      ),
    );
  }

  Future<void> _openPhotoMeal(BuildContext context, int patientId) async {
    final repository = recognition;
    if (repository == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhotoAnalysisPage(
          repository: repository,
          patientId: patientId,
          foods: tacoFoods,
        ),
      ),
    );
    if (saved == true) {
      unawaited(profile?.refresh());
      messenger.showSnackBar(
        const SnackBar(content: Text('Refeição registrada.')),
      );
    }
  }

  void _openReminders(BuildContext context, int patientId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MealRemindersPage(
          repository: reminders,
          patientId: patientId,
          push: push,
        ),
      ),
    );
  }

  void _openChallenges(BuildContext context, int patientId) {
    final repo = challenges;
    if (repo == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChallengesPage(
          repository: repo,
          patientId: patientId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Env.appName),
        actions: [
          if (privacy case final repository?)
            IconButton(
              tooltip: 'Privacidade e meus dados',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PrivacySettingsPage(
                    auth: auth,
                    repository: repository,
                  ),
                ),
              ),
              icon: const Icon(Icons.privacy_tip_outlined),
            ),
          IconButton(
            tooltip: 'Sair da conta',
            onPressed: auth.logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Login realizado com sucesso.\n'
                'As telas principais entram nas próximas tasks.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: auth.userId == null
                    ? null
                    : () => _openPlan(context, auth.userId!),
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Meu plano e progresso'),
              ),
              if (recognition != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: auth.userId == null
                      ? null
                      : () => _openPhotoMeal(context, auth.userId!),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Registrar refeição por foto'),
                ),
              ],
              if (meals != null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: auth.userId == null
                      ? null
                      : () => _openMeals(context, auth.userId!),
                  icon: const Icon(Icons.restaurant_menu_outlined),
                  label: const Text('Histórico de refeições'),
                ),
              ],
              const SizedBox(height: 12),
              // A API ainda nao expoe a meta salva, entao a home nao sabe se
              // a triagem ja foi feita: o botao serve para fazer ou refazer.
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ScreeningPage(auth: auth, repository: screening),
                  ),
                ),
                icon: const Icon(Icons.local_fire_department_outlined),
                label: const Text('Calcular minha meta diária'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: auth.userId == null
                    ? null
                    : () => _openReminders(context, auth.userId!),
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Lembretes de refeição'),
              ),
              if (challenges != null) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: auth.userId == null
                      ? null
                      : () => _openChallenges(context, auth.userId!),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Desafios entre amigos'),
                ),
              ],
              if (achievements case final repository?) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AchievementsPage(repository: repository),
                    ),
                  ),
                  icon: const Icon(Icons.emoji_events_outlined),
                  label: const Text('Minhas conquistas'),
                ),
              ],
              if (foods case final repository?) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FoodSearchPage(
                        repository: repository,
                        selectPortion: false,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.restaurant_outlined),
                  label: const Text('Meus alimentos'),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LinkingPage(auth: auth),
                  ),
                ),
                icon: const Icon(Icons.link),
                label: const Text('Vincular nutricionista'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
