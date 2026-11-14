import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../auth/application/auth_controller.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../challenges/presentation/challenges_page.dart';
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
    this.challenges,
    super.key,
  });

  final AuthController auth;
  final ScreeningRepository screening;
  final PlanRepository plans;
  final ReminderRepository reminders;
  final PushService push;
  final ChallengeRepository? challenges;

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
            ],
          ),
        ),
      ),
    );
  }
}
