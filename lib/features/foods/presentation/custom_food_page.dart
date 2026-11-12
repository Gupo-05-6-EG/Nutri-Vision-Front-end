import 'package:flutter/material.dart';

import '../data/food_repository.dart';
import '../domain/food.dart';
import '../domain/number_format.dart';

class CustomFoodPage extends StatefulWidget {
  const CustomFoodPage({
    required this.repository,
    required this.patientId,
    super.key,
  });
  final FoodRepository repository;
  final int patientId;

  @override
  State<CustomFoodPage> createState() => _CustomFoodPageState();
}

class _CustomFoodPageState extends State<CustomFoodPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _values = List.generate(4, (_) => TextEditingController());
  bool _saving = false;
  String? _error;
  static const _labels = [
    'Calorias (kcal)',
    'Carboidratos (g)',
    'Proteínas (g)',
    'Gorduras (g)',
  ];

  @override
  void dispose() {
    _name.dispose();
    for (final controller in _values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final values = _values.map((c) => parseDecimalInput(c.text)!).toList();
    if (values.skip(1).fold<double>(0, (a, b) => a + b) > 100) {
      setState(
        () => _error = 'A soma dos macronutrientes deve ser de até 100 g.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final food = await widget.repository
          .createCustom(widget.patientId, _name.text.trim(), values);
      if (mounted) Navigator.of(context).pop<Food>(food);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Não foi possível salvar. Verifique a conexão e se já existe um alimento com esse nome.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alimento personalizado')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Informe os valores do rótulo para 100 g de alimento.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                maxLength: 150,
                enabled: !_saving,
                decoration:
                    const InputDecoration(labelText: 'Nome do alimento'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
              ),
              for (var i = 0; i < _values.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: _values[i],
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _labels[i]),
                    validator: (v) {
                      final n = parseDecimalInput(v ?? '');
                      final max = i == 0 ? 900 : 100;
                      if (n == null || !n.isFinite || n < 0 || n > max) {
                        return 'Informe um valor entre 0 e $max.';
                      }
                      if ((n * 100 - (n * 100).round()).abs() > 0.00001) {
                        return 'Use até duas casas decimais.';
                      }
                      return null;
                    },
                  ),
                ),
              if (_error != null)
                Semantics(liveRegion: true, child: Text(_error!)),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Salvando…' : 'Salvar alimento'),
              ),
            ],
          ),
        ),
      );
}
