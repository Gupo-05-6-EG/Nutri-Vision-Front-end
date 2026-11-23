import '../../../core/network/api_client.dart';
import '../domain/food.dart';

/// Acesso a busca de alimentos da API (RF02.2).
class FoodRepository {
  const FoodRepository(this._client, {this.patientId});

  final int? patientId;

  /// Maximo de alimentos por busca (a API aceita ate 100).
  static const int searchLimit = 50;

  final ApiClient _client;

  /// Alimentos cujo nome contem [name], em ordem alfabetica.
  Future<List<Food>> search(String name) async {
    final result = await _client.get(
      patientId == null ? '/alimentos-taco' : '/alimentos',
      query: {
        'nome': name,
        'limite': searchLimit,
        if (patientId != null) 'paciente_id': patientId,
      },
    );
    final items = (result as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(Food.fromJson).toList();
  }

  Future<Food> createCustom(
    int patientId,
    String name,
    List<double> values,
  ) async {
    final result = await _client.post('/alimentos-personalizados', {
      'paciente_id': patientId,
      'nome': name,
      'kcal_100g': values[0],
      'carbs_100g': values[1],
      'prot_100g': values[2],
      'gord_100g': values[3],
    });
    return Food.fromJson({
      ...result as Map<String, dynamic>,
      'categoria': 'Personalizado',
      'origem': 'personalizado',
    });
  }
}
