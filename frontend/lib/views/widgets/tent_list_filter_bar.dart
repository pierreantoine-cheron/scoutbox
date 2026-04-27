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
                if (isDesktop) ...[
                  for (final size in availableSizes)
                    FilterChip(
                      label: Text(_sizeLabel(size)),
                      selected: selectedSizes.contains(size),
                      onSelected: (_) => onToggleSize(size),
                    ),
                  for (final option in availableShapeOptions)
                    FilterChip(
                      label: Text(option.label),
                      selected: selectedShapeIds.contains(option.id),
                      onSelected: (_) => onToggleShape(option.id),
                    ),
                ] else ...[
                  if (_hasSecondaryFilters)
                    FilledButton.tonalIcon(
                      onPressed: () => _openMobileFilters(context),
                      icon: const Icon(Icons.tune),
                      label: Text(_mobileFiltersLabel()),
                    ),
                ],
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
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
                          selected: selectedSizes.contains(size),
                          onSelected: (_) => onToggleSize(size),
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
                          selected: selectedShapeIds.contains(option.id),
                          onSelected: (_) => onToggleShape(option.id),
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
