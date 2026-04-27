import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';

part 'tent_filter_provider.g.dart';

class TentListFilterState {
  final String searchText;
  final String effectiveSearchText;
  final Set<TentOverallState> selectedStates;
  final Set<int> selectedSizes;
  final Set<String> selectedShapeIds;

  const TentListFilterState({
    this.searchText = '',
    this.effectiveSearchText = '',
    this.selectedStates = const {},
    this.selectedSizes = const {},
    this.selectedShapeIds = const {},
  });

  bool get isFilteredMode =>
      selectedStates.isNotEmpty ||
      selectedSizes.isNotEmpty ||
      selectedShapeIds.isNotEmpty ||
      effectiveSearchText.isNotEmpty;

  TentListFilterState copyWith({
    String? searchText,
    String? effectiveSearchText,
    Set<TentOverallState>? selectedStates,
    Set<int>? selectedSizes,
    Set<String>? selectedShapeIds,
  }) {
    return TentListFilterState(
      searchText: searchText ?? this.searchText,
      effectiveSearchText: effectiveSearchText ?? this.effectiveSearchText,
      selectedStates: selectedStates ?? this.selectedStates,
      selectedSizes: selectedSizes ?? this.selectedSizes,
      selectedShapeIds: selectedShapeIds ?? this.selectedShapeIds,
    );
  }
}

@riverpod
class TentListFilterNotifier extends _$TentListFilterNotifier {
  Timer? _searchDebounce;

  @override
  TentListFilterState build() {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });
    return const TentListFilterState();
  }

  void setSearchText(String value) {
    final normalized = value.trim();
    state = state.copyWith(searchText: value);

    if (normalized.length < 2) {
      _searchDebounce?.cancel();
      state = state.copyWith(effectiveSearchText: '');
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      state = state.copyWith(effectiveSearchText: normalized.toLowerCase());
    });
  }

  void toggleState(TentOverallState overallState) {
    final nextStates = Set<TentOverallState>.from(state.selectedStates);
    if (nextStates.contains(overallState)) {
      nextStates.remove(overallState);
    } else {
      nextStates.add(overallState);
    }

    state = state.copyWith(selectedStates: nextStates);
  }

  void toggleSize(int size) {
    final nextSizes = Set<int>.from(state.selectedSizes);
    if (nextSizes.contains(size)) {
      nextSizes.remove(size);
    } else {
      nextSizes.add(size);
    }

    state = state.copyWith(selectedSizes: nextSizes);
  }

  void toggleShape(String shapeId) {
    final nextShapeIds = Set<String>.from(state.selectedShapeIds);
    if (nextShapeIds.contains(shapeId)) {
      nextShapeIds.remove(shapeId);
    } else {
      nextShapeIds.add(shapeId);
    }

    state = state.copyWith(selectedShapeIds: nextShapeIds);
  }

  void clearAll() {
    _searchDebounce?.cancel();
    state = const TentListFilterState();
  }
}
