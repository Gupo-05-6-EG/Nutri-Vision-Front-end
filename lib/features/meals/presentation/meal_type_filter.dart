import 'package:flutter/material.dart';

import '../domain/meal_type.dart';

/// Filtro opcional por tipo para a listagem do histórico.
class MealTypeFilter extends StatelessWidget {
  const MealTypeFilter({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final MealType? value;
  final ValueChanged<MealType?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<MealType?>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Filtrar por refeição'),
        items: [
          const DropdownMenuItem<MealType?>(
            value: null,
            child: Text('Todas as refeições'),
          ),
          ...MealType.values.map(
            (type) => DropdownMenuItem<MealType?>(
              value: type,
              child: Text(type.label),
            ),
          ),
        ],
        onChanged: onChanged,
      );
}
