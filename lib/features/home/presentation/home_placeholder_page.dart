import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../auth/application/auth_controller.dart';
import '../../meals/application/meal_sync_service.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/presentation/meal_history_page.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/presentation/plan_progress_page.dart';
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
    this.meals,
    this.syncService,
    super.key,
  });

  final AuthController auth;
  final ScreeningRepository screening;
  final PlanRepository plans;
  final ReminderRepository reminders;
  final PushService push;
  final MealRepository? meals;
  final MealSyncService? syncService;

  void _openPlan(BuildContext context, int patientId) {
    // O teto da triagem so vale se foi calculado por este paciente.
    final goal = screening.lastGoal;
    final ceiling =
        goal != null && goal.patientId == patientId ? goal.dailyKcal : null;
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
    final goal = screening.lastGoal;
    final dailyGoal = goal != null && goal.patientId == patientId
        ? goal.dailyKcal
        : Env.dailyGoalKcal;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(Env.appName),
        actions: [
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
            ],
          ),
        ),
      ),
    );
  }
}
