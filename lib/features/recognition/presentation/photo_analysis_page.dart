import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../foods/data/food_repository.dart';
import '../data/photo_picker.dart';
import '../data/recognition_repository.dart';
import '../domain/detected_item.dart';
import 'recognition_review_page.dart';

/// Registro de refeicao por foto (RF02.1): o paciente tira (ou escolhe) a foto
/// do prato, a IA identifica os alimentos e a revisao abre com o resultado.
///
/// Fecha devolvendo `true` quando a refeicao foi registrada.
class PhotoAnalysisPage extends StatefulWidget {
  const PhotoAnalysisPage({
    required this.repository,
    required this.patientId,
    this.foods,
    this.pickPhoto = pickPhotoWithImagePicker,
    this.consumedAt,
    super.key,
  });

  final RecognitionRepository repository;
  final int patientId;

  /// Busca so na TACO, usada na revisao para trocar um alimento.
  final FoodRepository? foods;
  final PickPhoto pickPhoto;

  /// Quando a refeicao foi consumida; padrao: agora (ao abrir a revisao).
  final DateTime? consumedAt;

  @override
  State<PhotoAnalysisPage> createState() => _PhotoAnalysisPageState();
}

enum _Step { choosing, analyzing, problem }

class _PhotoAnalysisPageState extends State<PhotoAnalysisPage> {
  _Step _step = _Step.choosing;
  PickedPhoto? _photo;
  AnalysisStatus? _progress;
  String _message = '';

  /// A falha foi de rede/servico (vale repetir com a mesma foto).
  bool _retryable = false;

  /// Itens de uma analise que nao estimou com seguranca, para revisar mesmo
  /// assim (ex.: `low_confidence`).
  List<DetectedItem> _uncertainItems = const [];

  Future<void> _pick(PhotoSource source) async {
    final PickedPhoto? photo;
    try {
      photo = await widget.pickPhoto(source);
    } catch (_) {
      if (!mounted) return;
      _showProblem(
        source == PhotoSource.camera
            ? 'Não foi possível abrir a câmera. Verifique a permissão do app.'
            : 'Não foi possível abrir a galeria.',
        retryable: false,
      );
      return;
    }
    if (photo == null || !mounted) return;
    await _analyze(photo);
  }

  Future<void> _analyze(PickedPhoto photo) async {
    setState(() {
      _photo = photo;
      _step = _Step.analyzing;
      _progress = null;
      _uncertainItems = const [];
    });
    try {
      final analysis = await widget.repository.analyzePhoto(
        photo.bytes,
        filename: photo.filename,
        onProgress: (status) {
          if (mounted) setState(() => _progress = status);
        },
      );
      if (!mounted) return;
      if (analysis.status == AnalysisStatus.done && analysis.items.isNotEmpty) {
        await _review(analysis.items);
        return;
      }
      _uncertainItems = analysis.items;
      _showProblem(analysis.problemMessage, retryable: false);
    } catch (error) {
      if (!mounted) return;
      _showProblem(_describe(error), retryable: true);
    }
  }

  String _describe(Object error) {
    if (error is AnalysisTimeout) {
      return 'A análise está demorando mais que o normal. Tente de novo em '
          'instantes.';
    }
    if (error is ApiException) {
      return switch (error.statusCode) {
        null => 'Sem conexão com a API. Verifique sua internet.',
        413 => 'A foto é grande demais. Tente outra.',
        415 => 'O arquivo escolhido não é uma imagem.',
        503 => 'O serviço de análise está indisponível. Tente de novo em '
            'instantes.',
        _ => 'Não foi possível analisar a foto. Tente novamente.',
      };
    }
    return 'Não foi possível analisar a foto. Tente novamente.';
  }

  void _showProblem(String message, {required bool retryable}) {
    setState(() {
      _step = _Step.problem;
      _message = message;
      _retryable = retryable;
    });
  }

  Future<void> _review(List<DetectedItem> items) async {
    final photo = _photo!;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecognitionReviewPage(
          repository: widget.repository,
          patientId: widget.patientId,
          photo: MemoryImage(photo.bytes),
          items: items,
          foods: widget.foods,
          consumedAt: widget.consumedAt,
        ),
      ),
    );
    if (!mounted) return;
    if (saved == true) {
      Navigator.of(context).pop(true);
      return;
    }
    // Voltou da revisao sem registrar: pode tirar outra foto.
    setState(() => _step = _Step.choosing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Refeição por foto')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_photo case final photo? when _step != _Step.choosing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(
                    photo.bytes,
                    fit: BoxFit.cover,
                    semanticLabel: 'Foto da refeição',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            ...switch (_step) {
              _Step.choosing => _buildChoosing(context),
              _Step.analyzing => _buildAnalyzing(context),
              _Step.problem => _buildProblem(context),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _buildChoosing(BuildContext context) => [
        Icon(
          Icons.restaurant,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Fotografe o prato de cima, com boa luz, para a IA identificar os '
          'alimentos e estimar as porções.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ..._sourceButtons(),
      ];

  List<Widget> _sourceButtons() => [
        FilledButton.icon(
          onPressed: () => _pick(PhotoSource.camera),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Tirar foto'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _pick(PhotoSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Escolher da galeria'),
        ),
      ];

  List<Widget> _buildAnalyzing(BuildContext context) => [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Semantics(
          liveRegion: true,
          child: Text(
            _progress == AnalysisStatus.queued
                ? 'Foto na fila de análise...'
                : 'Analisando a foto...',
            textAlign: TextAlign.center,
          ),
        ),
      ];

  List<Widget> _buildProblem(BuildContext context) => [
        Semantics(
          liveRegion: true,
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 24),
        if (_uncertainItems.isNotEmpty) ...[
          FilledButton.tonal(
            onPressed: () => _review(_uncertainItems),
            child: const Text('Revisar os alimentos mesmo assim'),
          ),
          const SizedBox(height: 12),
        ],
        if (_photo case final photo? when _retryable) ...[
          OutlinedButton.icon(
            onPressed: () => _analyze(photo),
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar de novo com a mesma foto'),
          ),
          const SizedBox(height: 12),
        ],
        ..._sourceButtons(),
      ];
}
