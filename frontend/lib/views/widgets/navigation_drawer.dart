import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../utils/design_constants.dart';

class ScoutBoxNavigationDrawer extends ConsumerWidget {
  final NavigationSection selectedSection;
  final ValueChanged<NavigationSection> onSelectSection;

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
              children: [
                _DrawerItem(
                  section: NavigationSection.tents,
                  icon: NavigationSection.tents.icon,
                  label: NavigationSection.tents.label,
                  badge: tentCount,
                  isSelected: selectedSection == NavigationSection.tents,
                  enabled: true,
                  onTap: () => onSelectSection(NavigationSection.tents),
                ),
                _DrawerItem(
                  section: NavigationSection.tags,
                  icon: NavigationSection.tags.icon,
                  label: NavigationSection.tags.label,
                  badge: tagCount,
                  isSelected: selectedSection == NavigationSection.tags,
                  enabled: true,
                  onTap: () => onSelectSection(NavigationSection.tags),
                ),
                _DrawerItem(
                  section: NavigationSection.parts,
                  icon: NavigationSection.parts.icon,
                  label: NavigationSection.parts.label,
                  isSelected: selectedSection == NavigationSection.parts,
                  enabled: false,
                  onTap: null,
                ),
                _DrawerItem(
                  section: NavigationSection.models,
                  icon: NavigationSection.models.icon,
                  label: NavigationSection.models.label,
                  isSelected: selectedSection == NavigationSection.models,
                  enabled: false,
                  onTap: null,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: _DrawerItem(
              section: NavigationSection.settings,
              icon: NavigationSection.settings.icon,
              label: NavigationSection.settings.label,
              isSelected: selectedSection == NavigationSection.settings,
              enabled: false,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }

  int _totalTentCount(WidgetRef ref) {
    final tents = ref.watch(tentListProvider).asData?.value;
    return tents?.length ?? 0;
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
              color: colorScheme.onSurface,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.cabin,
              color: colorScheme.surface,
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

    final fgColor = isSelected && enabled
        ? colorScheme.onSurface
        : colorScheme.onSurfaceVariant;

    return Opacity(
      opacity: effectiveOpacity,
      child: Material(
        color: Colors.transparent,
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
                      fontWeight: isSelected && enabled
                          ? FontWeight.w600
                          : FontWeight.w400,
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
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      badge.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
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
