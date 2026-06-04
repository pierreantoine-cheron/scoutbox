import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../repositories/tent_repository.dart';
import 'state_badge.dart';

class TentHistorySection extends ConsumerStatefulWidget {
  final String tentId;

  const TentHistorySection({super.key, required this.tentId});

  @override
  ConsumerState<TentHistorySection> createState() => _TentHistorySectionState();
}

class _TentHistorySectionState extends ConsumerState<TentHistorySection> {
  String? _selectedCategory;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher dans l\'historique',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
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
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Chargement de l\'historique...'),
                    ],
                  ),
                ),
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
              data: (items) {
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

                final grouped = _groupByDate(filtered);
                return _HistoryList(grouped: grouped);
              },
            ),
          ],
        ),
      ),
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

  Map<String, List<TentHistoryItem>> _groupByDate(List<TentHistoryItem> items) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayFormatter = DateFormat('d MMMM yyyy', 'fr');

    final grouped = <String, List<TentHistoryItem>>{};
    for (final item in items) {
      final localDate = item.occurredAt.toLocal();
      final itemDay = DateTime(localDate.year, localDate.month, localDate.day);
      String label;
      if (itemDay == today) {
        label = "Aujourd'hui";
      } else if (itemDay == yesterday) {
        label = 'Hier';
      } else {
        label = dayFormatter.format(localDate);
      }
      grouped.putIfAbsent(label, () => []).add(item);
    }
    return grouped;
  }
}

class _FilterOption {
  final String label;
  final String? value;
  const _FilterOption({required this.label, this.value});
}

class _HistoryList extends StatelessWidget {
  final Map<String, List<TentHistoryItem>> grouped;

  const _HistoryList({required this.grouped});

  @override
  Widget build(BuildContext context) {
    final entries = grouped.entries.toList();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            ...entry.value.map((item) => _HistoryEntry(item: item)),
          ],
        );
      },
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  final TentHistoryItem item;

  const _HistoryEntry({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = _actionIcon(item.action);
    final time = DateFormat('HH:mm', 'fr').format(item.occurredAt.toLocal());
    final summary = _buildHistorySummary(item);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(icon, size: 20, color: colorScheme.primary),
        title: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
        subtitle: Text(
          '$time • ${item.actorDisplayName}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        enabled: item.details.isNotEmpty,
        children: item.details.map((detail) {
          return _buildDetail(context, detail);
        }).toList(),
      ),
    );
  }

  Widget _buildDetail(BuildContext context, TentHistoryDetail detail) {
    final colorScheme = Theme.of(context).colorScheme;

    if (detail.valueType == 'state' || detail.valueType == 'old_new') {
      final hasOldNew = detail.oldValue != null && detail.newValue != null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: [
            Text(
              '${detail.label}:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (hasOldNew) ...[
              _buildStateValue(context, detail.oldValue),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.arrow_forward, size: 14),
              ),
              _buildStateValue(context, detail.newValue),
            ] else
              Text(
                detail.value ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      );
    }

    if (detail.valueType == 'flag') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          detail.value ?? '',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: colorScheme.outline,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        '${detail.label}: ${detail.value ?? detail.newValue ?? detail.oldValue ?? ''}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildStateValue(BuildContext context, String? value) {
    if (value == null) return const Text('-');

    final parsedPartState = PartState.values
        .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
        .firstOrNull;

    if (parsedPartState != null) {
      return StateBadge.forPart(context, parsedPartState);
    }

    final parsedTentState = TentOverallState.values
        .where((s) => s.toApiValue() == value || s.toFrenchLabel() == value)
        .firstOrNull;

    if (parsedTentState != null) {
      return StateBadge.forTent(context, parsedTentState);
    }

    return Text(value);
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
}

String _buildHistorySummary(TentHistoryItem item) {
  final localDate = item.occurredAt.toLocal();
  final date = DateFormat('dd/MM/yyyy', 'fr').format(localDate);
  final time = DateFormat('HH:mm', 'fr').format(localDate);
  final suffix = 'le $date à $time par ${item.actorDisplayName}';
  final subject = item.subjectName ?? 'Pièce inconnue';

  switch (item.action) {
    case 'tent_created':
      return 'Tente créée $suffix';
    case 'tent_updated':
      return 'Informations mises à jour $suffix';
    case 'tent_archived':
      return 'Tente archivée $suffix';
    case 'part_state_changed':
      final stateDetail = item.details
          .where((d) => d.valueType == 'state')
          .firstOrNull;
      final oldState = _historyStateLabel(stateDetail?.oldValue);
      final newState = _historyStateLabel(stateDetail?.newValue);
      return 'État de $subject changé de $oldState à $newState $suffix';
    case 'part_comments_changed':
      return 'Commentaire de $subject modifié $suffix';
    case 'part_added':
      return 'Pièce ajoutée : $subject $suffix';
    case 'part_deleted':
      return 'Pièce supprimée : $subject $suffix';
    case 'tag_assigned':
      return 'Étiquette ajoutée : $subject $suffix';
    case 'tag_removed':
      return 'Étiquette retirée : $subject $suffix';
    default:
      return 'Action ${item.action} $suffix';
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
