import '../../../core/network/api_client.dart';

class Nutritionist {
  const Nutritionist({required this.id, required this.name, this.photoUrl});

  final int id;
  final String name;
  final String? photoUrl;

  factory Nutritionist.fromJson(Map<String, dynamic> json) {
    return Nutritionist(
      id: (json['id'] as num).toInt(),
      name: (json['nome'] ?? json['name'] ?? 'Nutricionista').toString(),
      photoUrl: (json['foto_url'] ?? json['photo_url']) as String?,
    );
  }
}

class LinkingService {
  const LinkingService(this._client);

  final ApiClient _client;

  Future<Nutritionist> redeemCode(String code) async {
    final result = await _client.post('/link', {'codigo': code});
    final data = Map<String, dynamic>.from(result as Map);
    final professional = data['nutricionista'];
    return Nutritionist.fromJson(
        Map<String, dynamic>.from(professional as Map));
  }

  Future<void> acceptLink(int nutritionistId) async {
    await _client.post('/link/$nutritionistId/aceitar', null);
  }
}
