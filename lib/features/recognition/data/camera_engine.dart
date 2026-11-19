import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'photo_picker.dart';

/// Não há câmera ou o acesso foi negado.
class CameraUnavailable implements Exception {
  const CameraUnavailable([this.reason]);

  final Object? reason;
}

/// Câmera usada pela tela de captura. A interface existe para a tela ser
/// testada sem hardware (os testes usam uma câmera falsa).
abstract class CameraEngine {
  /// Abre a câmera traseira (ou a primeira disponível).
  Future<void> initialize();

  /// Imagem ao vivo da câmera.
  Widget buildPreview();

  /// Proporção largura/altura da imagem ao vivo.
  double get aspectRatio;

  Future<PickedPhoto> takePicture();

  bool get supportsFlash;
  Future<void> setFlash({required bool on});

  bool get canSwitchCamera;
  Future<void> switchCamera();

  Future<void> dispose();
}

/// Câmera real, pelo pacote `camera` (Android, iOS e navegador).
class DeviceCameraEngine implements CameraEngine {
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  CameraController? _controller;

  @override
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (error) {
      throw CameraUnavailable(error);
    }
    if (_cameras.isEmpty) throw const CameraUnavailable();
    final back = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    _index = back >= 0 ? back : 0;
    await _open();
  }

  Future<void> _open() async {
    final previous = _controller;
    _controller = null;
    await previous?.dispose();
    final controller = CameraController(
      _cameras[_index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
    } on CameraException catch (error) {
      await controller.dispose();
      throw CameraUnavailable(error);
    }
    _controller = controller;
  }

  CameraController get _active {
    final controller = _controller;
    if (controller == null) throw const CameraUnavailable();
    return controller;
  }

  @override
  Widget buildPreview() => CameraPreview(_active);

  @override
  double get aspectRatio {
    final value = _controller?.value;
    if (value == null || !value.isInitialized) return 3 / 4;
    // O plugin informa a proporção em paisagem; a tela é em pé.
    return 1 / value.aspectRatio;
  }

  @override
  Future<PickedPhoto> takePicture() async {
    final file = await _active.takePicture();
    final name = file.name.toLowerCase();
    final filename = name.endsWith('.png') ? 'refeicao.png' : 'refeicao.jpg';
    return PickedPhoto(bytes: await file.readAsBytes(), filename: filename);
  }

  // Na web o navegador não expõe o flash.
  @override
  bool get supportsFlash => !kIsWeb;

  @override
  Future<void> setFlash({required bool on}) =>
      _active.setFlashMode(on ? FlashMode.always : FlashMode.off);

  @override
  bool get canSwitchCamera => _cameras.length > 1;

  @override
  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    _index = (_index + 1) % _cameras.length;
    await _open();
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}
