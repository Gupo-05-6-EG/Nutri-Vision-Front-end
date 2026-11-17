import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/foods/data/food_repository.dart';
import 'package:nutri_vision/features/meals/domain/meal_type.dart';
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
  name: 'Arroz, tipo 1, cozido',
  tacoId: 1,
  confidence: 0.92,
  grams: 150,
);

const _feijao = DetectedItem(
  name: 'Feijão, carioca, cozido',
  tacoId: 2,
  confidence: 0.35,
  grams: 100,
);

/// A IA reconheceu, mas nao esta na nossa TACO.
const _farofa = DetectedItem(name: 'farofa', confidence: 0.7, grams: 30);

/// Nossa TACO falsa: id -> nome.
const _taco = {
  1: 'Arroz, tipo 1, cozido',
  2: 'Feijão, carioca, cozido',
  3: 'Farofa de mandioca',
};

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
    if (request.url.path.endsWith('/alimentos-taco')) {
      return _json([
        {
          'id': 3,
          'nome': _taco[3],
          'categoria': 'Cereais',
          'kcal_100g': 406,
          'carbs_100g': 80,
          'prot_100g': 2,
          'gord_100g': 9,
        },
      ]);
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (request.url.path.endsWith('/refeicoes')) {
      savedMeals.add(body);
      return _json({'id': 1}, status: 201);
    }

    final items = body['itens'] as List<dynamic>;
    calculations.add(items);
    if (failCalculationWith != null) {
      return _json(
        {'detail': 'Alimento TACO de id 1 nao encontrado'},
        status: failCalculationWith!,
      );
    }
    final out = [
      for (final item in items.cast<Map<String, dynamic>>())
        {
          'classe': null,
          'metodo_preparo': null,
          'alimento_taco_id': item['alimento_taco_id'],
          'alimento_taco': _taco[item['alimento_taco_id']],
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
  bool withFoodSearch = true,
}) async {
  // A foto ocupa a tela padrao de 800x600; a tela alta mostra todos os itens.
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = api ?? _FakeApi();
  final client = ApiClient(
    baseUrl: 'http://api.test/api/v1',
    httpClient: MockClient(fake.handle),
  );
  final repository = RecognitionRepository(client);
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
                    foods: withFoodSearch ? FoodRepository(client) : null,
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

/// Na folha de edicao: "Trocar alimento" -> busca "farofa" -> 50 g.
Future<void> _replaceWithFarofa(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('edit-item-replace')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'farofa');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Farofa de mandioca'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('portion-grams')), '50');
  await tester.pump();
  await tester.tap(find.byKey(const Key('portion-confirm')));
  await tester.pumpAndSettle();
}

Finder _registerButton() => find.widgetWithText(FilledButton, 'Registrar');

void main() {
  group('DetectedItem', () {
    test('le o item de GET /analises/{id}', () {
      final item = DetectedItem.fromJson({
        'alimento': 'Feijão, carioca, cozido',
        'alimento_taco_id': 2,
        'gramas': 80,
        'confianca': 0.42,
        'calorias_kcal': 60.8,
      });

      expect(item.displayName, 'Feijão, carioca, cozido');
      expect(item.tacoId, 2);
      expect(item.isInTaco, isTrue);
      expect(item.grams, 80);
      expect(item.aiGrams, 80);
      expect(item.level, ConfidenceLevel.low);
    });

    test('item fora da TACO vem sem id', () {
      final item = DetectedItem.fromJson({
        'alimento': 'farofa',
        'alimento_taco_id': null,
        'gramas': 30,
        'confianca': 0.7,
      });

      expect(item.isInTaco, isFalse);
    });

    test('faixas de confianca', () {
      expect(ConfidenceLevel.of(0.8), ConfidenceLevel.high);
      expect(ConfidenceLevel.of(0.79), ConfidenceLevel.medium);
      expect(ConfidenceLevel.of(0.5), ConfidenceLevel.medium);
      expect(ConfidenceLevel.of(0.49), ConfidenceLevel.low);
    });

    test('calculo vai pelo id da TACO, com no maximo duas casas', () {
      final item = _arroz.copyWith(grams: 10.456);
      expect(item.toCalculationJson(), {
        'alimento_taco_id': 1,
        'gramas': 10.46,
      });
      // A estimativa original da IA continua como referencia.
      expect(item.aiGrams, 150);
    });

    test('trocar o alimento mantem a confianca e a estimativa da IA', () {
      final item = _farofa.copyWith(tacoId: 3, name: 'Farofa', grams: 40);
      expect(item.isInTaco, isTrue);
      expect(item.confidence, 0.7);
      expect(item.aiGrams, 30);
    });
  });

  group('RecognitionReviewPage', () {
    testWidgets('mostra badges, aviso de baixa confianca e total', (
      tester,
    ) async {
      final api = await _pumpPage(tester);

      expect(api.calculations, hasLength(1));
      expect(api.calculations.single, [
        {'alimento_taco_id': 1, 'gramas': 150},
        {'alimento_taco_id': 2, 'gramas': 100},
      ]);
      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
      expect(find.text('Alta · 92%'), findsOneWidget);
      expect(find.text('Baixa · 35%'), findsOneWidget);
      expect(find.textContaining('não tem certeza de 1 item'), findsOneWidget);
      expect(find.text('150 g · 150 kcal'), findsOneWidget);
      expect(find.text('Total: 250 kcal'), findsOneWidget);
      expect(find.bySemanticsLabel('Foto da refeição'), findsOneWidget);
    });

    testWidgets('editar gramas recalcula pelo id da TACO', (tester) async {
      final api = await _pumpPage(tester);

      await tester.tap(find.byTooltip('Editar Arroz, tipo 1, cozido'));
      await tester.pumpAndSettle();
      expect(find.text('Estimativa da IA: 150 g'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('edit-item-grams')), '200,5');
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-item-confirm')));
      await tester.pumpAndSettle();

      expect(api.calculations.last.first, {
        'alimento_taco_id': 1,
        'gramas': 200.5,
      });
      expect(find.text('200,5 g · 200,5 kcal'), findsOneWidget);
      expect(find.text('Total: 300,5 kcal'), findsOneWidget);
    });

    testWidgets('gramatura invalida nao pode ser salva', (tester) async {
      await _pumpPage(tester);

      await tester.tap(find.byTooltip('Editar Arroz, tipo 1, cozido'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-item-grams')), '0');
      await tester.pump();

      final save = tester.widget<FilledButton>(
        find.byKey(const Key('edit-item-confirm')),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets('trocar o alimento busca na TACO e recalcula', (tester) async {
      final api = await _pumpPage(tester);

      await tester.tap(find.byTooltip('Editar Feijão, carioca, cozido'));
      await tester.pumpAndSettle();
      await _replaceWithFarofa(tester);

      expect(find.text('Farofa de mandioca'), findsOneWidget);
      expect(find.text('Feijão, carioca, cozido'), findsNothing);
      expect(api.calculations.last.last, {
        'alimento_taco_id': 3,
        'gramas': 50,
      });
      expect(find.text('Total: 200 kcal'), findsOneWidget);
    });

    testWidgets('sem a busca da TACO nao oferece trocar o alimento', (
      tester,
    ) async {
      await _pumpPage(tester, withFoodSearch: false);

      await tester.tap(find.byTooltip('Editar Arroz, tipo 1, cozido'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('edit-item-replace')), findsNothing);
    });

    testWidgets('alimento fora da TACO bloqueia o registro ate ser trocado', (
      tester,
    ) async {
      final api = await _pumpPage(tester, items: const [_arroz, _farofa]);

      // So o arroz vai para o calculo; a farofa fica sinalizada
      expect(api.calculations.single, [
        {'alimento_taco_id': 1, 'gramas': 150},
      ]);
      expect(find.text('Fora da TACO · 30 g'), findsOneWidget);
      expect(
        find.textContaining('1 alimento não está na tabela TACO'),
        findsOneWidget,
      );
      expect(find.text('Total: 150 kcal'), findsOneWidget);
      expect(tester.widget<FilledButton>(_registerButton()).onPressed, isNull);

      // A folha so oferece trocar (nao ha gramas para editar)
      await tester.tap(find.byTooltip('Trocar farofa'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('edit-item-grams')), findsNothing);
      expect(
        find.textContaining('Este alimento não está na tabela TACO'),
        findsOneWidget,
      );
      await _replaceWithFarofa(tester);

      expect(find.text('Fora da TACO · 30 g'), findsNothing);
      expect(find.text('Total: 200 kcal'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_registerButton()).onPressed,
        isNotNull,
      );
    });

    testWidgets('excluir o alimento fora da TACO libera o registro', (
      tester,
    ) async {
      final api = await _pumpPage(tester, items: const [_arroz, _farofa]);

      await tester.tap(find.byTooltip('Excluir farofa'));
      await tester.pumpAndSettle();
      await tester.tap(_registerButton());
      await tester.pumpAndSettle();

      final itens = api.savedMeals.single['itens'] as List;
      expect(itens.map((i) => (i as Map)['nome_alimento']), [
        'Arroz, tipo 1, cozido',
      ]);
    });

    testWidgets('so alimentos fora da TACO: nada a calcular', (tester) async {
      final api = await _pumpPage(tester, items: const [_farofa]);

      expect(api.calculations, isEmpty);
      expect(find.text('Total: 0 kcal'), findsOneWidget);
      expect(tester.widget<FilledButton>(_registerButton()).onPressed, isNull);
    });

    testWidgets('excluir remove o item e desfazer devolve', (tester) async {
      final api = await _pumpPage(tester);

      await tester.tap(find.byTooltip('Excluir Feijão, carioca, cozido'));
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

      await tester.tap(find.byTooltip('Excluir Arroz, tipo 1, cozido'));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum alimento na refeição.'), findsOneWidget);
      expect(tester.widget<FilledButton>(_registerButton()).onPressed, isNull);
    });

    testWidgets('registrar fecha o aviso de desfazer de um item excluido', (
      tester,
    ) async {
      await _pumpPage(tester);

      await tester.tap(find.byTooltip('Excluir Feijão, carioca, cozido'));
      await tester.pumpAndSettle();
      expect(find.text('Desfazer'), findsOneWidget);

      await tester.tap(_registerButton());
      await tester.pumpAndSettle();

      expect(find.text('abrir'), findsOneWidget);
      expect(find.text('Desfazer'), findsNothing);
    });

    testWidgets('mostra o motivo quando o calculo falha', (tester) async {
      await _pumpPage(tester, api: _FakeApi()..failCalculationWith = 404);

      expect(
        find.text(
          'Não foi possível calcular: Alimento TACO de id 1 nao encontrado',
        ),
        findsOneWidget,
      );
      expect(find.text('Total indisponível'), findsOneWidget);
    });

    testWidgets('registrar envia a refeicao revisada e fecha', (tester) async {
      Object? popped;
      final api = await _pumpPage(tester, onPop: (value) => popped = value);

      await tester.tap(_registerButton());
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      final meal = api.savedMeals.single;
      expect(meal['paciente_id'], 4);
      expect(meal['consumida_em'], '2026-10-20T15:30:00.000Z');
      // Sugerido pelo horario local de consumedAt (depende do fuso da maquina).
      final suggested = MealType.suggestedAt(
        DateTime.utc(2026, 10, 20, 15, 30).toLocal(),
      );
      expect(meal['tipo'], suggested.apiValue);
      expect((meal['itens'] as List).first, {
        'nome_alimento': 'Arroz, tipo 1, cozido',
        'quantidade_g': 150,
        'calorias_kcal': 150,
        'proteinas_g': 1.23,
        'carboidratos_g': 2,
        'gorduras_g': 3,
      });
    });

    testWidgets('registra com o tipo escolhido no seletor', (tester) async {
      final api = await _pumpPage(tester);

      await tester.tap(find.byType(DropdownButtonFormField<MealType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jantar').last);
      await tester.pumpAndSettle();
      await tester.tap(_registerButton());
      await tester.pumpAndSettle();

      expect(api.savedMeals.single['tipo'], 'jantar');
    });
  });
}
