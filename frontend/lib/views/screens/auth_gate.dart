import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../providers/providers.dart';
import '../../utils/design_constants.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'models_screen.dart';
import 'part_kinds_screen.dart';
import 'tags_screen.dart';
import 'tent_list_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final RouteObserver<ModalRoute<dynamic>> _routeObserver;

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(routeObserverProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.isAuthenticated) {
      final section = ref.watch(navigationSectionProvider);
      final appBarConfig = ref.watch(appBarConfigProvider);
      final successTrigger = ref.watch(successIndicatorProvider);
      final isDesktop = MediaQuery.sizeOf(context).width >= 768;

      final isRootScreen = !appBarConfig.showBackButton;

      return Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(
          config: appBarConfig,
          isDesktop: isDesktop,
          isRootScreen: isRootScreen,
          section: section,
          successTrigger: successTrigger,
        ),
        drawer: isDesktop
            ? null
            : Drawer(
                width: 300,
                surfaceTintColor: Colors.transparent,
                child: ScoutBoxNavigationDrawer(
                  selectedSection: section,
                  onSelectSection: (s) {
                    _scaffoldKey.currentState?.closeDrawer();
                    _navigateToSection(s);
                  },
                ),
              ),
        floatingActionButton: isDesktop ? null : appBarConfig.fab,
        body: Navigator(
          key: _navigatorKey,
          observers: [_routeObserver],
          onGenerateInitialRoutes: (navigator, initialRoute) {
            return [
              MaterialPageRoute(
                builder: (_) => _buildRootScreen(section),
              ),
            ];
          },
        ),
      );
    }

    return authState.showLoginScreen ? const LoginScreen() : const RegisterScreen();
  }

  void _navigateToSection(NavigationSection section) {
    ref
        .read(appBarConfigProvider.notifier)
        .set(
          const AppBarConfig(screenId: ''),
        );
    ref.read(navigationSectionProvider.notifier).set(section);
    _navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => _buildRootScreen(section)),
      (_) => false,
    );
  }

  Widget _buildRootScreen(NavigationSection section) {
    return switch (section) {
      NavigationSection.tents => const TentListScreen(),
      NavigationSection.tags => const TagsScreen(),
      NavigationSection.parts => const PartKindsScreen(),
      NavigationSection.models => const ModelsScreen(),
      NavigationSection.settings => const _PlaceholderScreen(
        label: 'Réglages',
      ),
    };
  }

  PreferredSizeWidget _buildAppBar({
    required AppBarConfig config,
    required bool isDesktop,
    required bool isRootScreen,
    required NavigationSection section,
    required int successTrigger,
  }) {
    Widget? leading;
    if (isRootScreen && !isDesktop) {
      leading = IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      );
    } else if (!isRootScreen) {
      leading = BackButton(
        onPressed: () => _navigatorKey.currentState?.pop(),
      );
    }

    Widget? title;
    if (config.title != null) {
      title = config.title;
    } else if (isRootScreen && isDesktop) {
      title = _DesktopTitleRow(
        section: section,
        onSectionTap: (s) {
          if (s.isEnabled) _navigateToSection(s);
        },
      );
    }

    final actions = <Widget>[
      FadingCloudDoneIcon(trigger: successTrigger),
      if (config.actions != null) ...config.actions!,
    ];

    return AppBar(
      centerTitle: isDesktop && isRootScreen ? false : null,
      leading: leading,
      title: title,
      titleSpacing: isDesktop && isRootScreen ? 24 : null,
      actions: actions,
    );
  }
}

class _DesktopTitleRow extends StatelessWidget {
  final NavigationSection section;
  final ValueChanged<NavigationSection> onSectionTap;

  const _DesktopTitleRow({
    required this.section,
    required this.onSectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/brand/logo.svg',
          width: 24,
          height: 24,
        ),
        const SizedBox(width: 8),
        Text(
          'ScoutBox',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: NavigationSection.values
                  .map(
                    (s) => _TopTab(
                      label: s.label,
                      isSelected: section == s,
                      enabled: s.isEnabled,
                      onTap: () => onSectionTap(s),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _TopTab({
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveOpacity = enabled ? 1.0 : 0.38;

    return Opacity(
      opacity: effectiveOpacity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 18,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;

  const _PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bientôt disponible',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
