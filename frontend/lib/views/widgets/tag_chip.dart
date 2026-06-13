import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';

class TagChip extends StatelessWidget {
  final String name;
  final Color color;
  final int? tentCount;

  const TagChip({
    super.key,
    required this.name,
    required this.color,
    this.tentCount,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = TagPalette.textColorFor(color);
    final label = tentCount == null
        ? name
        : '$name · $tentCount tente${tentCount! > 1 ? 's' : ''}';

    return Chip(
      avatar: CircleAvatar(backgroundColor: color, radius: 8),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.18),
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w600),
    );
  }
}

class SelectableTagChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;

  const SelectableTagChip({
    super.key,
    required this.name,
    required this.color,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
