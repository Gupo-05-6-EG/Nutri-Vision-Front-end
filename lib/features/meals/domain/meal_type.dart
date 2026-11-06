/// Tipos de refeição aceitos pela API (RF19).
///
/// Os valores precisam bater com `TipoRefeicao` do back-end: qualquer outro
/// valor é recusado com `422`.
enum MealType {
  breakfast('cafe_da_manha', 'Café da manhã'),
  lunch('almoco', 'Almoço'),
  snack('lanche', 'Lanche'),
  dinner('jantar', 'Jantar');

  const MealType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MealType? fromApi(String? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }

  /// Sugestão pelo horário local, nas mesmas janelas que a API usa quando o
  /// tipo não é informado. Fora delas cai em lanche.
  static MealType suggestedAt(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return breakfast;
    if (hour >= 11 && hour < 15) return lunch;
    if (hour >= 18 && hour < 22) return dinner;
    return snack;
  }
}
