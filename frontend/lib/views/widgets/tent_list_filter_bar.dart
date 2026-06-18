import 'package:flutter/material.dart';

import '../../models/tag.dart';
import '../../models/tent.dart';
import '../../utils/app_colors.dart';
import 'filter_chip.dart';

class TentTypeFilterOption {
  final String id;
  final String label;

  const TentTypeFilterOption({required this.id, required this.label});
}

class TentListFilterBar extends StatefulWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final Set<TentOverallState> selectedStates;
  final Set<int> selectedSizes;
  final Set<String> selectedModelIds;
  final Set<String> selectedTagIds;
  final List<int> availableSizes;
  final List<TentTypeFilterOption> availableModelOptions;
  final List<Tag> allTags;
  final int visibleTentCount;
  final bool isFilteredMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<TentOverallState> onToggleState;
  final ValueChanged<int> onToggleSize;
  final ValueChanged<String> onToggleModel;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onClearAll;
  final VoidCallback? onClearTags;
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
    required this.visibleTentCount,
    required this.isFilteredMode,
    required this.onSearchChanged,
    required this.onToggleState,
    required this.onToggleSize,
    required this.onToggleModel,
    required this.onToggleTag,
    required this.onClearAll,
    this.onClearTags,
    this.onManageTags,
  });

  @override
  State<TentListFilterBar> createState() => _TentListFilterBarState();
}

class _TentListFilterBarState extends State<TentListFilterBar> {
  bool _panelExpanded = false;

  List<_ActivePill> get _activePills {
    final pills = <_ActivePill>[];
    for (final state in widget.selectedStates) {
      pills.add(_ActivePill(
        value: state.name,
        label: state.toFrenchLabel(),
        color: _stateColor(state),
        onTap: () => widget.onToggleState(state),
      ));
    }
    for (final size in widget.selectedSizes) {
      pills.add(_ActivePill(
        value: size.toString(),
        label: size == 1 ? '1 place' : '$size places',
        color: AppColors.scoutGreen,
        onTap: () => widget.onToggleSize(size),
      ));
    }
    for (final modelId in widget.selectedModelIds) {
      final model =
          widget.availableModelOptions.where((m) => m.id == modelId).firstOrNull;
      pills.add(_ActivePill(
        value: modelId,
        label: model?.label ?? modelId,
        color: AppColors.scoutGreen,
        onTap: () => widget.onToggleModel(modelId),
      ));
    }
    for (final tagId in widget.selectedTagIds) {
      final tag = widget.allTags.where((t) => t.id == tagId).firstOrNull;
      if (tag != null) {
        pills.add(_ActivePill(
          value: tagId,
          label: tag.name,
          tagColor: TagPalette.colorFromHex(tag.color),
          onTap: () => widget.onToggleTag(tagId),
        ));
      }
    }
    return pills;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final horizontalPadding = widget.isDesktop ? 24.0 : 16.0;

    return Material(
      color: colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FilterBarBase(
            pills: _activePills,
            tentCount: widget.visibleTentCount,
            isPanelExpanded: _panelExpanded,
            horizontalPadding: horizontalPadding,
            onTogglePanel: () => setState(() => _panelExpanded = !_panelExpanded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            alignment: Alignment.topCenter,
            curve: Curves.easeInOut,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SizedBox(
                  width: constraints.maxWidth,
                  child: _panelExpanded
                      ? _FilterPanel(
                          selectedStates: widget.selectedStates,
                          selectedSizes: widget.selectedSizes,
                          selectedModelIds: widget.selectedModelIds,
                          selectedTagIds: widget.selectedTagIds,
                          availableSizes: widget.availableSizes,
                          availableModelOptions: widget.availableModelOptions,
                          allTags: widget.allTags,
                          isFilteredMode: widget.isFilteredMode,
                          horizontalPadding: horizontalPadding,
                          onToggleState: widget.onToggleState,
                          onToggleSize: widget.onToggleSize,
                          onToggleModel: widget.onToggleModel,
                          onToggleTag: widget.onToggleTag,
                          onClearAll: widget.onClearAll,
                          onManageTags: widget.onManageTags,
                        )
                      : const SizedBox(width: double.infinity),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

Color _stateColor(TentOverallState state) {
  return switch (state) {
    TentOverallState.good => AppColors.statePerfect,
    TentOverallState.needsRepair => AppColors.stateUsable,
    TentOverallState.unusable => AppColors.stateUnusable,
  };
}

class _FilterBarBase extends StatelessWidget {
  final List<_ActivePill> pills;
  final int tentCount;
  final bool isPanelExpanded;
  final double horizontalPadding;
  final VoidCallback onTogglePanel;

  const _FilterBarBase({
    required this.pills,
    required this.tentCount,
    required this.isPanelExpanded,
    required this.horizontalPadding,
    required this.onTogglePanel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PillsOverflow(pills: pills),
          ),
          const SizedBox(width: 10),
          Text(
            '$tentCount tente${tentCount != 1 ? 's' : ''}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          _ExpandToggle(
            isExpanded: isPanelExpanded,
            onTap: onTogglePanel,
          ),
        ],
      ),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _ExpandToggle({required this.isExpanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isExpanded
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.surface,
          border: Border.all(
            color: isExpanded
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 220),
          child: Icon(
            Icons.expand_more,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _PillsOverflow extends StatelessWidget {
  final List<_ActivePill> pills;

  const _PillsOverflow({required this.pills});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (pills.isEmpty) {
      return Text(
        'Aucun filtre actif',
        style: TextStyle(
          fontSize: 12,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        const tokenHeight = 38.0;
        const maxRows = 2;
        final maxTokens = _fitCount(constraints.maxWidth, spacing);

        return ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: tokenHeight * maxRows + spacing * (maxRows - 1),
          ),
          child: Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (var i = 0; i < pills.length && i < maxTokens; i++)
                pills[i].tagColor != null
                    ? ScoutChip.filterTag(
                        name: pills[i].label,
                        color: pills[i].tagColor!,
                        selected: false,
                        onTap: pills[i].onTap,
                      )
                    : ScoutChip.filter(
                        label: pills[i].label,
                        color: pills[i].color!,
                        selected: false,
                        onTap: pills[i].onTap,
                      ),
              if (pills.length > maxTokens)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  constraints: const BoxConstraints(minHeight: 38),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    child: Text(
                      '+${pills.length - maxTokens}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _fitCount(double maxWidth, double spacing) {
    var used = spacing;
    for (var i = 0; i < pills.length; i++) {
      final w = pills[i].estimatedWidth + spacing;
      if (used + w > maxWidth && i >= 1) return i;
      used += w;
    }
    return pills.length;
  }
}


class _FilterPanel extends StatelessWidget {
  final Set<TentOverallState> selectedStates;
  final Set<int> selectedSizes;
  final Set<String> selectedModelIds;
  final Set<String> selectedTagIds;
  final List<int> availableSizes;
  final List<TentTypeFilterOption> availableModelOptions;
  final List<Tag> allTags;
  final bool isFilteredMode;
  final double horizontalPadding;
  final ValueChanged<TentOverallState> onToggleState;
  final ValueChanged<int> onToggleSize;
  final ValueChanged<String> onToggleModel;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onClearAll;
  final VoidCallback? onManageTags;

  const _FilterPanel({
    required this.selectedStates,
    required this.selectedSizes,
    required this.selectedModelIds,
    required this.selectedTagIds,
    required this.availableSizes,
    required this.availableModelOptions,
    required this.allTags,
    required this.isFilteredMode,
    required this.horizontalPadding,
    required this.onToggleState,
    required this.onToggleSize,
    required this.onToggleModel,
    required this.onToggleTag,
    required this.onClearAll,
    this.onManageTags,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FilterRow(
            label: 'État',
            children: [
              for (final state in TentOverallState.values)
                ScoutChip.filter(
                  label: state.toFrenchLabel(),
                  color: _stateColor(state),
                  selected: selectedStates.contains(state),
                  onTap: () => onToggleState(state),
                ),
            ],
          ),
          if (availableSizes.isNotEmpty)
            _FilterRow(
              label: 'Taille',
              children: [
                for (final size in availableSizes)
                  ScoutChip.filter(
                    label: size == 1 ? '$size place' : '$size places',
                    color: AppColors.scoutGreen,
                    selected: selectedSizes.contains(size),
                    onTap: () => onToggleSize(size),
                  ),
              ],
            ),
          if (availableModelOptions.isNotEmpty)
            _FilterRow(
              label: 'Modèle',
              children: [
                for (final option in availableModelOptions)
                  ScoutChip.filter(
                    label: option.label,
                    color: AppColors.scoutGreen,
                    selected: selectedModelIds.contains(option.id),
                    onTap: () => onToggleModel(option.id),
                  ),
              ],
            ),
          if (allTags.isNotEmpty)
            _FilterRow(
              label: 'Étiquettes',
              children: [
                for (final tag in _sortedTags())
                  ScoutChip.filterTag(
                    name: tag.name,
                    color: TagPalette.colorFromHex(tag.color),
                    selected: selectedTagIds.contains(tag.id),
                    onTap: () => onToggleTag(tag.id),
                  ),
              ],
            ),
          if (isFilteredMode)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: onClearAll,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      side: BorderSide(color: colorScheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      'Effacer les filtres',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Tag> _sortedTags() {
    final tags = [...allTags];
    tags.sort((left, right) {
      final countCompare = right.tentCount.compareTo(left.tentCount);
      if (countCompare != 0) return countCompare;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return tags;
  }
}

class _FilterRow extends StatelessWidget {
  final String label;
  final List<Widget> children;

  const _FilterRow({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.55,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}



class _ActivePill {
  final String value;
  final String label;
  final Color? color;
  final Color? tagColor;
  final VoidCallback onTap;

  const _ActivePill({
    required this.value,
    required this.label,
    this.color,
    this.tagColor,
    required this.onTap,
  });

  double get estimatedWidth => (label.length * 9.0) + 28;
}
