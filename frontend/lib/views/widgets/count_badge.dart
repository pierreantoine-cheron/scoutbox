import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class CountBadge extends StatelessWidget {
  final int count;
  final String label;

  const CountBadge({super.key, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$count $label${count > 1 ? 's' : ''}',
      style: AppTheme.monoCaption,
    );
  }
}
