/// Converte o texto digitado em numero, aceitando virgula ou ponto.
///
/// Devolve `null` quando o texto nao e um numero valido.
double? parseDecimalInput(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Formata para exibicao em pt-BR: sem casa decimal quando o valor e inteiro,
/// senao uma casa, com virgula (ex.: `45`, `22,5`).
String formatNumber(double value) {
  final digits = value == value.roundToDouble() ? 0 : 1;
  return value.toStringAsFixed(digits).replaceAll('.', ',');
}
