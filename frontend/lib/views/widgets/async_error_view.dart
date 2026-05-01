import 'package:flutter/material.dart';

class AsyncErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final bool isRetrying;
  final bool centered;

  const AsyncErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.isRetrying = false,
    this.centered = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: isRetrying ? null : onRetry,
            icon: isRetrying
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ],
    );

    if (centered) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: content,
    );
  }
}
