import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../utils/app_colors.dart';

class TentTagFilterSheet extends StatefulWidget {
  final List<Tag> tags;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onClearAll;

  const TentTagFilterSheet({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.onToggleTag,
    required this.onClearAll,
  });

  @override
  State<TentTagFilterSheet> createState() => _TentTagFilterSheetState();
}

class _TentTagFilterSheetState extends State<TentTagFilterSheet> {
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    final visibleTags = _visibleTags();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filtrer par étiquettes',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: widget.selectedTagIds.isEmpty
                      ? null
                      : widget.onClearAll,
                  child: const Text('Effacer tout'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Rechercher une étiquette',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() => _searchText = value.trim().toLowerCase());
              },
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in visibleTags)
                      _TagFilterChip(
                        tag: tag,
                        selected: widget.selectedTagIds.contains(tag.id),
                        onSelected: () => widget.onToggleTag(tag.id),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Tag> _visibleTags() {
    final tags = widget.tags
        .where((tag) => tag.name.toLowerCase().contains(_searchText))
        .toList();
    tags.sort((left, right) {
      final countCompare = right.tentCount.compareTo(left.tentCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return tags;
  }
}

class _TagFilterChip extends StatelessWidget {
  final Tag tag;
  final bool selected;
  final VoidCallback onSelected;

  const _TagFilterChip({
    required this.tag,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tagColor = TagPalette.colorFromHex(tag.color);

    return FilterChip(
      avatar: CircleAvatar(backgroundColor: tagColor),
      label: Text('${tag.name} (${tag.tentCount})'),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
