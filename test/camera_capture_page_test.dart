import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutri_vision/core/config/app_theme.dart';
import 'package:nutri_vision/features/recognition/data/camera_engine.dart';
import 'package:nutri_vision/features/recognition/data/photo_picker.dart';
import 'package:nutri_vision/features/recognition/presentation/camera_capture_page.dart';

class _FakeCamera implements CameraEngine {
  _FakeCamera({this.fails = false, this.cameras = 2, this.hangs = false});

  final bool fails;
  final bool hangs;
  final int cameras;
  bool flash = false;
  int switches = 0;
  bool disposed = false;

  @override
  Future<void> initialize() async {
    if (fails) throw const CameraUnavailable();
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Colors.brown);

  @override
  double get aspectRatio => 3 / 4;

  @override
  Future<PickedPhoto> takePicture() => hangs
      ? Completer<PickedPhoto>().future // nunca termina
      : Future.value(
          PickedPhoto(
            bytes: Uint8List.fromList([1, 2, 3]),
            filename: 'refeicao.jpg',
          ),
        );

  @override
  bool get supportsFlash => true;

  @override
  Future<void> setFlash({required bool on}) async => flash = on;

  @override
  bool get canSwitchCamera => cameras > 1;

  @override
  Future<void> switchCamera() async => switches++;

  @override
  Future<void> dispose() async => disposed = true;
}

Future<Object?> _open(
  WidgetTester tester,
  _FakeCamera camera, {
  PickPhoto? gallery,
  required void Function(Object?) onResult,
}) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(
            await Navigator.of(context).push<PickedPhoto>(
              MaterialPageRoute(
                builder: (_) => CameraCapturePage(
                  createEngine: () => camera,
                  pickFromGallery: gallery,
                  pickWithSystemCamera: gallery,
                ),
              ),
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return null;
}

void main() {
  testWidgets('tira a foto com o tipo de prato escolhido', (tester) async {
    Object? result;
    final camera = _FakeCamera();
    await _open(tester, camera, onResult: (r) => result = r);

    expect(find.text('Aponte para o prato e ganhe'), findsOneWidget);
    expect(find.bySemanticsLabel('Prato raso'), findsOneWidget);
    await tester.tap(find.text('Fundo'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Tirar foto'));
    await tester.pumpAndSettle();

    final photo = result! as PickedPhoto;
    expect(photo.plateType, PlateType.deep);
    expect(photo.bytes, [1, 2, 3]);
    expect(camera.disposed, isTrue);
  });

  testWidgets('captura travada libera o botao depois do limite',
      (tester) async {
    Object? result = 'nada';
    final camera = _FakeCamera(hangs: true);
    await _open(tester, camera, onResult: (r) => result = r);

    await tester.tap(find.bySemanticsLabel('Tirar foto'));
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(
      find.text(
        'Não foi possível tirar a foto. Tente de novo ou escolha da galeria.',
      ),
      findsOneWidget,
    );
    expect(result, 'nada'); // continua na camera
  });

  testWidgets('flash e troca de camera', (tester) async {
    final camera = _FakeCamera();
    await _open(tester, camera, onResult: (_) {});

    await tester.tap(find.byTooltip('Ligar o flash'));
    await tester.pump();
    expect(camera.flash, isTrue);
    expect(find.byTooltip('Desligar o flash'), findsOneWidget);

    await tester.tap(find.byTooltip('Trocar de câmera'));
    await tester.pumpAndSettle();
    expect(camera.switches, 1);
  });

  testWidgets('galeria leva o tipo de prato junto', (tester) async {
    Object? result;
    final sources = <PhotoSource>[];
    await _open(
      tester,
      _FakeCamera(),
      gallery: (source) async {
        sources.add(source);
        return PickedPhoto(bytes: Uint8List(1), filename: 'galeria.png');
      },
      onResult: (r) => result = r,
    );

    await tester.tap(find.byTooltip('Escolher da galeria'));
    await tester.pumpAndSettle();

    expect(sources, [PhotoSource.gallery]);
    expect((result! as PickedPhoto).plateType, PlateType.shallow);
  });

  testWidgets('sem camera oferece a do sistema e a galeria', (tester) async {
    Object? result;
    final sources = <PhotoSource>[];
    await _open(
      tester,
      _FakeCamera(fails: true),
      gallery: (source) async {
        sources.add(source);
        return PickedPhoto(bytes: Uint8List(1), filename: 'foto.jpg');
      },
      onResult: (r) => result = r,
    );

    expect(find.text('Não foi possível abrir a câmera.'), findsOneWidget);
    await tester.tap(find.text('Usar a câmera do sistema'));
    await tester.pumpAndSettle();

    expect(sources, [PhotoSource.camera]);
    expect(result, isA<PickedPhoto>());
  });

  testWidgets('fechar devolve nulo', (tester) async {
    Object? result = 'nao chamado';
    await _open(tester, _FakeCamera(cameras: 1), onResult: (r) => result = r);

    expect(find.byTooltip('Trocar de câmera'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
