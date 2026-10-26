/// Medida caseira com o peso aproximado de uma unidade, em gramas.
///
/// A TACO nao traz medidas caseiras por alimento, entao estes valores sao
/// genericos e aproximados: servem para o paciente que nao sabe o peso exato.
class HouseholdMeasure {
  const HouseholdMeasure(this.name, this.gramsPerUnit);

  final String name;
  final double gramsPerUnit;

  static const List<HouseholdMeasure> all = [
    HouseholdMeasure('Colher de sopa', 15),
    HouseholdMeasure('Colher de sobremesa', 10),
    HouseholdMeasure('Colher de chá', 5),
    HouseholdMeasure('Xícara (chá)', 200),
  ];
}
