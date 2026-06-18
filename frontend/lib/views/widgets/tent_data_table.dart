import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../models/tent.dart';
import '../../utils/app_colors.dart';
import '../../utils/tent_sort.dart';
import 'scout_pill.dart';
import 'state_badge.dart';
import 'tent_tag_chips.dart';

class TentDataTable extends StatefulWidget {
  final List<Tent> tents;
  final ValueChanged<Tent> onOpenTent;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<TentOverallState>? onStateTap;

  const TentDataTable({
    super.key,
    required this.tents,
    required this.onOpenTent,
    this.onTagTap,
    this.onStateTap,
  });

  @override
  State<TentDataTable> createState() => _TentDataTableState();
}

class _TentDataTableState extends State<TentDataTable> {
  TentDesktopSortColumn? _sortColumn;
  bool _sortAscending = true;

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.55,
    color: AppColors.muted,
  );

  static const _nameStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.075,
  );

  @override
  Widget build(BuildContext context) {
    final tents = sortTents(
      widget.tents,
      column: _sortColumn,
      ascending: _sortAscending,
    );
    final colorScheme = Theme.of(context).colorScheme;

    if (tents.isEmpty) {
      return Material(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        child: _EmptyTableState(),
      );
    }

    return Material(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(130),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(100),
          3: FixedColumnWidth(130),
          4: FlexColumnWidth(),
        },
        children: [
          _buildHeaderRow(colorScheme),
          for (final tent in tents)
            _buildDataRow(context, tent, colorScheme),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow(ColorScheme colorScheme) {
    return TableRow(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      children: [
        _SortableHeaderCell(
          label: 'État',
          isActive: _sortColumn == TentDesktopSortColumn.state,
          ascending: _sortAscending,
          onTap: () => _toggleSort(TentDesktopSortColumn.state),
        ),
        _SortableHeaderCell(
          label: 'Nom',
          isActive: _sortColumn == TentDesktopSortColumn.name,
          ascending: _sortAscending,
          onTap: () => _toggleSort(TentDesktopSortColumn.name),
        ),
        _SortableHeaderCell(
          label: 'Taille',
          isActive: _sortColumn == TentDesktopSortColumn.size,
          ascending: _sortAscending,
          onTap: () => _toggleSort(TentDesktopSortColumn.size),
        ),
        _SortableHeaderCell(
          label: 'Modèle',
          isActive: _sortColumn == TentDesktopSortColumn.model,
          ascending: _sortAscending,
          onTap: () => _toggleSort(TentDesktopSortColumn.model),
        ),
        const _HeaderCell(label: 'Étiquettes'),
      ],
    );
  }

  TableRow _buildDataRow(BuildContext context, Tent tent, ColorScheme colorScheme) {
    void onTap() => widget.onOpenTent(tent);

    return TableRow(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
      ),
      children: [
        _DataCell(
          onTap: onTap,
          child: ScoutPill.stateCompact(
            style: tentStateBadgeStyle(context, tent.overallState),
            onTap: widget.onStateTap != null
                ? () => widget.onStateTap!(tent.overallState)
                : null,
            semanticLabel: 'État : ${tent.overallState.toFrenchLabel()}',
          ),
        ),
        _DataCell(
          onTap: onTap,
          child: Text(
            tent.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _nameStyle,
          ),
        ),
        _DataCell(
          onTap: onTap,
          child: Text(tent.size == 1 ? '1 pl.' : '${tent.size} pl.'),
        ),
        _DataCell(
          onTap: onTap,
          child: _EllipsisCell(value: tent.tentModelName),
        ),
        _DataCell(
          onTap: onTap,
          last: true,
          child: _TagsCell(tags: tent.tags, onTagTap: widget.onTagTap),
        ),
      ],
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

class _SortableHeaderCell extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool ascending;
  final VoidCallback onTap;

  const _SortableHeaderCell({
    required this.label,
    required this.isActive,
    required this.ascending,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const headerStyle = _TentDataTableState._headerStyle;
    const arrowSize = 12.0;

    return _DataCell(
      onTap: onTap,
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label, style: headerStyle, overflow: TextOverflow.ellipsis),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: arrowSize,
                color: AppColors.muted,
              ),
            ],
          ],
        ),
      );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;

  const _HeaderCell({required this.label});

  @override
  Widget build(BuildContext context) {
    return _DataCell(
      child: Text(label, style: _TentDataTableState._headerStyle),
    );
  }
}

class _DataCell extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool last;

  const _DataCell({
    required this.child,
    this.onTap,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: child,
      ),
    );
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

