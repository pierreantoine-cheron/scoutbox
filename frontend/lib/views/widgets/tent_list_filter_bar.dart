import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../models/tent.dart';
import 'tent_tag_filter_sheet.dart';

class TentTypeFilterOption {
  final String id;
  final String label;

  const TentTypeFilterOption({required this.id, required this.label});
}

class TentListFilterBar extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final Set<TentOverallState> selectedStates;
  final Set<int> selectedSizes;
  final Set<String> selectedModelIds;
  final Set<String> selectedTagIds;
  final List<int> availableSizes;
  final List<TentTypeFilterOption> availableModelOptions;
  final List<Tag> allTags;
  final bool isFilteredMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TentOverallState> onToggleState;
  final ValueChanged<int> onToggleSize;
  final ValueChanged<String> onToggleModel;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onClearAll;
  final VoidCallback? onManageTags;

  const TentListFilterBar({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.selectedStates,
    required this.selectedSizes,
    required this.selectedModelIds,
    required this.selectedTagIds,
    required this.availableSizes,
    required this.availableModelOptions,
    required this.allTags,
    required this.isFilteredMode,
    required this.onSearchChanged,
    required this.onToggleState,
    required this.onToggleSize,
    required this.onToggleModel,
    required this.onToggleTag,
    required this.onClearAll,
    this.onManageTags,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchField(
              searchController: searchController,
              onSearchChanged: onSearchChanged,
            ),
            const SizedBox(height: 12),
            if (isDesktop)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 24,
                    runSpacing: 16,
                    children: [
                      _DesktopCategory(
                        label: 'Etat',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final state in TentOverallState.values)
                              FilterChip(
                                label: Text(state.toFrenchLabel()),
                                selected: selectedStates.contains(state),
                                onSelected: (_) => onToggleState(state),
                              ),
                          ],
                        ),
                      ),
                      if (availableSizes.isNotEmpty)
                        _DesktopCategory(
                          label: 'Taille',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final size in availableSizes)
                                FilterChip(
                                  label: Text(_sizeLabel(size)),
                                  selected: selectedSizes.contains(size),
                                  onSelected: (_) => onToggleSize(size),
                                ),
                            ],
                          ),
                        ),
                      if (availableModelOptions.isNotEmpty)
                        _DesktopCategory(
                          label: 'Type',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final option in availableModelOptions)
                                FilterChip(
                                  label: Text(option.label),
                                  selected: selectedModelIds.contains(
                                    option.id,
                                  ),
                                  onSelected: (_) => onToggleModel(option.id),
                                ),
                            ],
                          ),
                        ),
                      if (allTags.isNotEmpty)
                        _DesktopCategory(
                          label: 'Étiquettes',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in _sortedTags().take(6))
                                _TagFilterChip(
                                  tag: tag,
                                  selected: selectedTagIds.contains(tag.id),
                                  onToggleTag: onToggleTag,
                                ),
                              if (allTags.length > 6)
                                FilledButton.tonalIcon(
                                  onPressed: () => _openTagFilterSheet(context),
                                  icon: const Icon(Icons.label_outline),
                                  label: Text('Tags (${allTags.length})'),
                                ),
                            ],
                          ),
                        )
                      else if (!isFilteredMode)
                        _NoTagsMessage(onManageTags: onManageTags),
                    ],
                  ),
                  if (isFilteredMode) ...[
                    const SizedBox(height: 12),
                    ActionChip(
                      avatar: const Icon(Icons.clear_all),
                      label: const Text('Effacer tout'),
                      onPressed: onClearAll,
                    ),
                  ],
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel(label: 'Etat'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final state in TentOverallState.values)
                        FilterChip(
                          label: Text(state.toFrenchLabel()),
                          selected: selectedStates.contains(state),
                          onSelected: (_) => onToggleState(state),
                        ),
                      if (_hasSecondaryFilters)
                        FilledButton.tonalIcon(
                          onPressed: () => _openMobileFilters(context),
                          icon: const Icon(Icons.tune),
                          label: Text(_mobileFiltersLabel()),
                        ),
                      if (isFilteredMode)
                        ActionChip(
                          avatar: const Icon(Icons.clear_all),
                          label: const Text('Effacer tout'),
                          onPressed: onClearAll,
                        ),
                    ],
                  ),
                  if (allTags.isEmpty && !isFilteredMode) ...[
                    const SizedBox(height: 8),
                    _NoTagsMessage(onManageTags: onManageTags),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool get _hasSecondaryFilters =>
      availableSizes.isNotEmpty ||
      availableModelOptions.isNotEmpty ||
      allTags.isNotEmpty;

  String _mobileFiltersLabel() {
    final activeCount =
        selectedSizes.length + selectedModelIds.length + selectedTagIds.length;
    if (activeCount == 0) {
      return 'Filtres';
    }
    return 'Filtres ($activeCount)';
  }

  Future<void> _openMobileFilters(BuildContext context) async {
    final sheetSelectedSizes = Set<int>.from(selectedSizes);
    final sheetSelectedModelIds = Set<String>.from(selectedModelIds);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (availableSizes.isNotEmpty) ...[
                        const Text(
                          'Taille',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final size in availableSizes)
                              FilterChip(
                                label: Text(_sizeLabel(size)),
                                selected: sheetSelectedSizes.contains(size),
                                onSelected: (_) {
                                  setSheetState(() {
                                    if (sheetSelectedSizes.contains(size)) {
                                      sheetSelectedSizes.remove(size);
                                    } else {
                                      sheetSelectedSizes.add(size);
                                    }
                                  });
                                  onToggleSize(size);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (availableModelOptions.isNotEmpty) ...[
                        const Text(
                          'Type',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in availableModelOptions)
                              FilterChip(
                                label: Text(option.label),
                                selected: sheetSelectedModelIds.contains(
                                  option.id,
                                ),
                                onSelected: (_) {
                                  setSheetState(() {
                                    if (sheetSelectedModelIds.contains(
                                      option.id,
                                    )) {
                                      sheetSelectedModelIds.remove(option.id);
                                    } else {
                                      sheetSelectedModelIds.add(option.id);
                                    }
                                  });
                                  onToggleModel(option.id);
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (allTags.isNotEmpty) ...[
                        const Text(
                          'Étiquettes',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 260,
                          child: TentTagFilterSheet(
                            tags: allTags,
                            selectedTagIds: selectedTagIds,
                            onToggleTag: onToggleTag,
                            onClearAll: onClearAll,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Fermer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTagFilterSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useRootNavigator: true,
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: TentTagFilterSheet(
            tags: allTags,
            selectedTagIds: selectedTagIds,
            onToggleTag: onToggleTag,
            onClearAll: onClearAll,
          ),
        );
      },
    );
  }

  List<Tag> _sortedTags() {
    final tags = [...allTags];
    tags.sort((left, right) {
      final countCompare = right.tentCount.compareTo(left.tentCount);
      if (countCompare != 0) {
        return countCompare;
      }
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return tags;
  }

  String _sizeLabel(int size) {
    if (size <= 1) {
      return '$size place';
    }

    return '$size places';
  }
}

class _TagFilterChip extends StatelessWidget {
  final Tag tag;
  final bool selected;
  final ValueChanged<String> onToggleTag;

  const _TagFilterChip({
    required this.tag,
    required this.selected,
    required this.onToggleTag,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text('${tag.name} (${tag.tentCount})'),
      selected: selected,
      onSelected: (_) => onToggleTag(tag.id),
    );
  }
}

class _NoTagsMessage extends StatelessWidget {
  final VoidCallback? onManageTags;

  const _NoTagsMessage({this.onManageTags});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Aucune étiquette disponible'),
        if (onManageTags != null)
          TextButton(
            onPressed: onManageTags,
            child: const Text('Créer des étiquettes'),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(fontWeight: FontWeight.w600));
  }
}

class _DesktopCategory extends StatelessWidget {
  final String label;
  final Widget child;

  const _DesktopCategory({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: label),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  const _SearchField({
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: searchController,
      builder: (context, value, _) {
        return TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            labelText: 'Rechercher une tente',
            hintText: 'Nom de la tente',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer la recherche',
                    onPressed: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
