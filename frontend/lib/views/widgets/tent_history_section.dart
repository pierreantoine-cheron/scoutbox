import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../utils/error_messages.dart';
import 'search_field.dart';
import 'app_progress_indicator.dart';
import 'async_error_view.dart';

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
              child: Center(child: AppProgressIndicator()),
            ),
            error: (error, _) => AsyncErrorView(
              message: _toHistoryErrorMessage(error),
              centered: false,
              onRetry: () => ref.invalidate(
                tentHistoryProvider(
                  widget.tentId,
                  category: _selectedCategory,
                ),
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
    return item.buildSummary();
  }

  String _toHistoryErrorMessage(Object error) {
    return toUserFacingError(error, 'Impossible de charger l\'historique.');
  }
}

class _CompactHistoryItem extends StatelessWidget {
  final TentHistoryItem item;

  const _CompactHistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = TentHistoryItem.actionIcon(item.action);
    final dotColor = TentHistoryItem.actionDotColor(item.action, theme.colorScheme);
    final time = DateFormat('HH:mm', 'fr').format(item.occurredAt.toLocal());
    final date = DateFormat('dd/MM/yyyy', 'fr').format(item.occurredAt.toLocal());
    final summarySpan = item.buildSummarySpan(context);

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
                Text.rich(
                  summarySpan,
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

