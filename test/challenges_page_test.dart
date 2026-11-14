import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/core/network/api_client.dart';
import 'package:nutri_vision/features/challenges/data/challenge_repository.dart';
import 'package:nutri_vision/features/challenges/domain/challenge.dart';
import 'package:nutri_vision/features/challenges/presentation/challenge_leaderboard_page.dart';
import 'package:nutri_vision/features/challenges/presentation/challenges_page.dart';
import 'package:nutri_vision/features/challenges/presentation/create_challenge_page.dart';

http.Response _json(Object body, {int status = 200}) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

const _sampleChallengesJson = [
  {
    'id': 1,
    'nome': 'Semana Saudável',
    'tipo': 'refeicoes',
    'regra': 'Maior número de refeições registradas no período.',
    'inicio_em': '2026-04-10T00:00:00Z',
    'fim_em': '2026-04-17T00:00:00Z',
    'status': 'aceito',
  },
  {
    'id': 2,
    'nome': 'Foco na Meta',
    'tipo': 'sequencia_meta',
    'regra': 'Maior sequência de dias consecutivos dentro da meta.',
    'inicio_em': '2026-04-12T00:00:00Z',
    'fim_em': '2026-04-19T00:00:00Z',
    'status': 'convidado',
  },
];

const _sampleLeaderboardJson = {
  'desafio_id': 1,
  'tipo': 'refeicoes',
  'participantes': [
    {
      'posicao': 1,
      'paciente_id': 10,
      'nome': 'Ana Silva',
      'pontuacao': 14.0,
      'unidade': 'refeições',
    },
    {
      'posicao': 2,
      'paciente_id': 20,
      'nome': 'Bruno Costa',
      'pontuacao': 11.0,
      'unidade': 'refeições',
    },
    {
      'posicao': 3,
      'paciente_id': 30,
      'nome': 'Carla Souza',
      'pontuacao': null,
      'unidade': 'refeições',
    },
  ],
};

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  group('Challenge domain models & ChallengeRepository', () {
    test('parseia tipos, status, placar e amigos corretamente', () {
      expect(
        ChallengeType.fromApi('variacao_calorica'),
        ChallengeType.calorieVariation,
      );
      expect(
        ChallengeParticipantStatus.fromApi('convidado'),
        ChallengeParticipantStatus.invited,
      );
      expect(
        ChallengeParticipantStatus.fromApi('desconhecido'),
        isNull,
      );

      final friend = FriendSummary.fromJson({
        'paciente_id': 25,
        'username': 'Diego Lima',
        'streak': 4,
      });
      expect(friend.patientId, 25);
      expect(friend.displayName, 'Diego Lima');
      expect(friend.streak, 4);
    });

    test('consulta desafios, cria desafio, responde convite e busca placar',
        () async {
      final requests = <String>[];
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api/v1',
        httpClient: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/challenges') {
            return _json(_sampleChallengesJson);
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/challenges') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['nome'], 'Desafio Equilíbrio');
            expect(body['tipo'], 'variacao_calorica');
            expect(body['convidados'], [20, 30]);
            return _json(
              {
                'id': 9,
                'nome': body['nome'],
                'tipo': body['tipo'],
                'regra': body['regra'],
                'inicio_em': body['inicio_em'],
                'fim_em': body['fim_em'],
                'status': 'aceito',
              },
              status: 201,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/challenges/2/response') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            return _json({
              'paciente_id': 10,
              'nome': 'Ana Silva',
              'status': (body['aceitar'] as bool) ? 'aceito' : 'recusado',
            });
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/challenges/1/invites') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['pacientes'], [40]);
            return _json([
              {
                'paciente_id': 40,
                'nome': 'Eduardo Rocha',
                'status': 'convidado',
              },
            ]);
          }
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/challenges/1/leaderboard') {
            return _json(_sampleLeaderboardJson);
          }
          return _json({'detail': 'not found'}, status: 404);
        }),
      );

      final repo = ChallengeRepository(client);
      final list = await repo.listChallenges();
      expect(list, hasLength(2));
      expect(list.first.type, ChallengeType.meals);

      final created = await repo.createChallenge(
        ChallengeDraft(
          name: 'Desafio Equilíbrio',
          type: ChallengeType.calorieVariation,
          rule: ChallengeType.calorieVariation.defaultRule,
          startsAt: DateTime.utc(2026, 4, 14),
          endsAt: DateTime.utc(2026, 4, 21),
          invitedIds: const [20, 30],
        ),
      );
      expect(created.id, 9);

      final response = await repo.respondInvite(2, accept: true);
      expect(response.status, ChallengeParticipantStatus.accepted);

      final invited = await repo.inviteFriends(1, const [40]);
      expect(invited.single.name, 'Eduardo Rocha');

      final leaderboard = await repo.fetchLeaderboard(1);
      expect(leaderboard.entries, hasLength(3));
      expect(leaderboard.entries.first.score, 14.0);
      expect(requests, hasLength(5));
    });
  });

  group('ChallengesPage', () {
    testWidgets('lista convites pendentes e desafios ativos e aceita convite',
        (tester) async {
      var inviteAccepted = false;
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api/v1',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/challenges') {
            return _json([
              _sampleChallengesJson[0],
              {
                ..._sampleChallengesJson[1],
                'status': inviteAccepted ? 'aceito' : 'convidado',
              },
            ]);
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/challenges/2/response') {
            inviteAccepted = true;
            return _json({
              'paciente_id': 10,
              'nome': 'Ana Silva',
              'status': 'aceito',
            });
          }
          return _json({}, status: 404);
        }),
      );

      await tester.pumpWidget(
        _wrap(
          ChallengesPage(
            repository: ChallengeRepository(client),
            patientId: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Convites pendentes (1)'), findsOneWidget);
      expect(find.text('Meus desafios (1)'), findsOneWidget);
      expect(find.text('Foco na Meta'), findsOneWidget);
      expect(find.text('Semana Saudável'), findsOneWidget);

      await tester.tap(find.byKey(const Key('accept-challenge-2')));
      await tester.pumpAndSettle();

      expect(find.text('Convites pendentes (1)'), findsNothing);
      expect(find.text('Meus desafios (2)'), findsOneWidget);
    });
  });

  group('CreateChallengePage', () {
    testWidgets('escolhe tipo, seleciona amigos e cria desafio na API',
        (tester) async {
      Map<String, dynamic>? postedBody;
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api/v1',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/amizades') {
            return _json([
              {
                'paciente_id': 20,
                'username': 'Bruno Costa',
                'streak': 5,
              },
            ]);
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/challenges') {
            postedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(
              {
                'id': 77,
                'nome': postedBody!['nome'],
                'tipo': postedBody!['tipo'],
                'regra': postedBody!['regra'],
                'inicio_em': postedBody!['inicio_em'],
                'fim_em': postedBody!['fim_em'],
                'status': 'aceito',
              },
              status: 201,
            );
          }
          return _json({}, status: 404);
        }),
      );

      await tester.pumpWidget(
        _wrap(
          CreateChallengePage(
            repository: ChallengeRepository(client),
            patientId: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('challenge-name-input')),
        'Desafio 7 Dias',
      );
      await tester.tap(find.byKey(const Key('challenge-type-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sequência na meta').last);
      await tester.pumpAndSettle();

      // Seleciona amigo da lista e adiciona outro por ID
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('friend-chip-20')));
      await tester.enterText(
        find.byKey(const Key('invite-friend-id-input')),
        '30',
      );
      await tester.tap(find.byKey(const Key('add-friend-id-button')));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('submit-create-challenge')));
      await tester.pumpAndSettle();

      expect(postedBody, isNotNull);
      expect(postedBody!['nome'], 'Desafio 7 Dias');
      expect(postedBody!['tipo'], 'sequencia_meta');
      expect(postedBody!['convidados'], containsAll(<int>[20, 30]));
    });
  });

  group('ChallengeLeaderboardPage', () {
    testWidgets('exibe placar ordenado e permite convidar amigos adicionais',
        (tester) async {
      List<dynamic>? invitedIds;
      final client = ApiClient(
        baseUrl: 'https://api.example.com/api/v1',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/challenges/1/leaderboard') {
            return _json(_sampleLeaderboardJson);
          }
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/amizades') {
            return _json([]);
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/challenges/1/invites') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            invitedIds = body['pacientes'] as List<dynamic>;
            return _json([
              {
                'paciente_id': 50,
                'nome': 'Fernanda Dias',
                'status': 'convidado',
              },
            ]);
          }
          return _json({}, status: 404);
        }),
      );

      final challenge = Challenge.fromJson(_sampleChallengesJson.first);
      await tester.pumpWidget(
        _wrap(
          ChallengeLeaderboardPage(
            repository: ChallengeRepository(client),
            challenge: challenge,
            patientId: 10,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ana Silva (Você)'), findsOneWidget);
      expect(find.text('14 refeições'), findsOneWidget);
      expect(find.text('Bruno Costa'), findsOneWidget);
      expect(find.text('Sem pontuação'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-invite-friends')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('sheet-friend-id-input')),
        '50',
      );
      await tester.tap(find.byKey(const Key('sheet-add-friend-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('sheet-send-invites-button')));
      await tester.pumpAndSettle();

      expect(invitedIds, [50]);
      expect(
        find.text('Convite enviado para Fernanda Dias.'),
        findsOneWidget,
      );
    });
  });
}
