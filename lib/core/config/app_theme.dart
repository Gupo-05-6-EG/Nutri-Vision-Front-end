import 'package:flutter/material.dart';

import '../ui/nv_colors.dart';

/// Tema do app, com a identidade visual do protótipo (RNF01).
///
/// Paleta Material 3 tirada do `prototipo.svg`: verde escuro (#2B6C00) nos
/// botões principais, verde vivo (#58CC02) no progresso e nos destaques,
/// amarelo (#FEC700) no XP e na seleção, laranja (#FF9C27) na ofensiva. A fonte
/// é a Nunito, embutida em `assets/fonts` (funciona sem internet).
class AppTheme {
  const AppTheme._();

  static const fontFamily = 'Nunito';

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2B6C00),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF58CC02),
    onPrimaryContainer: Color(0xFF133A00),
    secondary: Color(0xFF6E5400),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFEC700),
    onSecondaryContainer: Color(0xFF4A3900),
    tertiary: Color(0xFF8C5000),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFF9C27),
    onTertiaryContainer: Color(0xFF4A2800),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),
    surface: Color(0xFFFBF9F8),
    onSurface: Color(0xFF1B1C1C),
    onSurfaceVariant: Color(0xFF3F4A36),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F3F3),
    surfaceContainer: Color(0xFFEFEDED),
    surfaceContainerHigh: Color(0xFFEAE8E7),
    surfaceContainerHighest: Color(0xFFE4E2E2),
    outline: Color(0xFF6F7B64),
    outlineVariant: Color(0xFFBECBB1),
    inverseSurface: Color(0xFF303030),
    onInverseSurface: Color(0xFFF2F0F0),
    inversePrimary: Color(0xFF6BE026),
  );

  /// Tema escuro derivado das mesmas cores: o verde vivo passa a ser o primário
  /// (contraste com o fundo escuro) e o amarelo e o laranja continuam marcando
  /// XP e ofensiva.
  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF6BE026),
    onPrimary: Color(0xFF0F2E00),
    primaryContainer: Color(0xFF2B6C00),
    onPrimaryContainer: Color(0xFFC6F7A6),
    secondary: Color(0xFFFEC700),
    onSecondary: Color(0xFF3A2C00),
    secondaryContainer: Color(0xFF5A4500),
    onSecondaryContainer: Color(0xFFFFE08A),
    tertiary: Color(0xFFFFB86B),
    onTertiary: Color(0xFF4A2800),
    tertiaryContainer: Color(0xFF6A3B00),
    onTertiaryContainer: Color(0xFFFFDCBF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131412),
    onSurface: Color(0xFFE4E2E0),
    onSurfaceVariant: Color(0xFFBECBB1),
    surfaceContainerLowest: Color(0xFF1C1D1B),
    surfaceContainerLow: Color(0xFF222320),
    surfaceContainer: Color(0xFF282926),
    surfaceContainerHigh: Color(0xFF2F302D),
    surfaceContainerHighest: Color(0xFF3A3B37),
    outline: Color(0xFF889580),
    outlineVariant: Color(0xFF3F4A36),
    inverseSurface: Color(0xFFE4E2E0),
    onInverseSurface: Color(0xFF303030),
    inversePrimary: Color(0xFF2B6C00),
  );

  static ThemeData get light => _build(_lightScheme, NvColors.light);

  static ThemeData get dark => _build(_darkScheme, NvColors.dark);

  static ThemeData _build(ColorScheme scheme, NvColors nv) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
    );
    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall
          ?.copyWith(fontWeight: FontWeight.w900, color: scheme.onSurface),
      headlineMedium: base.textTheme.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w900, color: scheme.onSurface),
      headlineSmall: base.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w900, color: scheme.onSurface),
      titleLarge: base.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
      titleMedium: base.textTheme.titleMedium
          ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
      titleSmall: base.textTheme.titleSmall
          ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      labelLarge:
          base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      bodyMedium: base.textTheme.bodyMedium
          ?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
    );
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const buttonText = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w800,
      fontSize: 16,
    );

    return base.copyWith(
      textTheme: text,
      extensions: [nv],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
        shape: Border(
          bottom: BorderSide(color: scheme.surfaceContainerHighest, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: rounded16,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: rounded16,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outlineVariant, width: 2),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(textStyle: buttonText.copyWith(fontSize: 15)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.surfaceContainerHighest),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.surfaceContainerHighest),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.surfaceContainerHighest, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: scheme.secondaryContainer,
        backgroundColor: scheme.surfaceContainerLowest,
        side: BorderSide(color: scheme.surfaceContainerHighest, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        checkmarkColor: scheme.onSecondaryContainer,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : scheme.surfaceContainerLowest,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
        ),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primaryContainer,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.surfaceContainerHighest),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
