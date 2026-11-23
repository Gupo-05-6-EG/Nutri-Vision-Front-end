import 'package:flutter/material.dart';

/// Cores de domínio do protótipo que não cabem no `ColorScheme`: macros, XP,
/// ofensiva e o "degrau" (borda inferior mais escura) de cartões e botões.
@immutable
class NvColors extends ThemeExtension<NvColors> {
  const NvColors({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.xp,
    required this.onXp,
    required this.streak,
    required this.onStreak,
    required this.cardStep,
    required this.primaryStep,
    required this.accentStep,
    required this.xpStep,
    required this.neutralStep,
  });

  final Color protein;
  final Color carbs;
  final Color fat;
  final Color xp;
  final Color onXp;
  final Color streak;
  final Color onStreak;

  /// Borda inferior dos cartões brancos.
  final Color cardStep;

  /// "Degrau" do botão verde escuro.
  final Color primaryStep;

  /// "Degrau" do verde vivo (destaques e seleção).
  final Color accentStep;

  /// "Degrau" do amarelo (XP, botão secundário).
  final Color xpStep;

  /// "Degrau" do botão neutro (cinza).
  final Color neutralStep;

  static const light = NvColors(
    protein: Color(0xFFFF9C27),
    carbs: Color(0xFFFEC700),
    fat: Color(0xFFBA1A1A),
    xp: Color(0xFFFEC700),
    onXp: Color(0xFF3A2C00),
    streak: Color(0xFFFF9C27),
    onStreak: Color(0xFF4A2800),
    cardStep: Color(0xFFE4E2E2),
    primaryStep: Color(0xFF1E5000),
    accentStep: Color(0xFF46A302),
    xpStep: Color(0xFFC79C00),
    neutralStep: Color(0xFFBECBB1),
  );

  static const dark = NvColors(
    protein: Color(0xFFFFB86B),
    carbs: Color(0xFFFEC700),
    fat: Color(0xFFFF8A80),
    xp: Color(0xFFFEC700),
    onXp: Color(0xFF3A2C00),
    streak: Color(0xFFFF9C27),
    onStreak: Color(0xFF4A2800),
    cardStep: Color(0xFF000000),
    primaryStep: Color(0xFF3E9A10),
    accentStep: Color(0xFF1E5000),
    xpStep: Color(0xFF8A6C00),
    neutralStep: Color(0xFF000000),
  );

  static NvColors of(BuildContext context) =>
      Theme.of(context).extension<NvColors>() ?? light;

  @override
  NvColors copyWith({
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? xp,
    Color? onXp,
    Color? streak,
    Color? onStreak,
    Color? cardStep,
    Color? primaryStep,
    Color? accentStep,
    Color? xpStep,
    Color? neutralStep,
  }) {
    return NvColors(
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      xp: xp ?? this.xp,
      onXp: onXp ?? this.onXp,
      streak: streak ?? this.streak,
      onStreak: onStreak ?? this.onStreak,
      cardStep: cardStep ?? this.cardStep,
      primaryStep: primaryStep ?? this.primaryStep,
      accentStep: accentStep ?? this.accentStep,
      xpStep: xpStep ?? this.xpStep,
      neutralStep: neutralStep ?? this.neutralStep,
    );
  }

  @override
  NvColors lerp(ThemeExtension<NvColors>? other, double t) {
    if (other is! NvColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return NvColors(
      protein: mix(protein, other.protein),
      carbs: mix(carbs, other.carbs),
      fat: mix(fat, other.fat),
      xp: mix(xp, other.xp),
      onXp: mix(onXp, other.onXp),
      streak: mix(streak, other.streak),
      onStreak: mix(onStreak, other.onStreak),
      cardStep: mix(cardStep, other.cardStep),
      primaryStep: mix(primaryStep, other.primaryStep),
      accentStep: mix(accentStep, other.accentStep),
      xpStep: mix(xpStep, other.xpStep),
      neutralStep: mix(neutralStep, other.neutralStep),
    );
  }
}
