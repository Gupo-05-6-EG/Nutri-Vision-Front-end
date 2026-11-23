import 'package:flutter/material.dart';

import '../../foods/domain/food.dart';
import '../../foods/domain/number_format.dart';
import '../../foods/presentation/portion_sheet.dart' show maxPortionGrams;
import '../domain/detected_item.dart';

/// Folha para corrigir a gramatura de um item identificado pela IA ou
/// troca-lo por outro alimento da TACO. Fecha devolvendo o [DetectedItem]
/// editado.
class EditItemSheet extends StatefulWidget {
  const EditItemSheet({required this.item, this.searchFood, super.key});

  final DetectedItem item;

  /// Abre a busca na TACO e devolve o alimento escolhido com a porcao. Sem
  /// ele, a opcao de trocar o alimento nao aparece.
  final Future<FoodPortion?> Function()? searchFood;

  @override
  State<EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<EditItemSheet> {
  late final _gramsController = TextEditingController(
    text: formatNumber(widget.item.grams),
  );

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
    Navigator.of(context).pop(widget.item.copyWith(grams: grams));
  }

  Future<void> _replace() async {
    final portion = await widget.searchFood?.call();
    if (portion == null || !mounted) return;
    Navigator.of(context).pop(
      widget.item.copyWith(
        name: portion.food.name,
        tacoId: portion.food.id,
        grams: portion.grams,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
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
            Text(item.displayName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Estimativa da IA: ${formatNumber(item.aiGrams)} g',
              style: theme.textTheme.bodySmall,
            ),
            if (!item.isInTaco) ...[
              const SizedBox(height: 8),
              Text(
                'Este alimento não está na tabela TACO. Troque por um da '
                'tabela para calcular as calorias.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            if (item.isInTaco)
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
            if (widget.searchFood != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('edit-item-replace'),
                onPressed: _replace,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Trocar alimento'),
              ),
            ],
            if (item.isInTaco) ...[
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
          ],
        ),
      ),
    );
  }
}
