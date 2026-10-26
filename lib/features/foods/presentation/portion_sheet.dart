import 'package:flutter/material.dart';

import '../domain/food.dart';
import '../domain/household_measure.dart';
import '../domain/number_format.dart';

/// Maior porcao aceita, em gramas (evita erro de digitacao).
const int maxPortionGrams = 10000;

const _decimalKeyboard = TextInputType.numberWithOptions(decimal: true);

enum _InputMode { grams, measure }

/// Folha para informar a porcao do alimento escolhido: peso em gramas ou
/// medida caseira. Fecha devolvendo um [FoodPortion].
class PortionSheet extends StatefulWidget {
  const PortionSheet({required this.food, super.key});

  final Food food;

  @override
  State<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<PortionSheet> {
  final _gramsController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  _InputMode _mode = _InputMode.grams;
  HouseholdMeasure _measure = HouseholdMeasure.all.first;

  @override
  void dispose() {
    _gramsController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  TextEditingController get _activeController {
    return _mode == _InputMode.grams ? _gramsController : _quantityController;
  }

  /// Porcao em gramas, ou `null` se o campo nao e um numero.
  double? get _grams {
    final typed = parseDecimalInput(_activeController.text);
    if (typed == null) return null;
    return _mode == _InputMode.grams ? typed : typed * _measure.gramsPerUnit;
  }

  bool get _isValid {
    final grams = _grams;
    return grams != null && grams > 0 && grams <= maxPortionGrams;
  }

  String? get _errorText {
    if (_activeController.text.trim().isEmpty || _isValid) return null;
    return 'Porção inválida: use mais de 0 g e no máximo $maxPortionGrams g.';
  }

  void _confirm() {
    final grams = _grams;
    if (grams == null || !_isValid) return;
    Navigator.of(context).pop(FoodPortion(food: widget.food, grams: grams));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grams = _grams;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.food.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '${formatNumber(widget.food.kcalPer100g)} kcal por 100 g',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<_InputMode>(
              segments: const [
                ButtonSegment(
                  value: _InputMode.grams,
                  label: Text('Peso (g)'),
                ),
                ButtonSegment(
                  value: _InputMode.measure,
                  label: Text('Medida caseira'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
            const SizedBox(height: 16),
            if (_mode == _InputMode.grams)
              TextField(
                key: const Key('portion-grams'),
                controller: _gramsController,
                autofocus: true,
                keyboardType: _decimalKeyboard,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Peso',
                  suffixText: 'g',
                  errorText: _errorText,
                  border: const OutlineInputBorder(),
                ),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('portion-quantity'),
                      controller: _quantityController,
                      keyboardType: _decimalKeyboard,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Quantidade',
                        errorText: _errorText,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButton<HouseholdMeasure>(
                      key: const Key('portion-measure'),
                      isExpanded: true,
                      value: _measure,
                      items: [
                        for (final measure in HouseholdMeasure.all)
                          DropdownMenuItem(
                            value: measure,
                            child: Text(measure.name),
                          ),
                      ],
                      onChanged: (measure) {
                        if (measure == null) return;
                        setState(() => _measure = measure);
                      },
                    ),
                  ),
                ],
              ),
            if (_mode == _InputMode.measure && _isValid) ...[
              const SizedBox(height: 8),
              Text(
                '≈ ${formatNumber(grams!)} g (valor aproximado)',
                key: const Key('portion-equivalent'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('portion-confirm'),
                onPressed: _isValid ? _confirm : null,
                child: const Text('Confirmar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
