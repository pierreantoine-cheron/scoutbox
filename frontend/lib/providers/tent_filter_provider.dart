import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tent.dart';

class TentListFilterState {
  final String searchText;
  final String effectiveSearchText;
  final Set<TentOverallState> selectedStates;

  const TentListFilterState({
    this.searchText = '',
    this.effectiveSearchText = '',
    this.selectedStates = const {},
  });

  bool get isFilteredMode =>
      selectedStates.isNotEmpty || effectiveSearchText.isNotEmpty;

  TentListFilterState copyWith({
    String? searchText,
    String? effectiveSearchText,
    Set<TentOverallState>? selectedStates,
  }) {
    return TentListFilterState(
      searchText: searchText ?? this.searchText,
      effectiveSearchText: effectiveSearchText ?? this.effectiveSearchText,
      selectedStates: selectedStates ?? this.selectedStates,
    );
  }
}

class TentListFilterNotifier extends Notifier<TentListFilterState> {
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

  void clearAll() {
    _searchDebounce?.cancel();
    state = const TentListFilterState();
  }
}

final tentListFilterProvider =
    NotifierProvider<TentListFilterNotifier, TentListFilterState>(
      TentListFilterNotifier.new,
    );
