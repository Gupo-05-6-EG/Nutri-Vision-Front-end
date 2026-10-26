import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/foods/data/food_repository.dart';
import 'package:nutri_vision/features/foods/domain/food.dart';
import 'package:nutri_vision/features/foods/presentation/food_search_page.dart';
import 'package:nutri_vision/features/foods/presentation/portion_sheet.dart';

const _arroz = <String, Object>{
  'id': 1,
  'nome': 'Arroz, tipo 1, cozido',
  'categoria': 'Cereais e derivados',
  'kcal_100g': 128,
  'carbs_100g': 28.1,
  'prot_100g': 2.5,
  'gord_100g': 0.2,
};

const _feijao = <String, Object>{
  'id': 2,
  'nome': 'Feijao, carioca, cozido',
  'categoria': 'Leguminosas e derivados',
  'kcal_100g': 76,
  'carbs_100g': 13.6,
  'prot_100g': 4.8,
  'gord_100g': 0.5,
};

const _arrozFood = Food(
  id: 1,
  name: 'Arroz, tipo 1, cozido',
  category: 'Cereais e derivados',
  kcalPer100g: 128,
  carbsPer100g: 28.1,
  proteinPer100g: 2.5,
  fatPer100g: 0.2,
);

const _debounce = Duration(milliseconds: 300);

http.Response _json(Object body) {
  return http.Response(
    jsonEncode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

FoodRepository _repository(MockClientHandler handler) {
  return FoodRepository(
    ApiClient(
      baseUrl: 'http://api.test/api/v1',
      httpClient: MockClient(handler),
    ),
  );
}

Future<void> _pumpPage(WidgetTester tester, FoodRepository repository) {
  return tester.pumpWidget(
    MaterialApp(home: FoodSearchPage(repository: repository)),
  );
}

/// Digita [text] na busca e espera o debounce e a resposta da API.
Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(_debounce);
  await tester.pumpAndSettle();
}

/// Resultado da ultima tela de busca aberta por [_Host].
FoodPortion? _chosen;

/// Abre a busca como o fluxo de montar refeicao faz: com `push` e esperando
/// o [FoodPortion] devolvido.
class _Host extends StatelessWidget {
  const _Host({required this.repository});

  final FoodRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            _chosen = await Navigator.of(context).push<FoodPortion>(
              MaterialPageRoute(
                builder: (_) => FoodSearchPage(repository: repository),
              ),
            );
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}

/// Abre a busca, pesquisa "arroz" e escolhe o primeiro resultado (abre a
/// folha de porcao).
Future<void> _openPortionSheet(WidgetTester tester) async {
  final repository = _repository((request) async => _json([_arroz]));
  await tester.pumpWidget(MaterialApp(home: _Host(repository: repository)));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  await _search(tester, 'arroz');
  await tester.tap(find.text('Arroz, tipo 1, cozido'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _chosen = null);

  group('FoodSearchPage - busca', () {
    testWidgets('comeca pedindo para digitar um alimento', (tester) async {
      await _pumpPage(tester, _repository((request) async => _json([])));

      expect(
        find.text('Digite o nome de um alimento para buscar.'),
        findsOneWidget,
      );
    });

    testWidgets('debounce de 300 ms busca so o ultimo texto', (tester) async {
      final nomes = <String>[];
      final repository = _repository((request) async {
        nomes.add(request.url.queryParameters['nome']!);
        return _json([_arroz]);
      });
      await _pumpPage(tester, repository);

      await tester.enterText(find.byType(TextField), 'ar');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'arroz');
      await tester.pump(const Duration(milliseconds: 299));
      expect(nomes, isEmpty);

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(nomes, ['arroz']);
    });

    testWidgets('mostra os alimentos encontrados', (tester) async {
      final repository = _repository(
        (request) async => _json([_arroz, _feijao]),
      );
      await _pumpPage(tester, repository);

      await _search(tester, 'cozido');

      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
      expect(
        find.text('Cereais e derivados · 128 kcal/100 g'),
        findsOneWidget,
      );
      expect(find.text('Feijao, carioca, cozido'), findsOneWidget);
    });

    testWidgets('avisa quando nada e encontrado', (tester) async {
      await _pumpPage(tester, _repository((request) async => _json([])));

      await _search(tester, 'xyz');

      expect(
        find.text('Nenhum alimento encontrado para "xyz".'),
        findsOneWidget,
      );
    });

    testWidgets('limpar o campo cancela a busca pendente', (tester) async {
      var chamadas = 0;
      final repository = _repository((request) async {
        chamadas++;
        return _json([_arroz]);
      });
      await _pumpPage(tester, repository);

      await tester.enterText(find.byType(TextField), 'arroz');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 500));

      expect(chamadas, 0);
      expect(
        find.text('Digite o nome de um alimento para buscar.'),
        findsOneWidget,
      );
    });

    testWidgets('ignora a resposta de uma busca antiga', (tester) async {
      final respostas = <String, Completer<http.Response>>{};
      final repository = _repository((request) {
        final resposta = Completer<http.Response>();
        respostas[request.url.queryParameters['nome']!] = resposta;
        return resposta.future;
      });
      await _pumpPage(tester, repository);

      await tester.enterText(find.byType(TextField), 'ar');
      await tester.pump(_debounce);
      await tester.enterText(find.byType(TextField), 'arroz');
      await tester.pump(_debounce);

      respostas['arroz']!.complete(_json([_arroz]));
      await tester.pump(const Duration(milliseconds: 1));
      respostas['ar']!.complete(_json([_feijao]));
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
      expect(find.text('Feijao, carioca, cozido'), findsNothing);
    });

    testWidgets('erro de rede permite tentar de novo', (tester) async {
      var tentativas = 0;
      final repository = _repository((request) async {
        tentativas++;
        if (tentativas == 1) throw Exception('sem rede');
        return _json([_arroz]);
      });
      await _pumpPage(tester, repository);

      await _search(tester, 'arroz');
      expect(
        find.text('Sem conexão com a API. Verifique sua internet.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Arroz, tipo 1, cozido'), findsOneWidget);
    });

    testWidgets('falha da API mostra mensagem generica', (tester) async {
      final repository = _repository(
        (request) async => http.Response('erro', 500),
      );
      await _pumpPage(tester, repository);

      await _search(tester, 'arroz');

      expect(
        find.text('Não foi possível buscar os alimentos. Tente novamente.'),
        findsOneWidget,
      );
    });
  });

  group('FoodSearchPage - porcao', () {
    testWidgets('peso informado devolve a porcao escolhida', (tester) async {
      await _openPortionSheet(tester);

      await tester.enterText(find.byKey(const Key('portion-grams')), '150,5');
      await tester.pump();
      await tester.tap(find.byKey(const Key('portion-confirm')));
      await tester.pumpAndSettle();

      expect(find.byType(FoodSearchPage), findsNothing);
      expect(_chosen?.food.name, 'Arroz, tipo 1, cozido');
      expect(_chosen?.grams, 150.5);
    });

    testWidgets('a medida caseira e convertida em gramas', (tester) async {
      await _openPortionSheet(tester);

      await tester.tap(find.text('Medida caseira'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('portion-quantity')), '2');
      await tester.pump();
      expect(find.text('≈ 30 g (valor aproximado)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('portion-confirm')));
      await tester.pumpAndSettle();

      expect(_chosen?.grams, 30);
    });

    testWidgets('fechar a folha nao devolve nada', (tester) async {
      await _openPortionSheet(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(FoodSearchPage), findsOneWidget);
      expect(_chosen, isNull);
    });
  });

  group('PortionSheet', () {
    Future<void> pumpSheet(WidgetTester tester) {
      return tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PortionSheet(food: _arrozFood)),
        ),
      );
    }

    FilledButton confirmButton(WidgetTester tester) {
      return tester.widget<FilledButton>(
        find.byKey(const Key('portion-confirm')),
      );
    }

    testWidgets('comeca sem peso e com o botao desabilitado', (tester) async {
      await pumpSheet(tester);

      expect(confirmButton(tester).onPressed, isNull);
      expect(find.textContaining('Porção inválida'), findsNothing);
    });

    testWidgets('recusa peso zero, texto e acima do maximo', (tester) async {
      await pumpSheet(tester);
      final campo = find.byKey(const Key('portion-grams'));

      for (final texto in ['0', 'abc', '$maxPortionGrams,5']) {
        await tester.enterText(campo, texto);
        await tester.pump();

        expect(confirmButton(tester).onPressed, isNull, reason: texto);
        expect(find.textContaining('Porção inválida'), findsOneWidget);
      }
    });

    testWidgets('aceita o peso maximo', (tester) async {
      await pumpSheet(tester);

      await tester.enterText(
        find.byKey(const Key('portion-grams')),
        '$maxPortionGrams',
      );
      await tester.pump();

      expect(confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('trocar a medida recalcula as gramas', (tester) async {
      await pumpSheet(tester);

      await tester.tap(find.text('Medida caseira'));
      await tester.pumpAndSettle();
      expect(find.text('≈ 15 g (valor aproximado)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('portion-measure')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xícara (chá)').last);
      await tester.pumpAndSettle();

      expect(find.text('≈ 200 g (valor aproximado)'), findsOneWidget);
    });
  });
}
