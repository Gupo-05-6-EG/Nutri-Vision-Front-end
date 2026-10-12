/// Tipos de refeição usados na organização dos registros.
enum MealType {
  breakfast('cafe_da_manha', 'Café da manhã'),
  morningSnack('lanche_da_manha', 'Lanche da manhã'),
  lunch('almoco', 'Almoço'),
  afternoonSnack('lanche_da_tarde', 'Lanche da tarde'),
  dinner('jantar', 'Jantar'),
  supper('ceia', 'Ceia');

  const MealType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static MealType? fromApi(String? value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }

  /// Sugestão padrão pelo horário local, em faixas inclusivas no início.
  static MealType suggestedAt(DateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes < 10 * 60) return breakfast;
    if (minutes < 11 * 60 + 30) return morningSnack;
    if (minutes < 14 * 60 + 30) return lunch;
    if (minutes < 17 * 60 + 30) return afternoonSnack;
    if (minutes < 21 * 60) return dinner;
    return supper;
  }
}
