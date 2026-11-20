/// Alimentos reconhecidos na foto pela IA (RF02.1, RF02.3).
///
/// O back-end (`GET /analises/{id}`) devolve, por alimento, o nome na tabela
/// TACO, o id dele na nossa base, as gramas estimadas e a confianca do modelo.
/// O paciente revisa tudo isso antes de registrar a refeicao.
library;

/// Faixa de confianca exibida no badge do item.
enum ConfidenceLevel {
  high('Alta'),
  medium('Média'),
  low('Baixa');

  const ConfidenceLevel(this.label);

  final String label;

  /// Confianca a partir da qual o item e considerado certo.
  static const double highThreshold = 0.8;

  /// Abaixo disto o paciente precisa conferir o item.
  static const double mediumThreshold = 0.5;

  static ConfidenceLevel of(double confidence) {
    if (confidence >= highThreshold) return high;
    if (confidence >= mediumThreshold) return medium;
    return low;
  }
}

/// Um alimento identificado pela IA, ja com as edicoes do paciente.
class DetectedItem {
  const DetectedItem({
    required this.name,
    required this.confidence,
    required this.grams,
    this.tacoId,
    this.manual = false,
    double? aiGrams,
  }) : aiGrams = aiGrams ?? grams;

  /// Alimento da TACO escolhido pelo paciente (registro manual ou item que a
  /// IA nao viu). Nao tem confianca de IA.
  const DetectedItem.manual({
    required this.name,
    required int this.tacoId,
    required this.grams,
  })  : confidence = 1,
        manual = true,
        aiGrams = grams;

  /// Item de `GET /analises/{id}`.
  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    return DetectedItem(
      name: json['alimento'] as String,
      tacoId: (json['alimento_taco_id'] as num?)?.toInt(),
      confidence: (json['confianca'] as num).toDouble(),
      grams: (json['gramas'] as num).toDouble(),
    );
  }

  /// Nome do alimento na TACO (ou o nome dado pela IA, se nao estiver nela).
  final String name;

  /// Id na nossa tabela TACO; nulo quando o alimento nao esta nela e precisa
  /// ser trocado por um da tabela (ou excluido) antes de registrar.
  final int? tacoId;

  /// Confianca do modelo, de 0 a 1.
  final double confidence;

  /// Porcao atual, ja com a correcao do paciente.
  final double grams;

  /// Porcao que a IA estimou na foto, para referencia na edicao.
  final double aiGrams;

  /// Adicionado pelo paciente, e nao identificado pela IA.
  final bool manual;

  ConfidenceLevel get level => ConfidenceLevel.of(confidence);

  bool get isInTaco => tacoId != null;

  String get displayName => name;

  /// Corrige a porcao e/ou troca o alimento por outro da TACO.
  DetectedItem copyWith({double? grams, int? tacoId, String? name}) {
    return DetectedItem(
      name: name ?? this.name,
      tacoId: tacoId ?? this.tacoId,
      confidence: confidence,
      grams: grams ?? this.grams,
      manual: manual,
      aiGrams: aiGrams,
    );
  }

  /// Corpo de um item em `POST /calculo-nutricional` (so itens da TACO).
  Map<String, Object> toCalculationJson() => {
        'alimento_taco_id': tacoId!,
        'gramas': roundTo2(grams),
      };
}

/// Andamento da analise de `GET /analises/{id}`.
enum AnalysisStatus {
  queued('QUEUED'),
  processing('PROCESSING'),
  done('DONE'),
  notEstimated('NOT_ESTIMATED'),
  failed('FAILED');

  const AnalysisStatus(this.apiValue);

  final String apiValue;

  /// Ainda na fila ou sendo analisada: consultar de novo.
  bool get isPending => this == queued || this == processing;

  static AnalysisStatus fromApi(String value) =>
      values.firstWhere((status) => status.apiValue == value);
}

/// Resultado (ou andamento) da analise de uma foto.
class PhotoAnalysis {
  const PhotoAnalysis({
    required this.id,
    required this.status,
    this.reason,
    this.issues = const [],
    this.items = const [],
  });

  factory PhotoAnalysis.fromJson(Map<String, dynamic> json) {
    return PhotoAnalysis(
      id: json['id'] as String,
      status: AnalysisStatus.fromApi(json['status'] as String),
      reason: json['motivo'] as String?,
      issues: [...?(json['problemas'] as List<dynamic>?)?.cast<String>()],
      items: [
        for (final item in (json['itens'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
          DetectedItem.fromJson(item),
      ],
    );
  }

  final String id;
  final AnalysisStatus status;

  /// Com `NOT_ESTIMATED`: `bad_photo`, `nothing_detected` ou `low_confidence`.
  final String? reason;

  /// Com `bad_photo`: `blurry`, `too_dark` e/ou `too_bright`.
  final List<String> issues;
  final List<DetectedItem> items;

  /// Mensagem para o paciente quando a analise nao identificou o prato.
  String get problemMessage {
    if (status == AnalysisStatus.failed) {
      return 'Não foi possível analisar a foto agora. Tente novamente.';
    }
    switch (reason) {
      case 'bad_photo':
        final problems = [
          if (issues.contains('blurry')) 'está tremida',
          if (issues.contains('too_dark')) 'está escura',
          if (issues.contains('too_bright')) 'está clara demais',
        ];
        final detail =
            problems.isEmpty ? 'não ficou boa' : problems.join(' e ');
        return 'A foto $detail. Tire outra com o prato bem iluminado e '
            'a câmera firme.';
      case 'nothing_detected':
        return 'Não encontramos alimentos na foto. Enquadre o prato e tente '
            'de novo.';
      case 'low_confidence':
        return 'A IA não conseguiu identificar os alimentos com segurança.';
      default:
        return 'Não foi possível identificar os alimentos da foto.';
    }
  }
}

/// A API aceita no maximo duas casas decimais nos valores.
double roundTo2(double value) => (value * 100).roundToDouble() / 100;
