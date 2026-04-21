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
      rows: [
        for (var index = 0; index < tents.length; index++)
          _buildDataRow(context, tents[index], autofocus: index == 0),
      ],
      empty: const Center(child: Text('Aucune tente disponible')),
    );
  }

  DataRow2 _buildDataRow(
    BuildContext context,
    Tent tent, {
    required bool autofocus,
  }) {
    return DataRow2(
      onTap: () => widget.onOpenTent(tent),
      cells: [
        DataCell(
          _RowActivationCell(
            label: tent.name,
            onActivate: () => widget.onOpenTent(tent),
            semanticsHint: 'Ouvrir le détail de la tente',
            autofocus: autofocus,
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
        TentDesktopSortColumn.shape => _compareNullableText(
          left.tentShapeName,
          right.tentShapeName,
        ),
        TentDesktopSortColumn.updatedAt => _compareNullableDate(
          left.updatedAt,
          right.updatedAt,
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

    return _applySortDirection(left.compareTo(right));
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

class _RowActivationCell extends StatefulWidget {
  final String label;
  final VoidCallback onActivate;
  final String semanticsHint;
  final bool autofocus;

  const _RowActivationCell({
    required this.label,
    required this.onActivate,
    required this.semanticsHint,
    required this.autofocus,
  });

  @override
  State<_RowActivationCell> createState() => _RowActivationCellState();
}

class _RowActivationCellState extends State<_RowActivationCell> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        hint: widget.semanticsHint,
        child: FocusableActionDetector(
          autofocus: widget.autofocus,
          onShowFocusHighlight: (value) {
            if (_isFocused == value) {
              return;
            }

            setState(() {
              _isFocused = value;
            });
          },
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onActivate();
                return null;
              },
            ),
          },
          child: Material(
            color: _isFocused
                ? colorScheme.secondaryContainer
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: _isFocused ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: InkWell(
              key: ValueKey('tent-row-activator-${widget.label}'),
              onTap: widget.onActivate,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
