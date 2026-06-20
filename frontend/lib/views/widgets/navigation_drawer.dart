import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';

class ScoutBoxNavigationDrawer extends ConsumerWidget {
  final NavigationSection selectedSection;
  final ValueChanged<NavigationSection> onSelectSection;

  static const _topSections = [
    NavigationSection.tents,
    NavigationSection.tags,
    NavigationSection.parts,
    NavigationSection.models,
  ];

  static const _bottomSections = [NavigationSection.settings];

  const ScoutBoxNavigationDrawer({
    super.key,
    required this.selectedSection,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tentCount = _totalTentCount(ref);
    final tagCount = _totalTagCount(ref);

    return Drawer(
      width: 300,
      child: Column(
        children: [
          const _DrawerHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: _topSections.map((s) => _buildItem(s, tentCount, tagCount)).toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _bottomSections.map((s) => _buildItem(s, tentCount, tagCount)).first,
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    NavigationSection section,
    int tentCount,
    int tagCount,
  ) {
    final badge = switch (section) {
      NavigationSection.tents => tentCount,
      NavigationSection.tags => tagCount,
      _ => null,
    };

    return _DrawerItem(
      section: section,
      icon: section.icon,
      label: section.label,
      badge: badge,
      isSelected: selectedSection == section,
      enabled: section.isEnabled,
      onTap: section.isEnabled ? () => onSelectSection(section) : null,
    );
  }

  int _totalTentCount(WidgetRef ref) {
    final tents = ref.watch(tentListProvider).asData?.value;
    return tents?.where((t) => !t.isArchived).length ?? 0;
  }

  int _totalTagCount(WidgetRef ref) {
    final tags = ref.watch(tagsProvider).asData?.value;
    return tags?.length ?? 0;
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.cabin,
              color: colorScheme.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'ScoutBox',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final NavigationSection section;
  final IconData icon;
  final String label;
  final int? badge;
  final bool isSelected;
  final bool enabled;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.section,
    required this.icon,
    required this.label,
    this.badge,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveOpacity = enabled ? 1.0 : 0.38;

    final fgColor = isSelected && enabled ? AppColors.scoutGreen : colorScheme.onSurface;

    return Opacity(
      opacity: effectiveOpacity,
      child: Material(
        color: isSelected && enabled ? AppColors.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fgColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: fgColor,
                      fontWeight: isSelected && enabled ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (badge != null && enabled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      badge.toString(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.scoutGreen,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
