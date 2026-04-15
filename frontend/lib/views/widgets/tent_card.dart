import 'package:flutter/material.dart';

import '../../models/tent.dart';

class TentCard extends StatelessWidget {
  final Tent tent;
  final VoidCallback onTap;

  const TentCard({super.key, required this.tent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final shapeName = tent.tentShapeName?.trim();
    final hasShapeName = shapeName != null && shapeName.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Tente ${tent.name}',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tent.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StateBadge(state: tent.overallState),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Taille: ${tent.size}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (hasShapeName) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Forme: $shapeName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 8),
                const SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Voir le detail'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  final TentOverallState state;

  const _StateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (state) {
      TentOverallState.good => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
      ),
      TentOverallState.needsRepair => (
        Colors.orange.shade100,
        Colors.orange.shade900,
      ),
      TentOverallState.unusable => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.toFrenchLabel(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
