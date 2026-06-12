import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../models/tent.dart';
import 'compact_state_badge.dart';
import 'tent_tag_chips.dart';

enum TentDesktopSortColumn { name, state, size, model }

class TentDataTable extends StatefulWidget {
  final List<Tent> tents;
  final ValueChanged<Tent> onOpenTent;
  final ValueChanged<String>? onTagTap;

  const TentDataTable({
    super.key,
    required this.tents,
    required this.onOpenTent,
    this.onTagTap,
  });

  @override
  State<TentDataTable> createState() => _TentDataTableState();
}

class _TentDataTableState extends State<TentDataTable> {
  static const _stateOrder = {
    TentOverallState.good: 0,
    TentOverallState.needsRepair: 1,
    TentOverallState.unusable: 2,
  };

  TentDesktopSortColumn? _sortColumn;
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final tents = _sortedTents(widget.tents);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable2(
        sortColumnIndex: _sortColumn == null ? null : _sortIndexFor(_sortColumn!),
      sortAscending: _sortAscending,
      columns: [
        DataColumn2(
          label: const Text('État'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.state),
          size: ColumnSize.M,
          fixedWidth: 140,
        ),
        DataColumn2(
          label: const Text('Nom'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.name),
          size: ColumnSize.L,
        ),
        DataColumn2(
          numeric: true,
          label: const Text('Taille'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.size),
          size: ColumnSize.S,
        ),
        DataColumn2(
          label: const Text('Modèle'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.model),
          size: ColumnSize.M,
        ),
        const DataColumn2(label: Text('Étiquettes'), size: ColumnSize.M),
      ],
      rows: [for (final tent in tents) _buildDataRow(context, tent)],
        empty: _EmptyTableState(),
      ),
    );
  }

  DataRow2 _buildDataRow(BuildContext context, Tent tent) {
    return DataRow2(
      onTap: () => widget.onOpenTent(tent),
      cells: [
        DataCell(CompactStateBadge.forTent(context, tent.overallState)),
        DataCell(
          Text(
            tent.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.075,
            ),
          ),
        ),
        DataCell(Text(tent.size == 1 ? '1 pl.' : '${tent.size} pl.')),
        DataCell(_EllipsisCell(value: tent.tentModelName)),
        DataCell(_TagsCell(tags: tent.tags, onTagTap: widget.onTagTap)),
      ],
    );
  }

  int _sortIndexFor(TentDesktopSortColumn column) {
    return switch (column) {
      TentDesktopSortColumn.state => 0,
      TentDesktopSortColumn.name => 1,
      TentDesktopSortColumn.size => 2,
      TentDesktopSortColumn.model => 3,
    };
  }

  List<Tent> _sortedTents(List<Tent> tents) {
    final column = _sortColumn;
    if (column == null) {
      return tents;
    }

    final copy = [...tents];
    copy.sort((left, right) {
      return switch (column) {
        TentDesktopSortColumn.name => _applySortDirection(
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          ),
        TentDesktopSortColumn.state => _applySortDirection(
            _compareState(left, right),
          ),
        TentDesktopSortColumn.size => _applySortDirection(
            left.size.compareTo(right.size),
          ),
        TentDesktopSortColumn.model => _compareNullableText(
            left.tentModelName,
            right.tentModelName,
          ),
      };
    });

    return copy;
  }

  int _applySortDirection(int value) => _sortAscending ? value : -value;

  int _compareState(Tent left, Tent right) {
    final leftRank = _stateOrder[left.overallState] ?? 99;
    final rightRank = _stateOrder[right.overallState] ?? 99;
    return leftRank.compareTo(rightRank);
  }

  int _compareNullableText(String? left, String? right) {
    final leftValue = left?.trim();
    final rightValue = right?.trim();
    final leftMissing = leftValue == null || leftValue.isEmpty;
    final rightMissing = rightValue == null || rightValue.isEmpty;

    if (leftMissing && rightMissing) {
      return 0;
    }
    if (leftMissing) {
      return 1;
    }
    if (rightMissing) {
      return -1;
    }

    return _applySortDirection(
      leftValue.toLowerCase().compareTo(rightValue.toLowerCase()),
    );
  }

  void _toggleSort(TentDesktopSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }
}

class _EllipsisCell extends StatelessWidget {
  final String? value;

  const _EllipsisCell({required this.value});

  @override
  Widget build(BuildContext context) {
    final normalized = value?.trim();
    final displayValue =
        normalized == null || normalized.isEmpty ? '-' : normalized;

    return Tooltip(
      message: displayValue,
      child: Text(displayValue, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _TagsCell extends StatelessWidget {
  final List<Tag> tags;
  final ValueChanged<String>? onTagTap;

  const _TagsCell({required this.tags, this.onTagTap});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text('-');
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: TentTagChips(tags: tags, onTagTap: onTagTap),
    );
  }
}

class _EmptyTableState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cabin, size: 48, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'Aucune tente trouvée',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Essayez d\'ajuster vos filtres ou d\'en créer une nouvelle.',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
