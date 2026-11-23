import 'package:flutter/material.dart';

import '../domain/meal_type.dart';

/// Seletor reutilizável para informar o tipo de uma refeição.
class MealTypeSelector extends StatelessWidget {
  const MealTypeSelector({
    required this.value,
    required this.onChanged,
    this.label = 'Tipo de refeição',
    super.key,
  });

  final MealType value;
  final ValueChanged<MealType> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<MealType>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: MealType.values
            .map(
              (type) => DropdownMenuItem(value: type, child: Text(type.label)),
            )
            .toList(),
        onChanged: (type) {
          if (type != null) onChanged(type);
        },
      );
}

/// Tipo da refeição em chips, como as categorias da revisão no protótipo.
class MealTypeChips extends StatelessWidget {
  const MealTypeChips({
    required this.value,
    required this.onChanged,
    this.label = 'Categoria da refeição',
    super.key,
  });

  final MealType value;
  final ValueChanged<MealType> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(label, style: theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in MealType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: type == value,
                showCheckmark: false,
                onSelected: (_) => onChanged(type),
              ),
          ],
        ),
      ],
    );
  }
}
