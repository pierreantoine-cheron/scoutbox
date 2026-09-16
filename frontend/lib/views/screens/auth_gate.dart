import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/tent.dart';
import '../../navigation/app_route_path.dart';
import '../../providers/providers.dart';
import '../../services/deep_link_service.dart';
import '../../utils/design_constants.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'models_screen.dart';
import 'part_kinds_screen.dart';
import 'tags_screen.dart';
import 'tent_detail_screen.dart';
import 'tent_creation_screen.dart';
import 'tent_list_screen.dart';
import 'settings_screen.dart';

class AuthGate extends ConsumerStatefulWidget {
  final AppRoutePath routePath;
  final ValueChanged<NavigationSection> onSelectSection;
  final ValueChanged<String> onOpenTentDetail;
  final VoidCallback onCreateTent;
  final VoidCallback onReturnToRoot;
  final VoidCallback onLeaveTentCreation;
  final ValueChanged<Future<bool> Function()?> onCreationLeaveHandlerChanged;
  final VoidCallback? onBrowserBack;

  const AuthGate({
    super.key,
    required this.routePath,
    required this.onSelectSection,
    required this.onOpenTentDetail,
    required this.onCreateTent,
    required this.onReturnToRoot,
    required this.onLeaveTentCreation,
    required this.onCreationLeaveHandlerChanged,
    this.onBrowserBack,
  });

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final RouteObserver<ModalRoute<dynamic>> _routeObserver;
  bool _checkedAuthenticatedInitialLink = false;

  @override
  void initState() {
    super.initState();
    _routeObserver = ref.read(routeObserverProvider);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (previous?.isAuthenticated == true && !next.isAuthenticated) {
        widget.onReturnToRoot();
      }
    });

    ref.listen<DeepLinkEvent?>(deepLinkProvider, (previous, next) {
      if (next != null && authState.isAuthenticated) {
        if (next.kind == DeepLinkEventKind.validInvite) {
          _showAuthenticatedDeepLinkBlocker();
        } else {
          _showIncompleteDeepLinkWarning();
        }
        ref.read(deepLinkProvider.notifier).clear();
        DeepLinkService.consumeInitialLink();
      }
    });

    if (authState.isAuthenticated) {
      _checkAuthenticatedInitialLinkOnce();
      final NavigationSection section = widget.routePath.section;
      final appBarConfig = ref.watch(appBarConfigProvider);
      final successTrigger = ref.watch(successIndicatorProvider);
      final isDesktop = MediaQuery.sizeOf(context).width >= DesignConstants.desktopBreakpoint;

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
                shape: const RoundedRectangleBorder(),
                surfaceTintColor: Colors.transparent,
                child: ScoutBoxNavigationDrawer(
                  selectedSection: section,
                  onSelectSection: (s) {
                    _scaffoldKey.currentState?.closeDrawer();
                    widget.onSelectSection(s);
                  },
                ),
              ),
        floatingActionButton: isDesktop ? null : appBarConfig.fab,
        body: NavigatorPopHandler(
          onPopWithResult: (_) => _handleBack(),
          child: Navigator(
            key: _navigatorKey,
            observers: [_routeObserver],
            pages: _buildPages(section),
            onDidRemovePage: _handlePageRemoved,
          ),
        ),
      );
    }

    return authState.showLoginScreen ? const LoginScreen() : const RegisterScreen();
  }

  void _handleBack() {
    final routePath = widget.routePath;
    if (routePath.kind == AppRouteKind.tentCreation) {
      _navigatorKey.currentState?.maybePop();
      return;
    }

    if (routePath.isLeaf) {
      final onBrowserBack = widget.onBrowserBack;
      if (onBrowserBack != null) {
        onBrowserBack();
      } else {
        widget.onReturnToRoot();
      }
      return;
    }

    _navigatorKey.currentState?.maybePop();
  }

  List<Page<void>> _buildPages(NavigationSection section) {
    final routePath = widget.routePath;
    return [
      MaterialPage<void>(
        key: ValueKey('section-${section.name}'),
        child: _buildRootScreen(section),
      ),
      if (routePath.kind == AppRouteKind.tentDetail)
        MaterialPage<void>(
          key: ValueKey('tent-${routePath.tentId}'),
          child: TentDetailScreen(
            tentId: routePath.tentId!,
            onManageTags: () => widget.onSelectSection(NavigationSection.tags),
          ),
        ),
      if (routePath.kind == AppRouteKind.tentCreation)
        MaterialPage<void>(
          key: const ValueKey('tent-creation'),
          child: TentCreationScreen(
            onCreated: _handleTentCreated,
            onLeaveConfirmed: widget.onLeaveTentCreation,
            onLeaveHandlerChanged: widget.onCreationLeaveHandlerChanged,
          ),
        ),
    ];
  }

  void _handlePageRemoved(Page<void> page) {
    if (!widget.routePath.isLeaf) return;

    final key = page.key;
    if (key is! ValueKey<String> || !key.value.startsWith('tent-')) {
      return;
    }

    widget.onReturnToRoot();
  }

  void _handleTentCreated(Tent tent) {
    ref.read(tentListProvider.notifier).onTentCreated(tent);
    widget.onLeaveTentCreation();
  }

  void _checkAuthenticatedInitialLinkOnce() {
    if (_checkedAuthenticatedInitialLink) return;
    _checkedAuthenticatedInitialLink = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kIsWeb) {
        final webData = DeepLinkService.parseWebQueryParams(Uri.base);
        if (webData != null) {
          _showAuthenticatedDeepLinkBlocker();
          ref.read(deepLinkProvider.notifier).clear();
          return;
        }
      }

      final uri = await ref.read(deepLinkServiceProvider).getInitialLink();
      if (!mounted || uri == null || !DeepLinkService.isInviteLink(uri)) return;

      final data = DeepLinkService.parseInviteLink(uri);
      if (data != null) {
        _showAuthenticatedDeepLinkBlocker();
      } else {
        _showIncompleteDeepLinkWarning();
      }
      ref.read(deepLinkProvider.notifier).clear();
    });
  }

  void _showAuthenticatedDeepLinkBlocker() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Déconnectez-vous avant d'utiliser un lien d'invitation"),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showIncompleteDeepLinkWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Le lien d'invitation est incomplet"),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _buildRootScreen(NavigationSection section) {
    return switch (section) {
      NavigationSection.tents => TentListScreen(
        onOpenTentDetail: widget.onOpenTentDetail,
        onSwitchToTags: () => widget.onSelectSection(NavigationSection.tags),
        onCreateTent: widget.onCreateTent,
      ),
      NavigationSection.tags => const TagsScreen(),
      NavigationSection.parts => const PartKindsScreen(),
      NavigationSection.models => const ModelsScreen(),
      NavigationSection.settings => const SettingsScreen(),
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
        onPressed: _handleBack,
      );
    }

    Widget? title;
    if (config.title != null) {
      title = config.title;
    } else if (isRootScreen && isDesktop) {
      title = _DesktopTitleRow(
        section: section,
        onSectionTap: widget.onSelectSection,
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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
  final VoidCallback onTap;

  const _TopTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        onTap: onTap,
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
    );
  }
}
