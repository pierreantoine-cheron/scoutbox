import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/providers.dart';
import '../../utils/app_colors.dart';
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
    final List<_NavigationDrawerItem> sections = [
      _NavigationDrawerItem(
        section: NavigationSection.tents,
        count: () =>
            ref.watch(tentListProvider).asData?.value.where((t) => !t.isArchived).length ?? 0,
      ),
      _NavigationDrawerItem(
        section: NavigationSection.tags,
        count: () => ref.watch(tagsProvider).asData?.value.length ?? 0,
      ),
      _NavigationDrawerItem(
        section: NavigationSection.parts,
        count: () => ref.watch(partKindsProvider).asData?.value.length ?? 0,
      ),
      _NavigationDrawerItem(
        section: NavigationSection.models,
        count: () => ref.watch(tentModelsProvider).asData?.value.length ?? 0,
      ),
    ];

    return Drawer(
      width: 300,
      child: Column(
        children: [
          const _DrawerHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.sm),
              children: sections
                  .map(
                    (item) => _DrawerItem(
                      section: item.section,
                      icon: item.section.icon,
                      label: item.section.label,
                      badge: item.count == null ? null : item.count!(),
                      isSelected: selectedSection == item.section,
                      enabled: item.section.isEnabled,
                      onTap: item.section.isEnabled ? () => onSelectSection(item.section) : null,
                    ),
                  )
                  .toList(),
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
              enabled: NavigationSection.settings.isEnabled,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationDrawerItem {
  final NavigationSection section;
  final int Function()? count;

  const _NavigationDrawerItem({
    required this.section,
    this.count,
  });
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
          SvgPicture.asset(
            'assets/brand/logo.svg',
            width: 36,
            height: 36,
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
