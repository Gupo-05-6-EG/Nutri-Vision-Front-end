import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Onde a preferência de tema fica salva entre aberturas do app.
abstract class ThemePreferenceStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SecureThemePreferenceStore implements ThemePreferenceStore {
  SecureThemePreferenceStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'theme_mode';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String value) async {
    try {
      await _storage.write(key: _key, value: value);
    } catch (_) {
      // Sem armazenamento: vale só até fechar o app.
    }
  }
}

class MemoryThemePreferenceStore implements ThemePreferenceStore {
  MemoryThemePreferenceStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}

/// "Modo de Exibição" do Perfil: claro, escuro ou o do sistema.
class ThemeController extends ChangeNotifier {
  ThemeController({ThemePreferenceStore? store})
      : _store = store ?? SecureThemePreferenceStore();

  final ThemePreferenceStore _store;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> load() async {
    final saved = await _store.read();
    final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
    if (mode != null && mode != _mode) {
      _mode = mode;
      notifyListeners();
    }
  }

  void setMode(ThemeMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    unawaited(_store.write(mode.name));
  }

  static String label(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Escuro',
        ThemeMode.system => 'Sistema',
      };
}
