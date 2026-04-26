import 'package:flutter/material.dart';

import '../../models/tent.dart';

class TentListFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final Set<TentOverallState> selectedStates;
  final bool isFilteredMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TentOverallState> onToggleState;
  final VoidCallback onClearAll;

  const TentListFilterBar({
    super.key,
    required this.searchController,
    required this.selectedStates,
    required this.isFilteredMode,
    required this.onSearchChanged,
    required this.onToggleState,
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
            TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Rechercher une tente',
                hintText: 'Nom de la tente',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isEmpty
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
}
