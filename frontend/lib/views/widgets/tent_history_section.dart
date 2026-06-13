import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import 'search_field.dart';

class _FilterOption {
  final String label;
  final String? value;
  const _FilterOption({required this.label, required this.value});
}

class TentHistorySection extends ConsumerStatefulWidget {
  final String tentId;

  const TentHistorySection({super.key, required this.tentId});

  @override
  ConsumerState<TentHistorySection> createState() => _TentHistorySectionState();
}

class _TentHistorySectionState extends ConsumerState<TentHistorySection> {
  String? _selectedCategory;
  String _searchQuery = '';
  bool _isExpanded = false;
  final _searchController = TextEditingController();
  static const int _collapsedCount = 3;

  static const _categories = <_FilterOption>[
    _FilterOption(label: 'Tout', value: null),
    _FilterOption(label: 'Tente', value: 'tent_info'),
    _FilterOption(label: 'États', value: 'part_state'),
    _FilterOption(label: 'Pièces', value: 'part_management'),
    _FilterOption(label: 'Étiquettes', value: 'tags'),
    _FilterOption(label: 'Archive', value: 'archive'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      tentHistoryProvider(widget.tentId, category: _selectedCategory),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat.value;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategory = selected ? cat.value : null;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          SearchField(
            controller: _searchController,
            hintText: 'Rechercher dans l\'historique',
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
          const SizedBox(height: 12),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _toHistoryErrorMessage(error),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(
                      tentHistoryProvider(
                        widget.tentId,
                        category: _selectedCategory,
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
            data: (items) => _buildHistoryList(items),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<TentHistoryItem> items) {
    final filtered = items.where((item) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery;
      return _historySummary(item).toLowerCase().contains(query) ||
          item.actorDisplayName.toLowerCase().contains(query) ||
          item.action.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('Aucun historique à afficher.')),
      );
    }

    final reversed = filtered.toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final displayed =
        _isExpanded ? reversed : reversed.take(_collapsedCount).toList();
    final hasMore = reversed.length > _collapsedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...displayed.map((item) => _CompactHistoryItem(item: item)),
        if (hasMore)
          TextButton.icon(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            icon: Icon(
              _isExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              size: 16,
            ),
            label: Text(
              _isExpanded ? 'Réduire' : 'Afficher tout',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.only(top: 8),
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }

  String _historySummary(TentHistoryItem item) {
    return _buildHistorySummary(item);
  }

  String _toHistoryErrorMessage(Object error) {
    if (error is TentRepositoryException) {
      return error.message;
    }
    return 'Impossible de charger l\'historique.';
  }
}

class _CompactHistoryItem extends StatelessWidget {
  final TentHistoryItem item;

  const _CompactHistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = _actionIcon(item.action);
    final dotColor = _actionDotColor(item.action, theme);
    final time = DateFormat('HH:mm', 'fr').format(item.occurredAt.toLocal());
    final date = DateFormat('dd/MM/yyyy', 'fr').format(item.occurredAt.toLocal());
    final summary = _buildHistorySummary(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: dotColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '$date • $time • ${item.actorDisplayName}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _actionDotColor(String action, ThemeData theme) {
  switch (action) {
    case 'tent_created':
      return theme.colorScheme.primary;
    case 'tent_updated':
      return theme.colorScheme.primary;
    case 'tent_archived':
      return theme.colorScheme.error;
    case 'part_state_changed':
      return theme.colorScheme.tertiary;
    case 'part_comments_changed':
      return theme.colorScheme.primary;
    case 'part_added':
      return theme.colorScheme.tertiary;
    case 'part_deleted':
      return theme.colorScheme.error;
    case 'tag_assigned':
    case 'tag_removed':
      return theme.colorScheme.secondary;
    default:
      return theme.colorScheme.outline;
  }
}

IconData _actionIcon(String action) {
  switch (action) {
    case 'tent_created':
      return Icons.add_circle_outline;
    case 'tent_updated':
      return Icons.edit_outlined;
    case 'tent_archived':
      return Icons.archive_outlined;
    case 'part_state_changed':
      return Icons.swap_horiz;
    case 'part_comments_changed':
      return Icons.comment_outlined;
    case 'part_added':
      return Icons.add_box_outlined;
    case 'part_deleted':
      return Icons.remove_circle_outline;
    case 'tag_assigned':
      return Icons.label_outlined;
    case 'tag_removed':
      return Icons.label_off_outlined;
    default:
      return Icons.info_outline;
  }
}

String _buildHistorySummary(TentHistoryItem item) {
  final subject = item.subjectName ?? 'Pièce inconnue';

  switch (item.action) {
    case 'tent_created':
      return 'Tente créée';
    case 'tent_updated':
      return 'Informations mises à jour';
    case 'tent_archived':
      return 'Tente archivée';
    case 'part_state_changed':
      final stateDetail =
          item.details.where((d) => d.valueType == 'state').firstOrNull;
      final oldState = _historyStateLabel(stateDetail?.oldValue);
      final newState = _historyStateLabel(stateDetail?.newValue);
      return 'État de $subject changé de $oldState à $newState';
    case 'part_comments_changed':
      return 'Commentaire de $subject modifié';
    case 'part_added':
      return 'Pièce ajoutée : $subject';
    case 'part_deleted':
      return 'Pièce supprimée : $subject';
    case 'tag_assigned':
      return 'Étiquette ajoutée : $subject';
    case 'tag_removed':
      return 'Étiquette retirée : $subject';
    default:
      return 'Action ${item.action}';
  }
}

String _historyStateLabel(String? value) {
  if (value == null || value.isEmpty) return '?';

  final partState = PartState.values
      .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
      .firstOrNull;
  if (partState != null) return partState.toFrenchLabel();

  final tentState = TentOverallState.values
      .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
      .firstOrNull;
  if (tentState != null) return tentState.toFrenchLabel();

  return value;
}
