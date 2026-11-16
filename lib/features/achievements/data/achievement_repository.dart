import '../../../core/network/api_client.dart';

class Achievement {
  const Achievement({
    required this.name,
    required this.progress,
    required this.target,
    required this.unlocked,
  });
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        name: json['nome'] as String,
        progress: json['progresso'] as int,
        target: json['meta'] as int,
        unlocked: json['obtida_em'] != null,
      );
  final String name;
  final int progress;
  final int target;
  final bool unlocked;
}

class AchievementRepository {
  const AchievementRepository(this.client);
  final ApiClient client;
  Future<List<Achievement>> list() async {
    final data = await client.get('/gamificacao/conquistas') as List<dynamic>;
    return data
        .map((v) => Achievement.fromJson(v as Map<String, dynamic>))
        .toList();
  }
}
