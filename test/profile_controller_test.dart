import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nutri_vision/features/auth/application/auth_controller.dart';
import 'package:nutri_vision/features/profile/application/profile_controller.dart';
import 'package:nutri_vision/features/profile/data/profile_repository.dart';
import 'package:nutri_vision/features/profile/domain/patient_profile.dart';

import 'support/session.dart';

void main() {
  test('le o perfil com a meta unica, XP e divisao', () {
    final profile = PatientProfile.fromJson(
      profileJson(
        nutritionist: {'id': 3, 'nome': 'Dra. Camila', 'crn': 'CRN-3 4289'},
      ),
    );

    expect(profile.firstName, 'Alex');
    expect(profile.goal.kcal, 2000);
    expect(profile.goal.proteinG, 120);
    expect(profile.goal.source, GoalSource.screening);
    expect(profile.goal.isSet, isTrue);
    expect(profile.gamification.xp, 520);
    expect(profile.gamification.division, 'Ouro');
    expect(profile.gamification.mealsLogged, 36);
    expect(profile.nutritionist?.crn, 'CRN-3 4289');
    expect(profile.bmiClass, 'Eutrófico');
  });

  test('sem meta: isSet falso e origem nula', () {
    final profile =
        PatientProfile.fromJson(profileJson(kcal: null, source: null));

    expect(profile.goal.isSet, isFalse);
    expect(profile.goal.source, isNull);
  });

  test('carrega ao entrar, recarrega no sync e limpa ao sair', () async {
    var calls = 0;
    final (client, auth) = await loggedSession(
      MockClient((request) async {
        if (request.url.path == ProfileRepository.path(7)) {
          calls++;
          return jsonResponse(profileJson(xp: 500 + calls * 10));
        }
        return http.Response('', 404);
      }),
    );
    final synced = StreamController<int>.broadcast();
    final controller = ProfileController(
      auth: auth,
      repository: ProfileRepository(client),
      syncEvents: synced.stream,
    );
    await controller.refresh();

    expect(controller.profile?.name, 'Alex Silva');
    expect(controller.xp, greaterThanOrEqualTo(510));
    final before = calls;

    synced.add(1);
    await pumpEventQueue();
    await controller.refresh();
    expect(calls, greaterThan(before));

    await auth.logout();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(controller.profile, isNull);
    expect(controller.goal.isSet, isFalse);

    controller.dispose();
    await synced.close();
  });

  test('erro da API fica em error, sem perfil', () async {
    final (client, auth) = await loggedSession(
      MockClient((_) async => http.Response('erro', 500)),
    );
    final controller =
        ProfileController(auth: auth, repository: ProfileRepository(client));
    await controller.refresh();

    expect(controller.profile, isNull);
    expect(controller.error, isNotNull);
    controller.dispose();
  });
}
