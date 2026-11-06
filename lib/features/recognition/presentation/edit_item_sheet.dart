import 'package:flutter/material.dart';

import '../../foods/domain/number_format.dart';
import '../../foods/presentation/portion_sheet.dart' show maxPortionGrams;
import '../domain/detected_item.dart';

/// Folha para corrigir a gramatura e o preparo de um item identificado pela
/// IA. Fecha devolvendo o [DetectedItem] editado.
class EditItemSheet extends StatefulWidget {
  const EditItemSheet({required this.item, super.key});

  final DetectedItem item;

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  late final _gramsController = TextEditingController(
    text: formatNumber(widget.item.grams),
  );
  late PreparationMethod _preparation = widget.item.preparation;

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  double? get _grams => parseDecimalInput(_gramsController.text);

  bool get _isValid {
    final grams = _grams;
    return grams != null && grams > 0 && grams <= maxPortionGrams;
  }

  void _confirm() {
    final grams = _grams;
    if (grams == null || !_isValid) return;
    Navigator.of(
      context,
    ).pop(widget.item.copyWith(grams: grams, preparation: _preparation));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            Text(widget.item.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Estimativa da IA: ${formatNumber(widget.item.grams)} g',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<PreparationMethod>(
              segments: [
                for (final method in PreparationMethod.values)
                  ButtonSegment(value: method, label: Text(method.label)),
              ],
              selected: {_preparation},
              onSelectionChanged: (selection) {
                setState(() => _preparation = selection.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('edit-item-grams'),
              controller: _gramsController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Peso',
                suffixText: 'g',
                errorText: _isValid
                    ? null
                    : 'Porção inválida: use mais de 0 g e no máximo '
                        '$maxPortionGrams g.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('edit-item-confirm'),
                onPressed: _isValid ? _confirm : null,
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
