import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/ui/nv_colors.dart';
import '../../../core/ui/nv_widgets.dart';
import '../data/camera_engine.dart';
import '../data/photo_picker.dart';

/// Câmera própria do protótipo: guia de enquadramento, flash, troca de câmera,
/// atalho para a galeria e a escolha do tipo de prato (raso ou fundo), que vai
/// para a IA como dica para estimar as gramas.
///
/// Fecha devolvendo a [PickedPhoto] (com o tipo de prato) ou `null`.
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({
    required this.createEngine,
    this.pickFromGallery,
    this.pickWithSystemCamera,
    this.captureTimeout = const Duration(seconds: 15),
    super.key,
  });

  final CameraEngine Function() createEngine;

  /// Galeria (e saída quando não há câmera).
  final PickPhoto? pickFromGallery;

  /// Câmera do sistema, usada quando esta câmera não abre.
  final PickPhoto? pickWithSystemCamera;

  /// Limite para a câmera devolver a foto. Se ela travar, o botão volta a
  /// funcionar e o paciente pode tentar de novo ou usar a galeria.
  final Duration captureTimeout;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

enum _CameraState { opening, ready, unavailable, capturing }

class _CameraCapturePageState extends State<CameraCapturePage> {
  late final CameraEngine _engine = widget.createEngine();
  _CameraState _state = _CameraState.opening;
  PlateType _plate = PlateType.shallow;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      await _engine.initialize();
      if (mounted) setState(() => _state = _CameraState.ready);
    } on Object {
      if (mounted) setState(() => _state = _CameraState.unavailable);
    }
  }

  @override
  void dispose() {
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _state = _CameraState.capturing);
    try {
      final photo = await _engine.takePicture().timeout(widget.captureTimeout);
      if (!mounted) return;
      Navigator.of(context).pop(photo.withPlate(_plate));
    } on Object {
      if (!mounted) return;
      setState(() => _state = _CameraState.ready);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível tirar a foto. Tente de novo ou escolha da galeria.',
          ),
        ),
      );
    }
  }

  Future<void> _fromPicker(PickPhoto? pick, PhotoSource source) async {
    if (pick == null) return;
    final PickedPhoto? photo;
    try {
      photo = await pick(source);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == PhotoSource.gallery
                ? 'Não foi possível abrir a galeria.'
                : 'Não foi possível abrir a câmera.',
          ),
        ),
      );
      return;
    }
    if (photo == null || !mounted) return;
    Navigator.of(context).pop(photo.withPlate(_plate));
  }

  Future<void> _toggleFlash() async {
    final on = !_flash;
    try {
      await _engine.setFlash(on: on);
      if (mounted) setState(() => _flash = on);
    } on Object {
      // Câmera sem flash: o botão só não muda.
    }
  }

  Future<void> _switch() async {
    setState(() => _state = _CameraState.opening);
    try {
      await _engine.switchCamera();
      if (mounted) setState(() => _state = _CameraState.ready);
    } on Object {
      if (mounted) setState(() => _state = _CameraState.unavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final live =
        _state == _CameraState.ready || _state == _CameraState.capturing;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (live)
            _Preview(engine: _engine)
          else if (_state == _CameraState.opening)
            const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Abrindo a câmera',
              ),
            )
          else
            _Unavailable(
              onSystemCamera: widget.pickWithSystemCamera == null
                  ? null
                  : () => _fromPicker(
                        widget.pickWithSystemCamera,
                        PhotoSource.camera,
                      ),
              onGallery: widget.pickFromGallery == null
                  ? null
                  : () => _fromPicker(
                        widget.pickFromGallery,
                        PhotoSource.gallery,
                      ),
            ),
          if (live) const _FrameGuide(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  onClose: () => Navigator.of(context).pop(),
                  flashOn: _flash,
                  onFlash: live && _engine.supportsFlash ? _toggleFlash : null,
                ),
                const Spacer(),
                if (live) ...[
                  const _Tip(),
                  const SizedBox(height: 12),
                  _PlateSelector(
                    value: _plate,
                    onChanged: (plate) => setState(() => _plate = plate),
                  ),
                  const SizedBox(height: 20),
                  _BottomControls(
                    capturing: _state == _CameraState.capturing,
                    onShutter: _capture,
                    onGallery: widget.pickFromGallery == null
                        ? null
                        : () => _fromPicker(
                              widget.pickFromGallery,
                              PhotoSource.gallery,
                            ),
                    onSwitch: _engine.canSwitchCamera ? _switch : null,
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.engine});

  final CameraEngine engine;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Imagem da câmera',
      image: true,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: 1000,
            height: 1000 / engine.aspectRatio,
            child: engine.buildPreview(),
          ),
        ),
      ),
    );
  }
}

/// Cantos verdes que mostram onde enquadrar o prato.
class _FrameGuide extends StatelessWidget {
  const _FrameGuide();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primaryContainer;
    return IgnorePointer(
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.78,
          child: AspectRatio(
            aspectRatio: 1,
            child: CustomPaint(painter: _CornersPainter(color)),
          ),
        ),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final arm = size.width * 0.16;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(w - arm, 0)
      ..lineTo(w, 0)
      ..lineTo(w, arm)
      ..moveTo(w, h - arm)
      ..lineTo(w, h)
      ..lineTo(w - arm, h)
      ..moveTo(arm, h)
      ..lineTo(0, h)
      ..lineTo(0, h - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: Colors.white.withValues(alpha: onPressed == null ? 0.4 : 0.9),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 48,
              child: Icon(icon, color: Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    required this.flashOn,
    required this.onFlash,
  });

  final VoidCallback onClose;
  final bool flashOn;
  final VoidCallback? onFlash;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _RoundButton(
            icon: Icons.close,
            tooltip: 'Fechar',
            onPressed: onClose,
          ),
          const Spacer(),
          const XpBadge(xp: 20, prefix: '+'),
          const Spacer(),
          if (onFlash != null)
            _RoundButton(
              icon: flashOn ? Icons.flash_on : Icons.flash_off,
              tooltip: flashOn ? 'Desligar o flash' : 'Ligar o flash',
              onPressed: onFlash,
            )
          else
            const SizedBox.square(dimension: 48),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: NvCard(
        radius: 28,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Column(
          children: [
            Text(
              'Aponte para o prato e ganhe',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const XpBadge(xp: 20, prefix: '+'),
          ],
        ),
      ),
    );
  }
}

class _PlateSelector extends StatelessWidget {
  const _PlateSelector({required this.value, required this.onChanged});

  final PlateType value;
  final ValueChanged<PlateType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          for (final plate in PlateType.values) ...[
            if (plate != PlateType.values.first) const SizedBox(width: 12),
            Expanded(
              child: _PlateOption(
                plate: plate,
                selected: plate == value,
                onTap: () => onChanged(plate),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlateOption extends StatelessWidget {
  const _PlateOption({
    required this.plate,
    required this.selected,
    required this.onTap,
  });

  final PlateType plate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nv = NvColors.of(context);
    final background = selected ? nv.xp : scheme.surfaceContainerLowest;
    final foreground = selected ? nv.onXp : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Prato ${plate.label.toLowerCase()}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            color: selected ? nv.xpStep : nv.cardStep,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(plate.icon, color: foreground, size: 20),
                const SizedBox(width: 6),
                Text(
                  plate.label,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.capturing,
    required this.onShutter,
    required this.onGallery,
    required this.onSwitch,
  });

  final bool capturing;
  final VoidCallback onShutter;
  final VoidCallback? onGallery;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: Icons.photo_library_outlined,
          tooltip: 'Escolher da galeria',
          onPressed: onGallery,
        ),
        Semantics(
          button: true,
          label: 'Tirar foto',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: capturing ? null : onShutter,
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 4),
                ),
                child: capturing
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : null,
              ),
            ),
          ),
        ),
        _RoundButton(
          icon: Icons.cameraswitch_outlined,
          tooltip: 'Trocar de câmera',
          onPressed: onSwitch,
        ),
      ],
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onSystemCamera, required this.onGallery});

  final VoidCallback? onSystemCamera;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: NvCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.no_photography_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                'Não foi possível abrir a câmera.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Verifique a permissão de câmera do app ou escolha uma foto.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (onSystemCamera != null) ...[
                NvButton(
                  label: 'Usar a câmera do sistema',
                  icon: Icons.photo_camera_outlined,
                  onPressed: onSystemCamera,
                ),
                const SizedBox(height: 12),
              ],
              if (onGallery != null)
                NvButton(
                  label: 'Escolher da galeria',
                  icon: Icons.photo_library_outlined,
                  style: NvButtonStyle.neutral,
                  onPressed: onGallery,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
