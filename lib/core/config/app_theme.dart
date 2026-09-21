import 'package:flutter/material.dart';

/// Tema do app. As cores definitivas saem do Figma na Task 1.7 (RNF01).
class AppTheme {
  const AppTheme._();

  static const Color _seed = Color(0xFF2E7D4F);

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      );
}
