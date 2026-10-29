import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/activity_item.dart';
import '../../providers/providers.dart';
import '../../utils/design_constants.dart';
import '../../utils/route_aware_app_bar_mixin.dart';
import '../widgets/widgets.dart';

class JournalScreen extends ConsumerStatefulWidget {
  final ValueChanged<String> onOpenTentDetail;

  const JournalScreen({super.key, required this.onOpenTentDetail});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with RouteAware, RouteAwareAppBarMixin<JournalScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    subscribeRouteObserver();
    dispatchAppBarConfig();
  }

  @override
  void dispose() {
    unsubscribeRouteObserver();
    super.dispose();
  }

  @override
  void didPush() {
    dispatchAppBarConfig();
  }

  @override
  void didPopNext() {
    dispatchAppBarConfig();
  }

  @override
  AppBarConfig buildAppBarConfig() {
    final isDesktop = MediaQuery.sizeOf(context).width >= DesignConstants.desktopBreakpoint;
    final isLoading = ref.read(journalProvider).isLoading;

    return AppBarConfig(
      screenId: 'journal',
      title: isDesktop ? null : const Text('Journal'),
      actions: [
        Builder(
          builder: (context) {
            if (!isDesktop) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser le journal',
              onPressed: isLoading
                  ? null
                  : () => ref.read(journalProvider.notifier).refresh(),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(journalProvider);

    ref.listen(journalProvider.select((state) => state.isLoading), (_, _) {
      dispatchAppBarConfig();
    });

    return DataScreenScaffold<ActivityPage>(
      state: pageState,
      errorFallbackMessage: 'Impossible de charger le journal.',
      onRetry: () => ref.read(journalProvider.notifier).retry(),
      builder: _buildDataState,
    );
  }

  Widget _buildDataState(ActivityPage page) {
    if (page.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(journalProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            JournalEmptyState(isFiltered: false),
          ],
        ),
      );
    }

    final rows = _buildRows(page.items);

    return RefreshIndicator(
      onRefresh: () => ref.read(journalProvider.notifier).refresh(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          if (row is String) {
            return _DayHeading(label: row);
          }

          final item = row as ActivityItem;
          return _JournalRow(
            item: item,
            onTap: item.tentId == null
                ? null
                : () => widget.onOpenTentDetail(item.tentId!),
          );
        },
      ),
    );
  }

  List<Object> _buildRows(List<ActivityItem> items) {
    final rows = <Object>[];
    String? currentLabel;

    for (final item in items) {
      final label = item.localDayLabel();
      if (label != currentLabel) {
        rows.add(label);
        currentLabel = label;
      }
      rows.add(item);
    }

    return rows;
  }
}

class JournalEmptyState extends StatelessWidget {
  final bool isFiltered;

  const JournalEmptyState({super.key, required this.isFiltered});

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: isFiltered ? Icons.search_off : Icons.history,
      title: isFiltered ? 'Aucun résultat' : 'Aucune activité',
      subtitle: isFiltered
          ? 'Aucune activité ne correspond à vos filtres.'
          : 'Aucun changement récent à afficher.',
    );
  }
}

class _DayHeading extends StatelessWidget {
  final String label;

  const _DayHeading({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _JournalRow extends StatelessWidget {
  final ActivityItem item;
  final VoidCallback? onTap;

  const _JournalRow({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: colorScheme.outline,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(item.buildRowSpan(context)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.localTimeLabel()} • ${item.actorDisplayName}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
