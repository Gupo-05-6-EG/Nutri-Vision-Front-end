// Teste de integracao do fluxo foto -> confirmacao (Task 7.4, parte 3/4).
//
// Liga as pecas reais do app (ApiClient, RecognitionRepository,
// MealRepository, RecognitionReviewPage e MealHistoryPage) a uma API falsa
// com estado, que calcula como o back-end (valor por 100 g x gramas / 100,
// TACO 4a edicao) e devolve no historico o que foi registrado. So o HTTP e
// simulado: o que o app envia e le e exatamente o contrato da API.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/meals/data/meal_repository.dart';
import 'package:nutri_vision/features/meals/presentation/meal_history_page.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/recognition/domain/detected_item.dart';
import 'package:nutri_vision/features/recognition/presentation/recognition_review_page.dart';

/// PNG 1x1 transparente, no lugar da foto da camera.
final _photo = MemoryImage(
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    ),
  ),
);

/// Resposta do servico de IA para a foto de um prato de arroz com feijao.
const _respostaIa = '''
{
  "itens": [
    {
      "classe": "arroz",
      "confianca": 0.93,
      "metodo_preparo": "cozido",
      "gramas": 150,
      "caixa": {"x": 0.05, "y": 0.1, "largura": 0.45, "altura": 0.5}
    },
    {
      "classe": "feijao_carioca",
      "confianca": 0.41,
      "metodo_preparo": "cozido",
      "gramas": 100,
      "caixa": {"x": 0.5, "y": 0.4, "largura": 0.4, "altura": 0.45}
    }
  ]
}
''';

/// Meio-dia UTC: a data local e a mesma em qualquer fuso de -11h a +11h.
final _consumedAt = DateTime.utc(2026, 10, 20, 12);

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

double _round2(num value) => (value * 100).round() / 100;

/// API falsa com estado: calcula pela TACO e guarda as refeicoes.
class _Backend {
  /// kcal, proteinas, carboidratos e gorduras por 100 g.
  static const _taco = {
    ('arroz', 'cozido'): ('Arroz, tipo 1, cozido', 128.0, 2.5, 28.1, 0.2),
    ('arroz', 'frito'): ('Arroz, tipo 1, frito', 210.0, 3.0, 30.0, 8.0),
    ('feijao_carioca', 'cozido'): (
      'Feijão, carioca, cozido',
      76.0,
      4.8,
      13.6,
      0.5
    ),
  };

  final requests = <String>[];
  final meals = <Map<String, dynamic>>[];
  bool failSave = false;
  bool offline = false;

  /// Quando preenchido, o proximo calculo so responde ao completar.
  Completer<void>? holdNextCalculation;

  Future<http.Response> handle(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');
    if (offline) throw const SocketExceptionLike();

    final path = request.url.path;
    if (path.endsWith('/calculo-nutricional')) return _calculate(request);
    if (path.endsWith('/refeicoes/consumo-diario')) return _daily(request);
    if (path.endsWith('/refeicoes') && request.method == 'POST') {
      return _save(request);
    }
    return _json({'detail': 'Not Found'}, status: 404);
  }

  Future<http.Response> _calculate(http.Request request) async {
    final hold = holdNextCalculation;
    holdNextCalculation = null;
    if (hold != null) await hold.future;

    final itens = (jsonDecode(request.body)['itens'] as List)
        .cast<Map<String, dynamic>>();
    final out = <Map<String, Object>>[];
    for (final item in itens) {
      final taco = _taco[(item['classe'], item['metodo_preparo'])];
      if (taco == null) {
        return _json(
          {
            'detail': "Sem mapeamento TACO para a classe '${item['classe']}' "
                "com preparo '${item['metodo_preparo']}'",
          },
          status: 422,
        );
      }
      final grams = item['gramas'] as num;
      out.add({
        'classe': item['classe'],
        'metodo_preparo': item['metodo_preparo'],
        'alimento_taco_id': 1,
        'alimento_taco': taco.$1,
        'gramas': grams,
        'calorias_kcal': _round2(taco.$2 * grams / 100),
        'proteinas_g': _round2(taco.$3 * grams / 100),
        'carboidratos_g': _round2(taco.$4 * grams / 100),
        'gorduras_g': _round2(taco.$5 * grams / 100),
      });
    }
    return _json({'itens': out, 'totais': _sum(out)});
  }

  Map<String, double> _sum(List<Map<String, Object?>> items) => {
        for (final field in const [
          'calorias_kcal',
          'proteinas_g',
          'carboidratos_g',
          'gorduras_g',
        ])
          field: _round2(
            items.fold<num>(0, (total, i) => total + (i[field] as num)),
          ),
      };

  http.Response _save(http.Request request) {
    if (failSave) return _json({'detail': 'erro interno'}, status: 500);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final id = meals.length + 1;
    final itens = [
      for (final (index, item)
          in (body['itens'] as List).cast<Map<String, dynamic>>().indexed)
        {'id': id * 10 + index, ...item},
    ];
    final meal = {
      'id': id,
      'paciente_id': body['paciente_id'],
      'consumida_em': body['consumida_em'],
      'tipo': body['tipo'],
      'observacao': null,
      'criada_em': body['consumida_em'],
      'atualizada_em': body['consumida_em'],
      'itens': itens,
      'totais': _sum(itens),
    };
    meals.add(meal);
    return _json(meal, status: 201);
  }

  http.Response _daily(http.Request request) {
    final query = request.url.queryParameters;
    final patientId = int.parse(query['paciente_id']!);
    final ofDay = [
      for (final meal in meals)
        if (meal['paciente_id'] == patientId &&
            (meal['consumida_em'] as String).startsWith(query['data']!))
          meal,
    ];
    return _json({
      'paciente_id': patientId,
      'data': query['data'],
      'quantidade_refeicoes': ofDay.length,
      'totais':
          _sum([for (final m in ofDay) m['totais'] as Map<String, Object?>]),
      'refeicoes': ofDay,
    });
  }
}

/// O `http` falha com uma excecao qualquer quando nao ha rede.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}

/// Tela inicial falsa: abre a revisao com o resultado da IA e, ao registrar,
/// vai para o historico do dia.
Future<_Backend> _pumpApp(WidgetTester tester, {_Backend? backend}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = backend ?? _Backend();
  final client = ApiClient(
    baseUrl: 'http://api.test/api/v1',
    httpClient: MockClient(api.handle),
  );
  final items = (jsonDecode(_respostaIa)['itens'] as List)
      .cast<Map<String, dynamic>>()
      .map(DetectedItem.fromJson)
      .toList();

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final saved = await navigator.push<bool>(
                MaterialPageRoute(
                  builder: (_) => RecognitionReviewPage(
                    repository: RecognitionRepository(client),
                    patientId: 7,
                    photo: _photo,
                    items: items,
                    consumedAt: _consumedAt,
                  ),
                ),
              );
              if (saved != true) return;
              await navigator.push(
                MaterialPageRoute<void>(
                  builder: (_) => MealHistoryPage(
                    repository: MealRepository(client),
                    patientId: 7,
                    dailyGoalKcal: 2000,
                    today: _consumedAt.toLocal(),
                  ),
                ),
              );
            },
            child: const Text('Tirar foto'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Tirar foto'));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _editGrams(WidgetTester tester, String name, String grams) async {
  await tester.tap(find.byTooltip('Editar $name'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('edit-item-grams')), grams);
  await tester.pump();
  await tester.tap(find.byKey(const Key('edit-item-confirm')));
  await tester.pumpAndSettle();
}

Future<void> _register(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
  await tester.pumpAndSettle();
}

void main() {
  group('Fluxo foto -> confirmacao', () {
    testWidgets('revisa, corrige, registra e ve a refeicao no historico', (
      tester,
    ) async {
      final api = await _pumpApp(tester);

      // Revisao: o que a IA achou, com os valores da TACO
      expect(find.text('Revisar refeição'), findsOneWidget);
      expect(find.text('Alta · 93%'), findsOneWidget);
      expect(find.text('Baixa · 41%'), findsOneWidget);
      expect(find.textContaining('não tem certeza de 1 item'), findsOneWidget);
      expect(find.text('Cozido · 150 g · 192 kcal'), findsOneWidget);
      expect(find.text('Cozido · 100 g · 76 kcal'), findsOneWidget);
      expect(find.text('Total: 268 kcal'), findsOneWidget);

      // O paciente corrige a porcao de feijao: a API recalcula
      await _editGrams(tester, 'Feijao carioca', '80');
      expect(find.text('Cozido · 80 g · 60,8 kcal'), findsOneWidget);
      expect(find.text('Total: 252,8 kcal'), findsOneWidget);

      // Confirma: grava e cai no historico do dia
      await _register(tester);

      expect(api.meals, hasLength(1));
      final saved = api.meals.single;
      expect(saved['paciente_id'], 7);
      expect(saved['consumida_em'], '2026-10-20T12:00:00.000Z');
      expect(
        (saved['itens'] as List).map((i) => (i as Map)['nome_alimento']),
        ['Arroz, tipo 1, cozido', 'Feijão, carioca, cozido'],
      );

      expect(find.text('Histórico de refeições'), findsOneWidget);
      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
      expect(find.text('Feijão, carioca, cozido'), findsOneWidget);
      expect(find.text('150 g · 192 kcal'), findsOneWidget);
      expect(find.text('80 g · 60,8 kcal'), findsOneWidget);
      expect(find.text('252,8 kcal'), findsWidgets);

      expect(api.requests, [
        'POST /api/v1/calculo-nutricional',
        'POST /api/v1/calculo-nutricional',
        'POST /api/v1/refeicoes',
        'GET /api/v1/refeicoes/consumo-diario',
      ]);
    });

    testWidgets('item excluido na revisao nao e registrado', (tester) async {
      final api = await _pumpApp(tester);

      await tester.tap(find.byTooltip('Excluir Feijao carioca'));
      await tester.pumpAndSettle();
      expect(find.text('Total: 192 kcal'), findsOneWidget);
      expect(find.textContaining('não tem certeza'), findsNothing);

      await _register(tester);

      final itens = api.meals.single['itens'] as List;
      expect(itens, hasLength(1));
      expect((itens.single as Map)['calorias_kcal'], 192);
      expect(find.text('Feijão, carioca, cozido'), findsNothing);
    });

    testWidgets('trocar o preparo muda o alimento da TACO', (tester) async {
      final api = await _pumpApp(tester);

      await tester.tap(find.byTooltip('Editar Arroz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frito'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-item-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Frito · 150 g · 315 kcal'), findsOneWidget);
      await _register(tester);
      expect(
        ((api.meals.single['itens'] as List).first as Map)['nome_alimento'],
        'Arroz, tipo 1, frito',
      );
    });

    testWidgets('preparo sem mapeamento explica o motivo e nao registra', (
      tester,
    ) async {
      final api = await _pumpApp(tester);

      await tester.tap(find.byTooltip('Editar Feijao carioca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Frito'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-item-confirm')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível calcular: Sem mapeamento TACO para a classe '
          "'feijao_carioca' com preparo 'frito'",
        ),
        findsOneWidget,
      );
      expect(find.text('Total indisponível'), findsOneWidget);
      final register = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar'),
      );
      expect(register.onPressed, isNull);
      expect(api.meals, isEmpty);
    });
  });

  group('Revisao - falhas de rede e de registro', () {
    testWidgets('sem conexao no calculo permite tentar de novo', (
      tester,
    ) async {
      final api = await _pumpApp(tester, backend: _Backend()..offline = true);

      expect(
        find.text('Sem conexão com a API. Verifique sua internet.'),
        findsOneWidget,
      );

      api.offline = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Total: 268 kcal'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('falha ao registrar avisa e continua na revisao', (
      tester,
    ) async {
      final api = await _pumpApp(tester, backend: _Backend()..failSave = true);

      await _register(tester);

      expect(
        find.text('Não foi possível registrar a refeição.'),
        findsOneWidget,
      );
      expect(find.text('Revisar refeição'), findsOneWidget);
      expect(api.meals, isEmpty);

      // Na segunda tentativa a API responde e o fluxo segue
      api.failSave = false;
      await _register(tester);
      expect(api.meals, hasLength(1));
      expect(find.text('Histórico de refeições'), findsOneWidget);
    });

    testWidgets('registrar fica desabilitado enquanto calcula', (
      tester,
    ) async {
      final hold = Completer<void>();
      final backend = _Backend()..holdNextCalculation = hold;

      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final items = (jsonDecode(_respostaIa)['itens'] as List)
          .cast<Map<String, dynamic>>()
          .map(DetectedItem.fromJson)
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: RecognitionReviewPage(
            repository: RecognitionRepository(
              ApiClient(
                baseUrl: 'http://api.test/api/v1',
                httpClient: MockClient(backend.handle),
              ),
            ),
            patientId: 7,
            photo: _photo,
            items: items,
            consumedAt: _consumedAt,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Calculando...'), findsOneWidget);
      final register = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar'),
      );
      expect(register.onPressed, isNull);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('Total: 268 kcal'), findsOneWidget);
    });

    testWidgets('resposta de um calculo antigo e ignorada', (tester) async {
      final api = await _pumpApp(tester);

      // Primeira edicao fica presa na API; a segunda responde antes
      final slow = Completer<void>();
      api.holdNextCalculation = slow;
      await tester.tap(find.byTooltip('Editar Arroz'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-item-grams')), '50');
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-item-confirm')));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Excluir Feijao carioca'));
      await tester.pumpAndSettle();
      expect(find.text('Total: 64 kcal'), findsOneWidget);

      // A resposta atrasada (arroz 50 g + feijao) chega por ultimo
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.text('Total: 64 kcal'), findsOneWidget);
      expect(find.text('Total: 140 kcal'), findsNothing);
    });
  });
}
