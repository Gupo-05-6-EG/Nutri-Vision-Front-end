// Teste de integracao do fluxo foto -> analise da IA -> confirmacao.
//
// Liga as pecas reais do app (ApiClient, RecognitionRepository,
// FoodRepository, MealRepository, PhotoAnalysisPage, RecognitionReviewPage e
// MealHistoryPage) a uma API falsa com estado, que analisa a foto como o
// back-end (`/analises`, com fila), calcula pela TACO (valor por 100 g x
// gramas / 100) e devolve no historico o que foi registrado. So o HTTP e a
// camera sao simulados: o que o app envia e le e exatamente o contrato da API.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/foods/data/food_repository.dart';
import 'package:nutri_vision/features/meals/data/meal_repository.dart';
import 'package:nutri_vision/features/meals/presentation/meal_history_page.dart';
import 'package:nutri_vision/features/recognition/data/photo_picker.dart';
import 'package:nutri_vision/features/recognition/data/recognition_repository.dart';
import 'package:nutri_vision/features/recognition/domain/detected_item.dart';
import 'package:nutri_vision/features/recognition/presentation/photo_analysis_page.dart';

/// PNG 1x1 transparente, no lugar da foto da camera.
final _photoBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

const _analysisId = '8c839452-3b71-4c47-9e97-34f14ac7d5ea';

/// Itens de `GET /analises/{id}` para um prato de arroz com feijao.
const _pratoItens = [
  {
    'alimento': 'Arroz, tipo 1, cozido',
    'alimento_taco_id': 1,
    'gramas': 150,
    'confianca': 0.93,
  },
  {
    'alimento': 'Feijão, carioca, cozido',
    'alimento_taco_id': 2,
    'gramas': 100,
    'confianca': 0.41,
  },
];

Map<String, Object?> _analysis(
  String status, {
  String? reason,
  List<String>? issues,
  List<Map<String, Object?>>? items,
}) =>
    {
      'id': _analysisId,
      'status': status,
      'motivo': reason,
      'problemas': issues,
      'itens': items,
    };

/// Meio-dia UTC: a data local e a mesma em qualquer fuso de -11h a +11h.
final _consumedAt = DateTime.utc(2026, 10, 20, 12);

http.Response _json(Object? body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

double _round2(num value) => (value * 100).round() / 100;

/// API falsa com estado: analisa a foto, calcula pela TACO e guarda as
/// refeicoes.
class _Backend {
  /// id -> nome, kcal, proteinas, carboidratos e gorduras por 100 g.
  static const _taco = {
    1: ('Arroz, tipo 1, cozido', 128.0, 2.5, 28.1, 0.2),
    2: ('Feijão, carioca, cozido', 76.0, 4.8, 13.6, 0.5),
    3: ('Batata, inglesa, cozida', 52.0, 1.2, 11.9, 0.0),
  };

  final requests = <String>[];
  final meals = <Map<String, dynamic>>[];
  bool failSave = false;
  bool offline = false;

  /// Sem rede so no calculo (a analise da foto responde).
  bool offlineCalculation = false;

  /// Resposta de `POST /analises` (status 202).
  Map<String, Object?> uploadResponse = _analysis('QUEUED');

  /// Status HTTP de `POST /analises` (ex.: 503 com a IA fora do ar).
  int uploadStatus = 202;

  /// Respostas de `GET /analises/{id}`, em ordem; a ultima se repete.
  List<Map<String, Object?>> analyses = [
    _analysis('PROCESSING'),
    _analysis('DONE', items: _pratoItens),
  ];

  /// Ultima foto recebida (corpo multipart).
  http.Request? upload;

  /// Quando preenchido, o proximo calculo so responde ao completar.
  Completer<void>? holdNextCalculation;

  Future<http.Response> handle(http.Request request) async {
    requests.add('${request.method} ${request.url.path}');
    if (offline) throw const SocketExceptionLike();

    final path = request.url.path;
    if (path.endsWith('/analises') && request.method == 'POST') {
      upload = request;
      return _json(
        uploadStatus == 202 ? uploadResponse : {'detail': 'indisponivel'},
        status: uploadStatus,
      );
    }
    if (path.endsWith('/analises/$_analysisId')) {
      final next = analyses.length > 1 ? analyses.removeAt(0) : analyses.first;
      return _json(next);
    }
    if (path.endsWith('/alimentos-taco')) return _search();
    if (path.endsWith('/calculo-nutricional')) {
      if (offlineCalculation) throw const SocketExceptionLike();
      return _calculate(request);
    }
    if (path.endsWith('/refeicoes/consumo-diario')) return _daily(request);
    if (path.endsWith('/refeicoes') && request.method == 'POST') {
      return _save(request);
    }
    return _json({'detail': 'Not Found'}, status: 404);
  }

  http.Response _search() => _json([
        for (final MapEntry(key: id, value: taco) in _taco.entries)
          {
            'id': id,
            'nome': taco.$1,
            'categoria': 'TACO',
            'kcal_100g': taco.$2,
            'prot_100g': taco.$3,
            'carbs_100g': taco.$4,
            'gord_100g': taco.$5,
          },
      ]);

  Future<http.Response> _calculate(http.Request request) async {
    final hold = holdNextCalculation;
    holdNextCalculation = null;
    if (hold != null) await hold.future;

    final itens = (jsonDecode(request.body)['itens'] as List)
        .cast<Map<String, dynamic>>();
    final out = <Map<String, Object?>>[];
    for (final item in itens) {
      final id = item['alimento_taco_id'] as int;
      final taco = _taco[id];
      if (taco == null) {
        return _json(
          {'detail': 'Alimento TACO de id $id nao encontrado'},
          status: 404,
        );
      }
      final grams = item['gramas'] as num;
      out.add({
        'classe': null,
        'metodo_preparo': null,
        'alimento_taco_id': id,
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

/// Camera falsa: devolve a foto, nada (paciente desistiu) ou falha.
class _Camera {
  final sources = <PhotoSource>[];
  bool cancel = false;
  bool fail = false;

  Future<PickedPhoto?> pick(PhotoSource source) async {
    sources.add(source);
    if (fail) throw Exception('camera indisponivel');
    if (cancel) return null;
    return PickedPhoto(bytes: _photoBytes, filename: 'prato.jpg');
  }
}

/// Tela inicial falsa: abre o registro por foto e, ao registrar, vai para o
/// historico do dia.
Future<_Backend> _pumpApp(
  WidgetTester tester, {
  _Backend? backend,
  _Camera? camera,
  Duration analysisTimeout = const Duration(minutes: 2),
}) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final api = backend ?? _Backend();
  final client = ApiClient(
    baseUrl: 'http://api.test/api/v1',
    httpClient: MockClient(api.handle),
  );
  final cam = camera ?? _Camera();

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final saved = await navigator.push<bool>(
                MaterialPageRoute(
                  builder: (_) => PhotoAnalysisPage(
                    repository: RecognitionRepository(
                      client,
                      pollInterval: Duration.zero,
                      analysisTimeout: analysisTimeout,
                    ),
                    patientId: 7,
                    foods: FoodRepository(client),
                    pickPhoto: cam.pick,
                    openCamera: (_, pick) => pick(PhotoSource.camera),
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
            child: const Text('Registrar por foto'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Registrar por foto'));
  await tester.pumpAndSettle();
  return api;
}

/// Tira a foto e espera a analise (e a revisao, se a IA identificou o prato).
Future<void> _takePhoto(WidgetTester tester) async {
  await tester.tap(find.text('Tirar foto'));
  await tester.pumpAndSettle();
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
  group('Fluxo foto -> analise -> confirmacao', () {
    testWidgets('fotografa, revisa, corrige, registra e ve no historico', (
      tester,
    ) async {
      final api = await _pumpApp(tester);

      expect(find.text('Refeição por foto'), findsOneWidget);
      await _takePhoto(tester);

      // A foto foi enviada como multipart, no campo `file`
      final upload = api.upload!;
      expect(upload.headers['content-type'], startsWith('multipart/form-data'));
      final body = latin1.decode(upload.bodyBytes);
      expect(body, contains('name="file"; filename="prato.jpg"'));
      expect(body, contains('content-type: image/jpeg'));

      // Revisao: o que a IA achou, com os valores da TACO
      expect(find.text('Revisar refeição'), findsOneWidget);
      expect(find.text('Alta · 93%'), findsOneWidget);
      expect(find.text('Baixa · 41%'), findsOneWidget);
      expect(find.textContaining('não tem certeza de 1 item'), findsOneWidget);
      expect(find.text('150 g · 192 kcal'), findsOneWidget);
      expect(find.text('100 g · 76 kcal'), findsOneWidget);
      expect(find.text('Total: 268 kcal'), findsOneWidget);

      // O paciente corrige a porcao de feijao: a API recalcula
      await _editGrams(tester, 'Feijão, carioca, cozido', '80');
      expect(find.text('80 g · 60,8 kcal'), findsOneWidget);
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
        'POST /api/v1/analises',
        'GET /api/v1/analises/$_analysisId',
        'GET /api/v1/analises/$_analysisId',
        'POST /api/v1/calculo-nutricional',
        'POST /api/v1/calculo-nutricional',
        'POST /api/v1/refeicoes',
        'GET /api/v1/refeicoes/consumo-diario',
      ]);
    });

    testWidgets('escolher da galeria tambem analisa', (tester) async {
      final camera = _Camera();
      await _pumpApp(tester, camera: camera);

      await tester.tap(find.text('Escolher da galeria'));
      await tester.pumpAndSettle();

      expect(camera.sources, [PhotoSource.gallery]);
      expect(find.text('Revisar refeição'), findsOneWidget);
    });

    testWidgets('item excluido na revisao nao e registrado', (tester) async {
      final api = await _pumpApp(tester);
      await _takePhoto(tester);

      await tester.tap(find.byTooltip('Excluir Feijão, carioca, cozido'));
      await tester.pumpAndSettle();
      expect(find.text('Total: 192 kcal'), findsOneWidget);
      expect(find.textContaining('não tem certeza'), findsNothing);

      await _register(tester);

      final itens = api.meals.single['itens'] as List;
      expect(itens, hasLength(1));
      expect((itens.single as Map)['calorias_kcal'], 192);
      expect(find.text('Feijão, carioca, cozido'), findsNothing);
    });

    testWidgets('alimento fora da TACO e trocado por um da tabela', (
      tester,
    ) async {
      final api = _Backend()
        ..analyses = [
          _analysis(
            'DONE',
            items: [
              _pratoItens.first,
              {
                'alimento': 'batata',
                'alimento_taco_id': null,
                'gramas': 90,
                'confianca': 0.6,
              },
            ],
          ),
        ];
      await _pumpApp(tester, backend: api);
      await _takePhoto(tester);

      expect(find.text('Fora da TACO · 90 g'), findsOneWidget);
      final register = find.widgetWithText(FilledButton, 'Registrar');
      expect(tester.widget<FilledButton>(register).onPressed, isNull);

      // Troca pela batata cozida da TACO, com 100 g
      await tester.tap(find.byTooltip('Trocar batata'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-item-replace')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'batata');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batata, inglesa, cozida'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('portion-grams')), '100');
      await tester.pump();
      await tester.tap(find.byKey(const Key('portion-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('100 g · 52 kcal'), findsOneWidget);
      expect(find.text('Total: 244 kcal'), findsOneWidget);
      await _register(tester);

      expect(
        (api.meals.single['itens'] as List).map(
          (i) => (i as Map)['nome_alimento'],
        ),
        ['Arroz, tipo 1, cozido', 'Batata, inglesa, cozida'],
      );
    });
  });

  group('Analise da foto - quando a IA nao identifica o prato', () {
    testWidgets('foto ruim explica o problema e permite tirar outra', (
      tester,
    ) async {
      final api = _Backend()
        ..uploadResponse = _analysis(
          'NOT_ESTIMATED',
          reason: 'bad_photo',
          issues: ['blurry', 'too_dark'],
          items: [],
        );
      final camera = _Camera();
      await _pumpApp(tester, backend: api, camera: camera);
      await _takePhoto(tester);

      expect(
        find.text(
          'A foto está tremida e está escura. Tire outra com o prato bem '
          'iluminado e a câmera firme.',
        ),
        findsOneWidget,
      );
      // Foto ruim volta na hora: nem consulta o andamento
      expect(api.requests, ['POST /api/v1/analises']);
      expect(find.text('Tentar de novo com a mesma foto'), findsNothing);

      // Tira outra foto, agora boa
      api.uploadResponse = _analysis('QUEUED');
      await _takePhoto(tester);
      expect(camera.sources, hasLength(2));
      expect(find.text('Revisar refeição'), findsOneWidget);
    });

    testWidgets('nada encontrado na foto', (tester) async {
      final api = _Backend()
        ..analyses = [
          _analysis('NOT_ESTIMATED', reason: 'nothing_detected', items: []),
        ];
      await _pumpApp(tester, backend: api);
      await _takePhoto(tester);

      expect(
        find.text(
          'Não encontramos alimentos na foto. Enquadre o prato e tente de novo.',
        ),
        findsOneWidget,
      );
      expect(find.text('Revisar os alimentos mesmo assim'), findsNothing);
    });

    testWidgets('baixa confianca deixa revisar os itens mesmo assim', (
      tester,
    ) async {
      final api = _Backend()
        ..analyses = [
          _analysis(
            'NOT_ESTIMATED',
            reason: 'low_confidence',
            items: [_pratoItens.last],
          ),
        ];
      await _pumpApp(tester, backend: api);
      await _takePhoto(tester);

      expect(
        find.text(
          'A IA não conseguiu identificar os alimentos com segurança.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Revisar os alimentos mesmo assim'));
      await tester.pumpAndSettle();

      expect(find.text('Revisar refeição'), findsOneWidget);
      expect(find.text('Feijão, carioca, cozido'), findsOneWidget);

      // Voltar da revisao sem registrar permite tirar outra foto
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Tirar foto'), findsOneWidget);
      expect(api.meals, isEmpty);
    });

    testWidgets('falha do modelo pede para tentar de novo', (tester) async {
      final api = _Backend()
        ..analyses = [
          {'id': _analysisId, 'status': 'FAILED', 'erro': 'Gemini 503'},
        ];
      await _pumpApp(tester, backend: api);
      await _takePhoto(tester);

      expect(
        find.text('Não foi possível analisar a foto agora. Tente novamente.'),
        findsOneWidget,
      );
    });
  });

  group('Analise da foto - falhas de rede e de servico', () {
    testWidgets('servico de IA fora do ar permite repetir a mesma foto', (
      tester,
    ) async {
      final api = _Backend()..uploadStatus = 503;
      final camera = _Camera();
      await _pumpApp(tester, backend: api, camera: camera);
      await _takePhoto(tester);

      expect(
        find.text(
          'O serviço de análise está indisponível. Tente de novo em instantes.',
        ),
        findsOneWidget,
      );

      api.uploadStatus = 202;
      await tester.tap(find.text('Tentar de novo com a mesma foto'));
      await tester.pumpAndSettle();

      expect(camera.sources, hasLength(1));
      expect(find.text('Revisar refeição'), findsOneWidget);
    });

    testWidgets('sem conexao avisa', (tester) async {
      await _pumpApp(tester, backend: _Backend()..offline = true);
      await _takePhoto(tester);

      expect(
        find.text('Sem conexão com a API. Verifique sua internet.'),
        findsOneWidget,
      );
    });

    testWidgets('analise que nao termina desiste no limite de espera', (
      tester,
    ) async {
      final api = _Backend()..analyses = [_analysis('QUEUED')];
      await _pumpApp(tester, backend: api, analysisTimeout: Duration.zero);
      await _takePhoto(tester);

      expect(
        find.textContaining('A análise está demorando mais que o normal'),
        findsOneWidget,
      );
    });

    testWidgets('camera indisponivel avisa', (tester) async {
      final api = _Backend();
      await _pumpApp(tester, backend: api, camera: _Camera()..fail = true);
      await _takePhoto(tester);

      expect(
        find.text(
          'Não foi possível abrir a câmera. Verifique a permissão do app.',
        ),
        findsOneWidget,
      );
      expect(api.requests, isEmpty);
    });

    testWidgets('desistir da camera nao envia nada', (tester) async {
      final api = _Backend();
      await _pumpApp(tester, backend: api, camera: _Camera()..cancel = true);
      await _takePhoto(tester);

      expect(find.text('Tirar foto'), findsOneWidget);
      expect(api.requests, isEmpty);
    });
  });

  group('Revisao - falhas de rede e de registro', () {
    testWidgets('sem conexao no calculo permite tentar de novo', (
      tester,
    ) async {
      final api = await _pumpApp(
        tester,
        backend: _Backend()..offlineCalculation = true,
      );
      await _takePhoto(tester);

      expect(find.text('Revisar refeição'), findsOneWidget);
      expect(
        find.text('Sem conexão com a API. Verifique sua internet.'),
        findsOneWidget,
      );

      api.offlineCalculation = false;
      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Total: 268 kcal'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsNothing);
    });

    testWidgets('falha ao registrar avisa e continua na revisao', (
      tester,
    ) async {
      final api = await _pumpApp(tester, backend: _Backend()..failSave = true);
      await _takePhoto(tester);

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
      final api = await _pumpApp(
        tester,
        backend: _Backend()..holdNextCalculation = hold,
      );
      await tester.tap(find.text('Tirar foto'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Calculando...'), findsOneWidget);
      final register = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar'),
      );
      expect(register.onPressed, isNull);

      hold.complete();
      await tester.pumpAndSettle();
      expect(find.text('Total: 268 kcal'), findsOneWidget);
      expect(api.meals, isEmpty);
    });

    testWidgets('resposta de um calculo antigo e ignorada', (tester) async {
      final api = await _pumpApp(tester);
      await _takePhoto(tester);

      // Primeira edicao fica presa na API; a segunda responde antes
      final slow = Completer<void>();
      api.holdNextCalculation = slow;
      await tester.tap(find.byTooltip('Editar Arroz, tipo 1, cozido'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('edit-item-grams')), '50');
      await tester.pump();
      await tester.tap(find.byKey(const Key('edit-item-confirm')));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byTooltip('Excluir Feijão, carioca, cozido'));
      await tester.pumpAndSettle();
      expect(find.text('Total: 64 kcal'), findsOneWidget);

      // A resposta atrasada (arroz 50 g + feijao) chega por ultimo
      slow.complete();
      await tester.pumpAndSettle();
      expect(find.text('Total: 64 kcal'), findsOneWidget);
      expect(find.text('Total: 140 kcal'), findsNothing);
    });
  });

  group('Dominio da analise', () {
    test('tipo da foto pela extensao', () {
      expect(imageContentType('prato.JPG'), 'image/jpeg');
      expect(imageContentType('prato.png'), 'image/png');
      expect(imageContentType('prato.webp'), 'image/webp');
      expect(imageContentType('IMG_1.HEIC'), 'image/heic');
      expect(imageContentType('sem_extensao'), 'image/jpeg');
    });

    test('le o andamento e o resultado de GET /analises/{id}', () {
      final pending = PhotoAnalysis.fromJson(_analysis('QUEUED'));
      expect(pending.status.isPending, isTrue);
      expect(pending.items, isEmpty);

      final done = PhotoAnalysis.fromJson({
        ..._analysis('DONE', items: _pratoItens),
        'versao_modelo': 'gemini',
        'totais': {'calorias_kcal': 268},
      });
      expect(done.status, AnalysisStatus.done);
      expect(done.items.map((i) => i.tacoId), [1, 2]);
    });

    test('mensagens de foto ruim', () {
      String message(List<String> issues) => PhotoAnalysis(
            id: 'x',
            status: AnalysisStatus.notEstimated,
            reason: 'bad_photo',
            issues: issues,
          ).problemMessage;

      expect(message(['too_bright']), startsWith('A foto está clara demais.'));
      expect(message([]), startsWith('A foto não ficou boa.'));
    });
  });
}
