import 'package:flutter/material.dart';

import 'app_progress_indicator.dart';

class PrimarySubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final IconData? icon;

  const PrimarySubmitButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveEnabled = enabled && !isLoading;

    final style = ElevatedButton.styleFrom(
      backgroundColor: colorScheme.primary,
      disabledBackgroundColor: colorScheme.outlineVariant,
      foregroundColor: Colors.white,
      disabledForegroundColor: colorScheme.onSurfaceVariant,
    );

    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: AppProgressIndicator(color: Colors.white),
          )
        : Text(label);

    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: effectiveEnabled ? onPressed : null,
        style: style,
        icon: Icon(icon, size: 18),
        label: child,
      );
    }

    return ElevatedButton(
      onPressed: effectiveEnabled ? onPressed : null,
      style: style,
      child: child,
    );
  }
}
