import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../utils/app_colors.dart';
import 'scout_pill.dart';

enum TentTagChipsMode { compact }

class TentTagChips extends StatelessWidget {
  final List<Tag> tags;
  final int maxVisible;
  final TentTagChipsMode mode;
  final ValueChanged<String>? onTagTap;

  const TentTagChips({
    super.key,
    required this.tags,
    this.maxVisible = 3,
    this.mode = TentTagChipsMode.compact,
    this.onTagTap,
  }) : assert(maxVisible > 0, 'maxVisible must be greater than 0');

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleTags = tags.take(maxVisible).toList();
    final hiddenTags = tags.skip(maxVisible).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in visibleTags) ...[
          Flexible(
            child: ScoutPill.tag(
              label: tag.name,
              color: TagPalette.colorFromHex(tag.color),
              variant: ScoutPillVariant.compact,
              onTap: onTagTap != null ? () => onTagTap!(tag.id) : null,
              semanticLabel: 'Étiquette : ${tag.name}',
            ),
          ),
          if (tag != visibleTags.last || hiddenTags.isNotEmpty)
            const SizedBox(width: 4),
        ],
        if (hiddenTags.isNotEmpty) _OverflowTagChip(tags: hiddenTags),
      ],
    );
  }
}


class _OverflowTagChip extends StatelessWidget {
  final List<Tag> tags;

  const _OverflowTagChip({required this.tags});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hiddenNames = tags.map((tag) => tag.name).join(', ');
    final countLabel = '+${tags.length}';
    final plural = tags.length > 1 ? 'étiquettes' : 'étiquette';

    return Tooltip(
      message: 'Étiquettes masquées : $hiddenNames',
      child: Semantics(
        label: '$countLabel $plural : $hiddenNames',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
