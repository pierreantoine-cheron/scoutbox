import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../utils/app_colors.dart';

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
            child: _CompactTagChip(tag: tag, onTagTap: onTagTap),
          ),
          if (tag != visibleTags.last || hiddenTags.isNotEmpty)
            const SizedBox(width: 4),
        ],
        if (hiddenTags.isNotEmpty) _OverflowTagChip(tags: hiddenTags),
      ],
    );
  }
}

class _CompactTagChip extends StatelessWidget {
  final Tag tag;
  final ValueChanged<String>? onTagTap;

  const _CompactTagChip({required this.tag, this.onTagTap});

  @override
  Widget build(BuildContext context) {
    final tagColor = TagPalette.colorFromHex(tag.color);
    final textColor = TagPalette.textColorFor(tagColor);

    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tag.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    return Tooltip(
      message: tag.name,
      child: Semantics(
        label: 'Étiquette : ${tag.name}',
        button: onTagTap != null,
        child: ExcludeSemantics(
          child: onTagTap == null
              ? chip
              : InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onTagTap!(tag.id),
                  child: chip,
                ),
        ),
      ),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Text(
              countLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
