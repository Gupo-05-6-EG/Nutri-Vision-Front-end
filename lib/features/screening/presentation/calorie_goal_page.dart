import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/screening.dart';
import 'widgets/screening_widgets.dart';

/// Formata kcal como inteiro com separador de milhar (ex.: `2.890`).
String formatKcal(double value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer(value.round() < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Formata o fator de atividade sem zeros sobrando (ex.: `1,2`, `1,375`).
String formatFactor(double value) {
  var text = value.toStringAsFixed(3);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return text.replaceAll('.', ',');
}

/// Confirmacao da triagem: mostra o teto calorico diario gerado e como ele
/// foi calculado. O visual segue o card "Meta Diaria" do dashboard (Figma).
class CalorieGoalPage extends StatelessWidget {
  const CalorieGoalPage({
    required this.goal,
    required this.activity,
    super.key,
  });

  final CalorieGoal goal;

  /// Nivel escolhido na triagem, para explicar o fator.
  final ActivityLevel activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.celebration, size: 40, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Sua meta está pronta!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calculamos quanta energia você precisa por dia com base '
                    'nos seus dados.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _GoalCard(kcal: goal.dailyKcal),
                  const SizedBox(height: 16),
                  _BreakdownCard(goal: goal, activity: activity),
                  const SizedBox(height: 32),
                  ScreeningPrimaryButton(
                    label: 'Começar minha jornada',
                    onPressed: () => Navigator.of(context)
                        .popUntil((route) => route.isFirst),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.kcal});

  final double kcal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _Card(
      child: Column(
        children: [
          Text(
            'Meta Diária',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            label: 'Meta diária de ${formatKcal(kcal)} quilocalorias',
            excludeSemantics: true,
            child: SizedBox.square(
              dimension: 200,
              child: CustomPaint(
                painter: _RingPainter(
                  track: scheme.surfaceContainerHighest,
                  color: scheme.primary,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restaurant, color: scheme.primary, size: 32),
                    const SizedBox(height: 4),
                    Text(
                      formatKcal(kcal),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'kcal por dia',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Esse é o seu teto calórico diário inicial.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Anel cheio: no inicio do dia a meta inteira esta disponivel.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.track, required this.color});

  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.track != track || oldDelegate.color != color;
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.goal, required this.activity});

  final CalorieGoal goal;
  final ActivityLevel activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget row(String label, String value, {bool strong = false}) {
      final style = strong
          ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
          : theme.textTheme.bodyLarge;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: style)),
            Text(value, style: style),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Como chegamos nesse número',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          row('Metabolismo basal', '${formatKcal(goal.basalKcal)} kcal'),
          row(
            'Atividade: ${activity.label}',
            '× ${formatFactor(goal.activityFactor)}',
          ),
          const Divider(height: 24),
          row(
            'Meta diária',
            '${formatKcal(goal.dailyKcal)} kcal',
            strong: true,
          ),
          const SizedBox(height: 8),
          Text(
            'Calculado pela equação de Harris-Benedict. Seu nutricionista '
            'pode ajustar essa meta, e você pode refazer a triagem quando '
            'seus dados mudarem.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
