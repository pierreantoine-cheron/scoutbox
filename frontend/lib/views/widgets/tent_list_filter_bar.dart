import 'package:flutter/material.dart';

import '../../models/tent.dart';

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
  final Set<String> selectedShapeIds;
  final List<int> availableSizes;
  final List<TentTypeFilterOption> availableShapeOptions;
  final bool isFilteredMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TentOverallState> onToggleState;
  final ValueChanged<int> onToggleSize;
  final ValueChanged<String> onToggleShape;
  final VoidCallback onClearAll;

  const TentListFilterBar({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.selectedStates,
    required this.selectedSizes,
    required this.selectedShapeIds,
    required this.availableSizes,
    required this.availableShapeOptions,
    required this.isFilteredMode,
    required this.onSearchChanged,
    required this.onToggleState,
    required this.onToggleSize,
    required this.onToggleShape,
    required this.onClearAll,
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
              _DesktopFilterSections(
                selectedStates: selectedStates,
                selectedSizes: selectedSizes,
                selectedShapeIds: selectedShapeIds,
                availableSizes: availableSizes,
                availableShapeOptions: availableShapeOptions,
                isFilteredMode: isFilteredMode,
                onToggleState: onToggleState,
                onToggleSize: onToggleSize,
                onToggleShape: onToggleShape,
                onClearAll: onClearAll,
                sizeLabelBuilder: _sizeLabel,
              )
            else
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
          ],
        ),
      ),
    );
  }

  bool get _hasSecondaryFilters =>
      availableSizes.isNotEmpty || availableShapeOptions.isNotEmpty;

  String _mobileFiltersLabel() {
    final activeCount = selectedSizes.length + selectedShapeIds.length;
    if (activeCount == 0) {
      return 'Filtres';
    }
    return 'Filtres ($activeCount)';
  }

  Future<void> _openMobileFilters(BuildContext context) async {
    final sheetSelectedSizes = Set<int>.from(selectedSizes);
    final sheetSelectedShapeIds = Set<String>.from(selectedShapeIds);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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
                      if (availableShapeOptions.isNotEmpty) ...[
                        const Text(
                          'Type',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final option in availableShapeOptions)
                              FilterChip(
                                label: Text(option.label),
                                selected: sheetSelectedShapeIds.contains(
                                  option.id,
                                ),
                                onSelected: (_) {
                                  setSheetState(() {
                                    if (sheetSelectedShapeIds.contains(
                                      option.id,
                                    )) {
                                      sheetSelectedShapeIds.remove(option.id);
                                    } else {
                                      sheetSelectedShapeIds.add(option.id);
                                    }
                                  });
                                  onToggleShape(option.id);
                                },
                              ),
                          ],
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

  String _sizeLabel(int size) {
    if (size <= 1) {
      return '$size place';
    }

    return '$size places';
  }
}

class _DesktopFilterSections extends StatelessWidget {
  final Set<TentOverallState> selectedStates;
  final Set<int> selectedSizes;
  final Set<String> selectedShapeIds;
  final List<int> availableSizes;
  final List<TentTypeFilterOption> availableShapeOptions;
  final bool isFilteredMode;
  final ValueChanged<TentOverallState> onToggleState;
  final ValueChanged<int> onToggleSize;
  final ValueChanged<String> onToggleShape;
  final VoidCallback onClearAll;
  final String Function(int size) sizeLabelBuilder;

  const _DesktopFilterSections({
    required this.selectedStates,
    required this.selectedSizes,
    required this.selectedShapeIds,
    required this.availableSizes,
    required this.availableShapeOptions,
    required this.isFilteredMode,
    required this.onToggleState,
    required this.onToggleSize,
    required this.onToggleShape,
    required this.onClearAll,
    required this.sizeLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          ],
        ),
        if (availableSizes.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel(label: 'Taille'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in availableSizes)
                FilterChip(
                  label: Text(sizeLabelBuilder(size)),
                  selected: selectedSizes.contains(size),
                  onSelected: (_) => onToggleSize(size),
                ),
            ],
          ),
        ],
        if (availableShapeOptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel(label: 'Type'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in availableShapeOptions)
                FilterChip(
                  label: Text(option.label),
                  selected: selectedShapeIds.contains(option.id),
                  onSelected: (_) => onToggleShape(option.id),
                ),
            ],
          ),
        ],
        if (isFilteredMode) ...[
          const SizedBox(height: 12),
          ActionChip(
            avatar: const Icon(Icons.clear_all),
            label: const Text('Effacer tout'),
            onPressed: onClearAll,
          ),
        ],
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
