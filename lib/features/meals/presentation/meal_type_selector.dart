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
              (type) => DropdownMenuItem(
                value: type,
                child: Text(type.label),
              ),
            )
            .toList(),
        onChanged: (type) {
          if (type != null) onChanged(type);
        },
      );
}
