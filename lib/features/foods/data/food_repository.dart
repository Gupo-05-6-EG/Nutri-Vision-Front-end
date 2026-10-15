import '../../../core/network/api_client.dart';
import '../domain/food.dart';

/// Acesso a busca de alimentos da API (RF02.2).
class FoodRepository {
  const FoodRepository(this._client);

  /// Maximo de alimentos por busca (a API aceita ate 100).
  static const int searchLimit = 50;

  final ApiClient _client;

  /// Alimentos cujo nome contem [name], em ordem alfabetica.
  Future<List<Food>> search(String name) async {
    final result = await _client.get(
      '/alimentos-taco',
      query: {'nome': name, 'limite': searchLimit},
    );
    final items = (result as List<dynamic>).cast<Map<String, dynamic>>();
    return items.map(Food.fromJson).toList();
  }
}
