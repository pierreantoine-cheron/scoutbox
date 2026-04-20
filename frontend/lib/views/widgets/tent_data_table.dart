import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/tent.dart';

enum TentDesktopSortColumn { name, state, size, shape, updatedAt }

class TentDataTable extends StatefulWidget {
  final List<Tent> tents;
  final ValueChanged<Tent> onOpenTent;

  const TentDataTable({
    super.key,
    required this.tents,
    required this.onOpenTent,
  });

  @override
  State<TentDataTable> createState() => _TentDataTableState();
}

class _TentDataTableState extends State<TentDataTable> {
  static final _updatedAtFormatter = DateFormat('dd/MM/yyyy HH:mm');
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

    return DataTable2(
      fixedTopRows: 1,
      fixedLeftColumns: 1,
      minWidth: 980,
      sortColumnIndex: _sortColumn?.index,
      sortAscending: _sortAscending,
      columns: [
        DataColumn2(
          label: const Text('Nom'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.name),
          size: ColumnSize.L,
        ),
        DataColumn2(
          label: const Text('Etat'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.state),
          size: ColumnSize.M,
        ),
        DataColumn2(
          numeric: true,
          label: const Text('Taille'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.size),
          size: ColumnSize.S,
        ),
        DataColumn2(
          label: const Text('Forme'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.shape),
          size: ColumnSize.M,
        ),
        DataColumn2(
          label: const Text('Derniere mise a jour'),
          onSort: (_, _) => _toggleSort(TentDesktopSortColumn.updatedAt),
          size: ColumnSize.M,
        ),
      ],
      rows: [for (final tent in tents) _buildDataRow(context, tent)],
      empty: const Center(child: Text('Aucune tente disponible')),
    );
  }

  DataRow2 _buildDataRow(BuildContext context, Tent tent) {
    return DataRow2(
      onTap: () => widget.onOpenTent(tent),
      cells: [
        DataCell(
          _RowActivationCell(
            label: tent.name,
            onActivate: () => widget.onOpenTent(tent),
          ),
        ),
        DataCell(Text(tent.overallState.toFrenchLabel())),
        DataCell(Text(tent.size == 1 ? '1 place' : '${tent.size} places')),
        DataCell(_EllipsisCell(value: tent.tentShapeName)),
        DataCell(Text(tent.toFrenchUpdatedAtLabel(_updatedAtFormatter))),
      ],
    );
  }

  List<Tent> _sortedTents(List<Tent> tents) {
    final column = _sortColumn;
    if (column == null) {
      return tents;
    }

    final copy = [...tents];
    copy.sort((left, right) {
      final result = switch (column) {
        TentDesktopSortColumn.name => left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        ),
        TentDesktopSortColumn.state => _compareState(left, right),
        TentDesktopSortColumn.size => left.size.compareTo(right.size),
        TentDesktopSortColumn.shape => _compareNullableText(
          left.tentShapeName,
          right.tentShapeName,
        ),
        TentDesktopSortColumn.updatedAt => _compareNullableDate(
          left.updatedAt,
          right.updatedAt,
        ),
      };
      return _sortAscending ? result : -result;
    });

    return copy;
  }

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

    return leftValue.toLowerCase().compareTo(rightValue.toLowerCase());
  }

  int _compareNullableDate(DateTime? left, DateTime? right) {
    if (left == null && right == null) {
      return 0;
    }
    if (left == null) {
      return 1;
    }
    if (right == null) {
      return -1;
    }

    return left.compareTo(right);
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
    final displayValue = normalized == null || normalized.isEmpty
        ? '-'
        : normalized;

    return Tooltip(
      message: displayValue,
      child: Text(displayValue, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _RowActivationCell extends StatelessWidget {
  final String label;
  final VoidCallback onActivate;

  const _RowActivationCell({required this.label, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: FocusableActionDetector(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onActivate();
              return null;
            },
          ),
        },
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
