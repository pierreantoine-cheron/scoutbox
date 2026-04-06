import 'package:flutter/material.dart';

import '../../models/tent_shape.dart';

class TentShapeSelectionGrid extends StatelessWidget {
  final List<TentShape> shapes;
  final TentShape? selectedShape;
  final ValueChanged<TentShape> onSelect;

  const TentShapeSelectionGrid({
    super.key,
    required this.shapes,
    required this.selectedShape,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: shapes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final shape = shapes[index];
        final isSelected = selectedShape?.id == shape.id;

        return InkWell(
          key: ValueKey('shape-${shape.id}'),
          onTap: () => onSelect(shape),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      shape.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
