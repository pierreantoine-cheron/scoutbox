import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/tent.dart';
import '../utils/design_constants.dart';

part 'tent_filter_provider.g.dart';

enum ArchiveFilter {
  active,
  all,
  archived;

  String toFrenchLabel() {
    switch (this) {
      case ArchiveFilter.active:
        return 'Actives';
      case ArchiveFilter.all:
        return 'Toutes';
      case ArchiveFilter.archived:
        return 'Archivées';
    }
  }
}

class TentListFilterState {
  final String searchText;
  final String effectiveSearchText;
  final Set<TentOverallState> selectedStates;
  final Set<int> selectedSizes;
  final Set<String> selectedModelIds;
  final Set<String> selectedTagIds;
  final ArchiveFilter archiveFilter;

  const TentListFilterState({
    this.searchText = '',
    this.effectiveSearchText = '',
    this.selectedStates = const {},
    this.selectedSizes = const {},
    this.selectedModelIds = const {},
    this.selectedTagIds = const {},
    this.archiveFilter = ArchiveFilter.active,
  });

  bool get isFilteredMode =>
      selectedStates.isNotEmpty ||
      selectedSizes.isNotEmpty ||
      selectedModelIds.isNotEmpty ||
      selectedTagIds.isNotEmpty ||
      archiveFilter != ArchiveFilter.active ||
      effectiveSearchText.isNotEmpty;

  TentListFilterState copyWith({
    String? searchText,
    String? effectiveSearchText,
    Set<TentOverallState>? selectedStates,
    Set<int>? selectedSizes,
    Set<String>? selectedModelIds,
    Set<String>? selectedTagIds,
    ArchiveFilter? archiveFilter,
  }) {
    return TentListFilterState(
      searchText: searchText ?? this.searchText,
      effectiveSearchText: effectiveSearchText ?? this.effectiveSearchText,
      selectedStates: selectedStates ?? this.selectedStates,
      selectedSizes: selectedSizes ?? this.selectedSizes,
      selectedModelIds: selectedModelIds ?? this.selectedModelIds,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      archiveFilter: archiveFilter ?? this.archiveFilter,
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
    _searchDebounce = Timer(DesignConstants.searchDebounce, () {
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

  void toggleModel(String modelId) {
    final nextModelIds = Set<String>.from(state.selectedModelIds);
    if (nextModelIds.contains(modelId)) {
      nextModelIds.remove(modelId);
    } else {
      nextModelIds.add(modelId);
    }

    state = state.copyWith(selectedModelIds: nextModelIds);
  }

  void toggleTag(String tagId) {
    final nextTagIds = Set<String>.from(state.selectedTagIds);
    if (nextTagIds.contains(tagId)) {
      nextTagIds.remove(tagId);
    } else {
      nextTagIds.add(tagId);
    }

    state = state.copyWith(selectedTagIds: nextTagIds);
  }

  void setSelectedTags(Set<String> tagIds) {
    state = state.copyWith(selectedTagIds: Set<String>.from(tagIds));
  }

  void setArchiveFilter(ArchiveFilter filter) {
    state = state.copyWith(archiveFilter: filter);
  }

  void clearAll() {
    _searchDebounce?.cancel();
    state = const TentListFilterState();
  }
}
