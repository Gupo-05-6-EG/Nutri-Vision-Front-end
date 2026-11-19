import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/core/config/app_theme.dart';
import 'package:nutri_vision/core/ui/nv_colors.dart';
import 'package:nutri_vision/core/ui/nv_widgets.dart';

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  test('formatInt usa o separador de milhar brasileiro', () {
    expect(formatInt(0), '0');
    expect(formatInt(520), '520');
    expect(formatInt(2234), '2.234');
    expect(formatInt(1250000), '1.250.000');
    expect(formatInt(-1500), '-1.500');
  });

  test('iniciais do avatar', () {
    expect(NvAvatar.initials('Alex Silva'), 'AS');
    expect(NvAvatar.initials('maria da silva souza'), 'MS');
    expect(NvAvatar.initials('Cher'), 'C');
    expect(NvAvatar.initials('  '), '?');
  });

  test('tema claro e escuro trazem as cores do prototipo', () {
    expect(AppTheme.light.colorScheme.primary, const Color(0xFF2B6C00));
    expect(
      AppTheme.light.colorScheme.primaryContainer,
      const Color(0xFF58CC02),
    );
    expect(
      AppTheme.light.colorScheme.secondaryContainer,
      const Color(0xFFFEC700),
    );
    expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    expect(AppTheme.light.extension<NvColors>(), isNotNull);
    expect(AppTheme.dark.extension<NvColors>(), NvColors.dark);
  });

  testWidgets('NvButton chama o callback e anuncia o rotulo', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(NvButton(label: 'Entrar', onPressed: () => taps++)),
    );

    await tester.tap(find.text('Entrar'));
    expect(taps, 1);
    expect(find.bySemanticsLabel('Entrar'), findsOneWidget);
  });

  testWidgets('NvButton desabilitado e carregando nao chamam', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            const NvButton(label: 'Desligado', onPressed: null),
            NvButton(
              label: 'Carregando',
              onPressed: () => taps++,
              loading: true,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Desligado'));
    await tester.tap(find.byType(CircularProgressIndicator));
    expect(taps, 0);
  });

  testWidgets('selos de XP e ofensiva', (tester) async {
    await tester.pumpWidget(
      _app(
        const Column(
          children: [
            XpBadge(xp: 1250),
            XpBadge(xp: 20, prefix: '+'),
            StreakBadge(days: 1),
            StreakBadge(days: 12),
          ],
        ),
      ),
    );

    expect(find.text('1.250 XP'), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
    expect(find.text('1 dia'), findsOneWidget);
    expect(find.text('12 dias'), findsOneWidget);
    expect(find.bySemanticsLabel('Ofensiva de 12 dias'), findsOneWidget);
  });

  testWidgets('MacroBar mostra consumo, meta e funciona no tema escuro',
      (tester) async {
    await tester.pumpWidget(
      _app(
        const MacroBar(
          label: 'Proteína',
          icon: Icons.egg,
          color: Colors.orange,
          consumed: 80,
          goal: 120,
        ),
        theme: AppTheme.dark,
      ),
    );

    expect(find.text('80g'), findsOneWidget);
    expect(find.text('/ 120g'), findsOneWidget);
    expect(find.bySemanticsLabel('Proteína: 80g de 120g'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(80 / 120, 0.001));
  });

  testWidgets('ProgressRing com rotulo acessivel', (tester) async {
    await tester.pumpWidget(
      _app(
        const ProgressRing(
          progress: 0.75,
          semanticLabel: '1.500 de 2.000 kcal',
          child: Text('1500'),
        ),
      ),
    );

    expect(find.bySemanticsLabel('1.500 de 2.000 kcal'), findsOneWidget);
  });
}
