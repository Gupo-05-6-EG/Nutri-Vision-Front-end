/// Alimentos reconhecidos na foto pelo modelo de IA (RF02.1, RF02.3).
///
/// O modelo devolve, por alimento, a classe (ex.: `arroz`), a confianca, o
/// metodo de preparo, as gramas estimadas e onde o alimento esta na foto. O
/// paciente revisa tudo isso antes de registrar a refeicao.
library;

/// Metodo de preparo, como a API de calculo nutricional espera (`cru`,
/// `cozido`, `frito`): a TACO tem uma linha para cada um.
enum PreparationMethod {
  raw('cru', 'Cru'),
  cooked('cozido', 'Cozido'),
  fried('frito', 'Frito');

  const PreparationMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PreparationMethod fromApi(String value) =>
      values.firstWhere((method) => method.apiValue == value);
}

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

/// Regiao do alimento na foto, em fracoes (0 a 1) da largura e da altura.
class BoundingBox {
  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  factory BoundingBox.fromJson(Map<String, dynamic> json) {
    return BoundingBox(
      left: (json['x'] as num).toDouble(),
      top: (json['y'] as num).toDouble(),
      width: (json['largura'] as num).toDouble(),
      height: (json['altura'] as num).toDouble(),
    );
  }

  final double left;
  final double top;
  final double width;
  final double height;
}

/// Um alimento identificado pela IA, ja com as edicoes do paciente.
class DetectedItem {
  const DetectedItem({
    required this.foodClass,
    required this.confidence,
    required this.preparation,
    required this.grams,
    this.box,
  });

  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    final box = json['caixa'] as Map<String, dynamic>?;
    return DetectedItem(
      foodClass: json['classe'] as String,
      confidence: (json['confianca'] as num).toDouble(),
      preparation: PreparationMethod.fromApi(json['metodo_preparo'] as String),
      grams: (json['gramas'] as num).toDouble(),
      box: box == null ? null : BoundingBox.fromJson(box),
    );
  }

  /// Classe devolvida pelo modelo (ex.: `feijao_carioca`).
  final String foodClass;

  /// Confianca do modelo, de 0 a 1.
  final double confidence;
  final PreparationMethod preparation;
  final double grams;
  final BoundingBox? box;

  ConfidenceLevel get level => ConfidenceLevel.of(confidence);

  /// Nome legivel da classe (`feijao_carioca` -> `Feijao carioca`).
  String get displayName {
    final words = foodClass.replaceAll('_', ' ').trim();
    if (words.isEmpty) return foodClass;
    return words[0].toUpperCase() + words.substring(1);
  }

  DetectedItem copyWith({PreparationMethod? preparation, double? grams}) {
    return DetectedItem(
      foodClass: foodClass,
      confidence: confidence,
      preparation: preparation ?? this.preparation,
      grams: grams ?? this.grams,
      box: box,
    );
  }

  /// Corpo de um item em `POST /calculo-nutricional`.
  Map<String, Object> toCalculationJson() => {
        'classe': foodClass,
        'metodo_preparo': preparation.apiValue,
        'gramas': roundTo2(grams),
      };
}

/// A API aceita no maximo duas casas decimais nos valores.
double roundTo2(double value) => (value * 100).roundToDouble() / 100;
