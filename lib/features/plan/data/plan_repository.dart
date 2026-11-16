import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../meals/data/meal_repository.dart';
import '../domain/meal_plan.dart';
import '../domain/progress.dart';

/// Plano alimentar e consumo do paciente (Task 2.9; RF06, RF25).
class PlanRepository {
  PlanRepository(this._client) : _meals = MealRepository(_client);

  static String activePlanPath(int patientId) =>
      '/pacientes/$patientId/planos/ativo';

  final ApiClient _client;
  final MealRepository _meals;

  /// Plano ativo do paciente, ou `null` quando o nutricionista ainda nao
  /// prescreveu nenhum (a API responde 404 "Paciente sem plano ativo").
  Future<MealPlan?> activePlan(int patientId) async {
    final Object? response;
    try {
      response = await _client.get(activePlanPath(patientId));
    } on ApiException catch (error) {
      if (error.statusCode == 404 && error.message.contains('sem plano')) {
        return null;
      }
      rethrow;
    }
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Resposta inesperada do plano.');
    }
    return MealPlan.fromJson(response);
  }

  /// Consumo de hoje e da semana (segunda ate hoje), com uma consulta por dia.
  Future<WeekConsumption> weekConsumption({
    required int patientId,
    required DateTime today,
  }) async {
    final days = weekDaysUntil(today);
    final results = await Future.wait(
      days.map(
        (day) => _meals.dailyConsumption(patientId: patientId, day: day),
      ),
    );
    final totals = results.map((result) => result.totals).toList();
    return WeekConsumption(today: totals.last, week: sumTotals(totals));
  }
}
