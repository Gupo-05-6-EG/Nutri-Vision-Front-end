import 'package:flutter/material.dart';

import '../../../core/config/env.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

/// Tela temporaria de diagnostico.
///
/// Existe apenas para provar que o app builda, le o `.env` e fala com a API.
/// E substituida pelas telas de cadastro/login na Task 1.2.
class ApiStatusPage extends StatefulWidget {
  const ApiStatusPage({required this.client, super.key});

  final ApiClient client;

  @override
  State<ApiStatusPage> createState() => _ApiStatusPageState();
}

class _ApiStatusPageState extends State<ApiStatusPage> {
  late Future<Map<String, dynamic>> _health;

  @override
  void initState() {
    super.initState();
    _health = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() async {
    final result = await widget.client.get('/health');
    return Map<String, dynamic>.from(result as Map);
  }

  void _retry() => setState(() => _health = _fetch());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Env.appName)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<Map<String, dynamic>>(
            future: _health,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              final error = snapshot.error;
              if (error != null) {
                return _StatusCard(
                  icon: Icons.cloud_off,
                  title: 'Sem conexao com a API',
                  detail: error is ApiException ? error.message : '$error',
                  onRetry: _retry,
                );
              }

              return _StatusCard(
                icon: Icons.cloud_done,
                title: 'API conectada',
                detail: '${snapshot.data?['service']} '
                    '(${snapshot.data?['environment']})\n${Env.apiUrl}',
                onRetry: _retry,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.detail,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, semanticLabel: title),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(detail, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar de novo'),
        ),
      ],
    );
  }
}
