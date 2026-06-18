import '../../models/tent.dart';

enum TentDesktopSortColumn { name, state, size, model }

const _stateOrder = {
  TentOverallState.good: 0,
  TentOverallState.needsRepair: 1,
  TentOverallState.unusable: 2,
};

List<Tent> sortTents(
  List<Tent> tents, {
  TentDesktopSortColumn? column,
  bool ascending = true,
}) {
  if (column == null) return tents;

  final copy = [...tents];
  copy.sort((left, right) {
    final cmp = switch (column) {
      TentDesktopSortColumn.name =>
          left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      TentDesktopSortColumn.state => _compareState(left, right),
      TentDesktopSortColumn.size => left.size.compareTo(right.size),
      TentDesktopSortColumn.model =>
          _compareNullableText(left.tentModelName, right.tentModelName),
    };
    return ascending ? cmp : -cmp;
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

  if (leftMissing && rightMissing) return 0;
  if (leftMissing) return 1;
  if (rightMissing) return -1;

  return leftValue.toLowerCase().compareTo(rightValue.toLowerCase());
}
