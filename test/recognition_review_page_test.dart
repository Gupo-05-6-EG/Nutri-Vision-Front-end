import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/recognition/domain/detected_item.dart';
import 'package:nutri_vision/features/recognition/presentation/recognition_review_page.dart';

/// PNG 1x1 transparente.
final _photo = MemoryImage(
  Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    ),
  ),
);

const _arroz = DetectedItem(
  foodClass: 'arroz',
  confidence: 0.92,
  preparation: PreparationMethod.cooked,
  grams: 150,
  box: BoundingBox(left: 0.1, top: 0.1, width: 0.4, height: 0.4),
);

const _feijao = DetectedItem(
  foodClass: 'feijao_carioca',
  confidence: 0.35,
  preparation: PreparationMethod.cooked,
  grams: 100,
  box: BoundingBox(left: 0.5, top: 0.5, width: 0.4, height: 0.4),
);

http.Response _json(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

/// API falsa: 1 kcal por grama, e guarda cada corpo recebido.
class _FakeApi {
  final calculations = <List<dynamic>>[];
  final savedMeals = <Map<String, dynamic>>[];
  int? failCalculationWith;

  Future<http.Response> handle(http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.endsWith('/refeicoes')) {
      savedMeals.add(body);
      return _json({'id': 1}, status: 201);
    }

    final items = body['itens'] as List<dynamic>;
    calculations.add(items);
    if (failCalculationWith != null) {
      return _json(
        {'detail': "Sem mapeamento TACO para a classe 'arroz'"},
        status: failCalculationWith!,
      );
    }
    final out = [
      for (final item in items.cast<Map<String, dynamic>>())
        {
          'classe': item['classe'],
          'metodo_preparo': item['metodo_preparo'],
          'alimento_taco_id': 1,
          'alimento_taco': 'TACO ${item['classe']}',
          'gramas': item['gramas'],
          'calorias_kcal': item['gramas'],
          'proteinas_g': 1.234,
          'carboidratos_g': 2,
          'gorduras_g': 3,
        },
    ];
    final total = out.fold<num>(0, (sum, i) => sum + (i['gramas'] as num));
    return _json({
      'itens': out,
      'totais': {
        'calorias_kcal': total,
        'proteinas_g': 0,
        'carboidratos_g': 0,
        'gorduras_g': 0,
      },
    });
  }
}

Future<_FakeApi> _pumpPage(
  WidgetTester tester, {
  List<DetectedItem> items = const [_arroz, _feijao],
  _FakeApi? api,
  ValueChanged<Object?>? onPop,
}) async {
  // A foto ocupa a tela padrao de 800x600; a tela alta mostra todos os itens.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = api ?? _FakeApi();
  final repository = RecognitionRepository(
    ApiClient(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient(fake.handle),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(
                  builder: (context) => RecognitionReviewPage(
                    repository: repository,
                    patientId: 4,
                    photo: _photo,
                    items: items,
                    consumedAt: DateTime.utc(2026, 10, 20, 15, 30),
                  ),
                ),
              );
              onPop?.call(result);
            },
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('DetectedItem', () {
    test('le o resultado da IA', () {
      final item = DetectedItem.fromJson({
        'classe': 'feijao_carioca',
        'confianca': 0.42,
        'metodo_preparo': 'cozido',
        'gramas': 80,
        'caixa': {'x': 0.1, 'y': 0.2, 'largura': 0.3, 'altura': 0.4},
      });

      expect(item.displayName, 'Feijao carioca');
      expect(item.preparation, PreparationMethod.cooked);
      expect(item.level, ConfidenceLevel.low);
      expect(item.box!.height, 0.4);
    });

    test('faixas de confianca', () {
      expect(ConfidenceLevel.of(0.8), ConfidenceLevel.high);
      expect(ConfidenceLevel.of(0.79), ConfidenceLevel.medium);
      expect(ConfidenceLevel.of(0.5), ConfidenceLevel.medium);
      expect(ConfidenceLevel.of(0.49), ConfidenceLevel.low);
    });

    test('envia as gramas com no maximo duas casas', () {
      final item = _arroz.copyWith(grams: 10.456);
      expect(item.toCalculationJson(), {
        'classe': 'arroz',
        'metodo_preparo': 'cozido',
        'gramas': 10.46,
      });
    });
  });

  group('RecognitionReviewPage', () {
    testWidgets('mostra tags, badges, aviso de baixa confianca e total', (
      tester,
    ) async {
      final api = await _pumpPage(tester);

      expect(api.calculations, hasLength(1));
      expect(find.text('Arroz 92%'), findsOneWidget);
      expect(find.text('Alta · 92%'), findsOneWidget);
      expect(find.text('Baixa · 35%'), findsOneWidget);
      expect(find.textContaining('não tem certeza de 1 item'), findsOneWidget);
      expect(find.text('Cozido · 150 g · 150 kcal'), findsOneWidget);
      expect(find.text('Total: 250 kcal'), findsOneWidget);
    });

    testWidgets('editar gramas e preparo recalcula', (tester) async {
      final api = await _pumpPage(tester);

      await tester.tap(find.byTooltip('Editar Arroz'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-item-grams')), '200,5');
      await tester.tap(find.text('Frito'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-item-confirm')));
      await tester.pumpAndSettle();

      expect(api.calculations.last.first, {
        'classe': 'arroz',
        'metodo_preparo': 'frito',
        'gramas': 200.5,
      });
      expect(find.text('Frito · 200,5 g · 200,5 kcal'), findsOneWidget);
      expect(find.text('Total: 300,5 kcal'), findsOneWidget);
    });

    testWidgets('gramatura invalida nao pode ser salva', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.byTooltip('Editar Arroz'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-item-grams')), '0');
      await tester.pump();

      final save = tester.widget<FilledButton>(
        find.byKey(const Key('edit-item-confirm')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('excluir remove o item e desfazer devolve', (tester) async {
      final api = await _pumpPage(tester);

      await tester.tap(find.byTooltip('Excluir Feijao carioca'));
      await tester.pumpAndSettle();

      expect(find.text('Baixa · 35%'), findsNothing);
      expect(api.calculations.last, hasLength(1));
      expect(find.text('Total: 150 kcal'), findsOneWidget);

      await tester.tap(find.text('Desfazer'));
      await tester.pumpAndSettle();

      expect(find.text('Baixa · 35%'), findsOneWidget);
      expect(find.text('Total: 250 kcal'), findsOneWidget);
    });

    testWidgets('sem itens nao deixa registrar', (tester) async {
      await _pumpPage(tester, items: const [_arroz]);

      await tester.tap(find.byTooltip('Excluir Arroz'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum alimento na refeição.'), findsOneWidget);
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('mostra o motivo quando falta mapeamento na TACO', (
      tester,
    ) async {
      await _pumpPage(tester, api: _FakeApi()..failCalculationWith = 422);

      expect(
        find.text(
          "Não foi possível calcular: Sem mapeamento TACO para a classe 'arroz'",
        ),
        findsOneWidget,
      );
      expect(find.text('Total indisponível'), findsOneWidget);
    });

    testWidgets('registrar envia a refeicao revisada e fecha', (tester) async {
      Object? popped;
      final api = await _pumpPage(tester, onPop: (value) => popped = value);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar'));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      final meal = api.savedMeals.single;
      expect(meal['paciente_id'], 4);
      expect(meal['consumida_em'], '2026-10-20T15:30:00.000Z');
      expect(meal.containsKey('tipo'), isFalse);
      expect((meal['itens'] as List).first, {
        'nome_alimento': 'TACO arroz',
        'quantidade_g': 150,
        'calorias_kcal': 150,
        'proteinas_g': 1.23,
        'carboidratos_g': 2,
        'gorduras_g': 3,
      });
    });
  });
}
