import 'package:flutter/material.dart';

import '../../utils/design_constants.dart';

class SegmentedToggleOption<T> {
  final T value;
  final String label;
  final Color? color;
  final Color? backgroundColor;

  const SegmentedToggleOption({
    required this.value,
    required this.label,
    this.color,
    this.backgroundColor,
  });
}

class ScoutSegmentedToggle<T> extends StatelessWidget {
  final List<SegmentedToggleOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool expanded;

  const ScoutSegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final row = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final option in options)
          _SegmentedButton<T>(
            label: option.label,
            color: option.color,
            backgroundColor: option.backgroundColor,
            isSelected: selected == option.value,
            expanded: expanded,
            onTap: () => onChanged(option.value),
          ),
      ],
    );

    final inner = expanded ? row : IntrinsicWidth(child: row);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.md),
        color: colorScheme.onSurface.withAlpha(13),
      ),
      padding: const EdgeInsets.all(2),
      child: inner,
    );
  }
}

class _SegmentedButton<T> extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? backgroundColor;
  final bool isSelected;
  final bool expanded;
  final VoidCallback onTap;

  const _SegmentedButton({
    required this.label,
    this.color,
    this.backgroundColor,
    required this.isSelected,
    required this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colored = color != null;

    final child = Semantics(
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: _decoration(colorScheme, colored),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textColor(colorScheme, colored),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (expanded) return Expanded(child: child);
    return child;
  }

  BoxDecoration _decoration(ColorScheme colorScheme, bool colored) {
    if (!colored) {
      return BoxDecoration(
        color: isSelected ? colorScheme.surface : colorScheme.surface.withAlpha(0),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withAlpha(13),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      );
    }

    final bg = backgroundColor ?? color!.withAlpha(38);
    return BoxDecoration(
      color: isSelected ? bg : colorScheme.surface.withAlpha(0),
      borderRadius: BorderRadius.circular(AppRadii.sm),
    );
  }

  Color _textColor(ColorScheme colorScheme, bool colored) {
    if (!colored) {
      return isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant;
    }
    return color!;
  }
}
