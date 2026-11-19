import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'nv_colors.dart';

/// Componentes visuais do protótipo, usados por todas as telas.

/// Cartão branco com o "degrau": uma faixa mais escura de 4 px embaixo.
class NvCard extends StatelessWidget {
  const NvCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
    this.stepColor,
    this.radius = 20,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? stepColor;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nv = NvColors.of(context);
    final borderRadius = BorderRadius.circular(radius);
    final body = Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: borderRadius,
        border: Border.all(
          color: stepColor ?? nv.cardStep,
          width: 1.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      container: semanticLabel != null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: stepColor ?? nv.cardStep,
          borderRadius: borderRadius,
        ),
        child: body,
      ),
    );
  }
}

enum NvButtonStyle { primary, accent, secondary, neutral, danger }

/// Botão do protótipo: cheio, cantos de 16 e o "degrau" que "afunda" ao tocar.
class NvButton extends StatefulWidget {
  const NvButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = NvButtonStyle.primary,
    this.loading = false,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NvButtonStyle style;
  final bool loading;

  /// Selo à direita do texto (ex.: "+20 XP").
  final Widget? trailing;

  @override
  State<NvButton> createState() => _NvButtonState();
}

class _NvButtonState extends State<NvButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nv = NvColors.of(context);
    final (background, foreground, step) = switch (widget.style) {
      NvButtonStyle.primary => (
          scheme.primary,
          scheme.onPrimary,
          nv.primaryStep
        ),
      NvButtonStyle.accent => (
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
          nv.accentStep,
        ),
      NvButtonStyle.secondary => (nv.xp, nv.onXp, nv.xpStep),
      NvButtonStyle.neutral => (
          scheme.surfaceContainerHigh,
          scheme.onSurface,
          nv.neutralStep,
        ),
      NvButtonStyle.danger => (
          scheme.errorContainer,
          scheme.onErrorContainer,
          scheme.error.withValues(alpha: 0.5),
        ),
    };
    final enabled = widget.onPressed != null && !widget.loading;
    final depth = enabled && !_pressed ? 4.0 : 0.0;
    final radius = BorderRadius.circular(16);

    final content = widget.loading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
              semanticsLabel: 'Aguarde, processando solicitação',
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: foreground, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 10),
                widget.trailing!,
              ],
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.loading ? null : widget.label,
      excludeSemantics: !widget.loading,
      onTap: enabled ? widget.onPressed : null,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: Opacity(
          opacity: enabled || widget.loading ? 1 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            margin: EdgeInsets.only(top: 4 - depth),
            padding: EdgeInsets.only(bottom: depth),
            decoration: BoxDecoration(color: step, borderRadius: radius),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: background, borderRadius: radius),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo amarelo de XP ("⚡ 520 XP").
class XpBadge extends StatelessWidget {
  const XpBadge({required this.xp, this.prefix = '', super.key});

  final int xp;

  /// Ex.: "+" para "+20 XP".
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final nv = NvColors.of(context);
    return _Pill(
      color: nv.xp,
      step: nv.xpStep,
      foreground: nv.onXp,
      icon: Icons.bolt_rounded,
      text: '$prefix${formatInt(xp)} XP',
      semantics: prefix.isEmpty ? '${formatInt(xp)} XP' : 'Ganhe $xp XP',
    );
  }
}

/// Selo laranja da ofensiva ("🔥 12 dias").
class StreakBadge extends StatelessWidget {
  const StreakBadge({required this.days, this.suffix, super.key});

  final int days;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final nv = NvColors.of(context);
    final text = '$days ${days == 1 ? 'dia' : 'dias'}${suffix ?? ''}';
    return _Pill(
      color: nv.streak,
      step: nv.streak.withValues(alpha: 0.6),
      foreground: nv.onStreak,
      icon: Icons.local_fire_department_rounded,
      text: text,
      semantics: 'Ofensiva de $text',
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.color,
    required this.step,
    required this.foreground,
    required this.icon,
    required this.text,
    required this.semantics,
  });

  final Color color;
  final Color step;
  final Color foreground;
  final IconData icon;
  final String text;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: step,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anel de progresso da meta diária (protótipo: "1500 / 2000 kcal").
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.progress,
    required this.child,
    this.size = 200,
    this.stroke = 22,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// De 0 a 1 (acima de 1 o anel fica cheio e muda de cor).
  final double progress;
  final Widget child;
  final double size;
  final double stroke;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = progress > 1;
    return Semantics(
      container: semanticLabel != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: progress.clamp(0, 1).toDouble(),
            stroke: stroke,
            track: scheme.surfaceContainerHigh,
            color: over
                ? scheme.tertiaryContainer
                : (color ?? scheme.primaryContainer),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.stroke,
    required this.track,
    required this.color,
  });

  final double progress;
  final double stroke;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
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
    if (progress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Cartão de macro do protótipo: ícone, nome, "80g / 120g" e a barra.
class MacroBar extends StatelessWidget {
  const MacroBar({
    required this.label,
    required this.icon,
    required this.color,
    required this.consumed,
    required this.goal,
    this.unit = 'g',
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double consumed;
  final double? goal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalValue = goal;
    final hasGoal = goalValue != null && goalValue > 0;
    final progress = hasGoal ? (consumed / goalValue).clamp(0.0, 1.0) : 0.0;
    final consumedText = '${formatInt(consumed.round())}$unit';
    final goalText =
        hasGoal ? '${formatInt(goalValue.round())}$unit' : 'sem meta';
    return NvCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      semanticLabel: '$label: $consumedText de $goalText',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 8),
                Text(label, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  consumedText,
                  style: theme.textTheme.labelLarge,
                ),
                const Spacer(),
                Text('/ $goalText', style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                color: color,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar com as iniciais do nome (o app não guarda foto de perfil).
class NvAvatar extends StatelessWidget {
  const NvAvatar({
    required this.name,
    this.size = 48,
    this.highlight = false,
    super.key,
  });

  final String name;
  final double size;
  final bool highlight;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: highlight
              ? scheme.surfaceContainerLowest
              : scheme.primaryContainer,
          border: Border.all(
            color: highlight
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            width: size > 60 ? 4 : 2,
          ),
        ),
        child: Text(
          initials(name),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: size * 0.36,
            color: highlight ? scheme.primary : scheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// Marca "Nutri Vision" do topo das telas do app.
class NvBrand extends StatelessWidget {
  const NvBrand({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      label: 'Nutri Vision',
      excludeSemantics: true,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, color: scheme.primary, size: 26),
            const SizedBox(width: 6),
            Text(
              'Nutri Vision',
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título de seção ("Estatísticas", "Suas Conquistas").
class NvSectionTitle extends StatelessWidget {
  const NvSectionTitle(this.text, {this.icon, this.trailing, super.key});

  final String text;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: theme.colorScheme.secondary, size: 24),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: theme.textTheme.titleLarge),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Número inteiro com separador de milhar brasileiro: 2234 -> "2.234".
String formatInt(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}
