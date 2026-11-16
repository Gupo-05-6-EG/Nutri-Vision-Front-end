import 'package:flutter/material.dart';
import '../data/achievement_repository.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({required this.repository, super.key});
  final AchievementRepository repository;
  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  late Future<List<Achievement>> _items = widget.repository.list();
  void _reload() => setState(() => _items = widget.repository.list());

  Future<void> _refresh() async {
    _reload();
    try {
      await _items;
    } catch (_) {
      // FutureBuilder apresenta o erro e oferece uma nova tentativa.
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Minhas conquistas')),
        body: FutureBuilder<List<Achievement>>(
          future: _items,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Não foi possível carregar suas conquistas.'),
                    TextButton(
                      onPressed: _reload,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Carregando conquistas',
                ),
              );
            }
            if (snapshot.data!.isEmpty) {
              return const Center(child: Text('Nenhuma conquista disponível.'));
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: snapshot.data!
                    .map(
                      (item) => Semantics(
                        label:
                            '${item.name}. ${item.unlocked ? "Obtida" : "Bloqueada"}. ${item.progress} de ${item.target}.',
                        excludeSemantics: true,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  item.unlocked
                                      ? Icons.emoji_events
                                      : Icons.lock_outline,
                                ),
                                Text(
                                  item.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  item.unlocked
                                      ? 'Obtida'
                                      : 'Bloqueada · ${item.progress}/${item.target}',
                                ),
                                LinearProgressIndicator(
                                  value: item.progress / item.target,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          },
        ),
      );
}
