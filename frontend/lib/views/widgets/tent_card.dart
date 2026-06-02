import 'package:flutter/material.dart';

import '../../models/tent.dart';
import 'state_badge.dart';
import 'tent_tag_chips.dart';

class TentCard extends StatelessWidget {
  final Tent tent;
  final VoidCallback onTap;

  const TentCard({super.key, required this.tent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final modelName = tent.tentModelName?.trim();
    final hasModelName = modelName != null && modelName.isNotEmpty;

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
                    StateBadge.forTent(context, tent.overallState),
                  ],
                ),
                if (tent.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  TentTagChips(tags: tent.tags),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      tent.size == 1
                          ? '${tent.size} place'
                          : '${tent.size} places',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),

                    if (hasModelName) ...[
                      const SizedBox(height: 6),
                      Text(
                        modelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
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
