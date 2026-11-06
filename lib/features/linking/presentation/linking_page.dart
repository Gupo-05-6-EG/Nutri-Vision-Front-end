import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/linking_service.dart';

class LinkingPage extends StatefulWidget {
  const LinkingPage({required this.client, super.key});

  final ApiClient client;

  @override
  State<LinkingPage> createState() => _LinkingPageState();
}

class _LinkingPageState extends State<LinkingPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  late final _service = LinkingService(widget.client);
  Nutritionist? _nutritionist;
  bool _loading = false;
  bool _linked = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _findNutritionist() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _nutritionist = null;
    });
    try {
      final nutritionist = await _service.redeemCode(_codeController.text);
      if (!mounted) return;
      setState(() => _nutritionist = nutritionist);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmLink() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.acceptLink(_nutritionist!.id);
      if (!mounted) return;
      setState(() => _linked = true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _messageFor(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 404 ||
          error.statusCode == 400 ||
          error.statusCode == 409 ||
          error.statusCode == 410) {
        return 'Codigo invalido ou expirado. Confira os 6 digitos com seu nutricionista.';
      }
      return error.message;
    }
    return 'Nao foi possivel conectar. Verifique sua internet e tente novamente.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: _linked
                  ? _successView(colors)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Icon(Icons.arrow_back, color: colors.primary),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child:
                              Icon(Icons.link, size: 32, color: colors.primary),
                        ),
                        const SizedBox(height: 24),
                        Text('Conecte-se ao seu nutricionista',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                )),
                        const SizedBox(height: 10),
                        Text(
                          'Digite o c\u{00f3}digo de 6 d\u{00ed}gitos que seu nutricionista compartilhou com voc\u{00ea}.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onFieldSubmitted: (_) => _findNutritionist(),
                            decoration: const InputDecoration(
                              labelText: 'C\u{00f3}digo de vincula\u{00e7}\u{00e3}o',
                              hintText: '000000',
                              prefixIcon: Icon(Icons.pin_outlined),
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == null ||
                                    !RegExp(r'^\d{6}$').hasMatch(value)
                                ? 'Informe os 6 d\u{00ed}gitos do c\u{00f3}digo.'
                                : null,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: colors.error)),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _loading ? null : _findNutritionist,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Continuar'),
                        ),
                        if (_nutritionist case final nutritionist?) ...[
                          const SizedBox(height: 28),
                          _NutritionistCard(nutritionist: nutritionist),
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: _loading ? null : _confirmLink,
                            icon: const Icon(Icons.check),
                            label: const Text('Confirmar vincula\u{00e7}\u{00e3}o'),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _successView(ColorScheme colors) => Column(
        children: [
          Icon(Icons.check_circle, size: 72, color: colors.primary),
          const SizedBox(height: 20),
          Text('Vincula\u{00e7}\u{00e3}o conclu\u{00ed}da!',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('Agora voc\u{00ea} est\u{00e1} conectado ao seu nutricionista.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge),
        ],
      );
}

class _NutritionistCard extends StatelessWidget {
  const _NutritionistCard({required this.nutritionist});

  final Nutritionist nutritionist;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: colors.primaryContainer,
              foregroundImage: nutritionist.photoUrl == null
                  ? null
                  : NetworkImage(nutritionist.photoUrl!),
              child: nutritionist.photoUrl == null
                  ? Icon(Icons.person, color: colors.primary, size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voc\u{00ea} vai se conectar com',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(nutritionist.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
