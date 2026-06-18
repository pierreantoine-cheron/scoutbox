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

