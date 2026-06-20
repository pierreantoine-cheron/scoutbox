import 'package:flutter/material.dart';

import '../../models/tent.dart';
import 'scout_pill.dart';
import 'state_badge.dart';
import 'tent_tag_chips.dart';

class TentCard extends StatelessWidget {
  final Tent tent;
  final VoidCallback onTap;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<TentOverallState>? onStateTap;

  const TentCard({
    super.key,
    required this.tent,
    required this.onTap,
    this.onTagTap,
    this.onStateTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelName = tent.tentModelName?.trim();
    final hasModelName = modelName != null && modelName.isNotEmpty;
    final hasTags = tent.tags.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Tente ${tent.name}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Material(
          color: tent.isArchived
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScoutPill.stateCompact(
                    style: tentStateBadgeStyle(context, tent.overallState),
                    onTap: onStateTap != null ? () => onStateTap!(tent.overallState) : null,
                    semanticLabel: 'État : ${tent.overallState.toFrenchLabel()}',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tent.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.17,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _MetaRow(
                          modelName: hasModelName ? modelName : null,
                          size: tent.size,
                        ),
                        if (hasTags) ...[
                          const SizedBox(height: 9),
                          TentTagChips(tags: tent.tags, onTagTap: onTagTap),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String? modelName;
  final int size;

  const _MetaRow({this.modelName, required this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (modelName != null) ...[
          Icon(Icons.cabin, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              modelName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Icon(Icons.people_outline, size: 13, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          '$size pl.',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
