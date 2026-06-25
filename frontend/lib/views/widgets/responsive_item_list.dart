import 'package:flutter/material.dart';

import '../../utils/app_colors.dart';
import '../../utils/design_constants.dart';
import 'refresh_warning_card.dart';

class ResponsiveItemList<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item) itemContent;
  final Future<void> Function() onRefresh;
  final String? refreshWarning;
  final Widget emptyState;
  final Future<void> Function(T item) onEdit;
  final Future<void> Function(T item) onDelete;
  const ResponsiveItemList({
    super.key,
    required this.items,
    required this.itemContent,
    required this.onRefresh,
    this.refreshWarning,
    required this.emptyState,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (refreshWarning != null)
              RefreshWarningCard(message: refreshWarning!),
            const SizedBox(height: 72),
            emptyState,
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final crossAxisCount = width >= 1100 ? 3 : width >= DesignConstants.desktopBreakpoint ? 2 : 1;
          final spacing = AppSpacing.sm;
          final cardWidth = (width - 2 * 16 - (crossAxisCount - 1) * spacing) / crossAxisCount;

          // Extra bottom padding on mobile so the last card is not hidden behind the FAB
          final bottomPadding = width < DesignConstants.desktopBreakpoint ? 16.0 + 72.0 : 16.0;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            children: [
              if (refreshWarning != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: RefreshWarningCard(message: refreshWarning!),
                ),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: items.map((item) {
                  return SizedBox(
                    width: cardWidth,
                    child: _buildCard(context, item),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, T item) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        child: Padding(
          padding: AppPadding.cardContent,
          child: Row(
            children: [
              Expanded(child: itemContent(context, item)),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                useRootNavigator: true,
                icon: const Icon(Icons.more_vert, color: AppColors.muted, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                offset: const Offset(0, 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  side: const BorderSide(color: AppColors.border),
                ),
                elevation: AppElevation.popup,
                color: colorScheme.surface,
                itemBuilder: (_) {
                  return const [
                    PopupMenuItem<String>(
                      enabled: true,
                      value: 'edit',
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: AppSpacing.sm),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      enabled: true,
                      value: 'delete',
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: AppColors.stateUnusable),
                          SizedBox(width: AppSpacing.sm),
                          Text('Supprimer', style: TextStyle(color: AppColors.stateUnusable)),
                        ],
                      ),
                    ),
                  ];
                },
                onSelected: (value) {
                  if (value == 'edit') onEdit(item);
                  if (value == 'delete') onDelete(item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
