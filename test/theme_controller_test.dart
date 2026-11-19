import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/core/config/theme_controller.dart';

void main() {
  test('guarda e recupera o modo de exibicao', () async {
    final store = MemoryThemePreferenceStore();
    final controller = ThemeController(store: store);

    controller.setMode(ThemeMode.dark);
    await pumpEventQueue();
    expect(store.value, 'dark');

    final reopened = ThemeController(store: store);
    await reopened.load();
    expect(reopened.mode, ThemeMode.dark);
  });

  test('valor desconhecido fica no tema do sistema', () async {
    final controller =
        ThemeController(store: MemoryThemePreferenceStore('rosa'));
    await controller.load();

    expect(controller.mode, ThemeMode.system);
    expect(ThemeController.label(ThemeMode.light), 'Claro');
  });
}
