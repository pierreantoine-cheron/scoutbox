import 'package:flutter/material.dart';

import 'state_badge.dart';

class StateSelector<T> extends StatelessWidget {
  final List<T> values;
  final T selectedValue;
  final bool enabled;
  final String tooltip;
  final StateBadgeStyle Function(BuildContext context, T value) styleFor;
  final Widget Function(BuildContext context, T value) selectedBadgeBuilder;
  final void Function(T value) onSelected;

  const StateSelector({
    super.key,
    required this.values,
    required this.selectedValue,
    required this.styleFor,
    required this.selectedBadgeBuilder,
    required this.onSelected,
    this.enabled = true,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      enabled: enabled,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      splashRadius: 1,
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == selectedValue) {
          return;
        }
        onSelected(value);
      },
      itemBuilder: (context) {
        return values.map((value) {
          final style = styleFor(context, value);
          final isCurrent = value == selectedValue;
          return PopupMenuItem<T>(
            value: value,
            enabled: !isCurrent,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 16, color: style.foreground),
                      const SizedBox(width: 6),
                      Text(
                        style.label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: style.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            selectedBadgeBuilder(context, selectedValue),
            if (enabled) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
