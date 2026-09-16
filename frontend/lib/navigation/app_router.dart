import 'package:flutter/material.dart';

import 'app_route_path.dart';
import '../providers/navigation_provider.dart';
import '../services/browser_navigation.dart';
import '../views/screens/auth_gate.dart';
import '../views/widgets/app_progress_indicator.dart';

export 'app_route_path.dart';

class AppRouteInformationParser extends RouteInformationParser<AppRoutePath> {
  const AppRouteInformationParser();

  @override
  Future<AppRoutePath> parseRouteInformation(RouteInformation routeInformation) async {
    return AppRoutePath.fromRouteInformation(routeInformation);
  }

  @override
  RouteInformation restoreRouteInformation(AppRoutePath configuration) {
    return RouteInformation(
      uri: configuration.uri,
      state: configuration.routeInformationState,
    );
  }
}

class AppRouterDelegate extends RouterDelegate<AppRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<AppRoutePath> {
  AppRoutePath _path = AppRoutePath.section(NavigationSection.tents);
  bool _isInitializing = true;
  Future<bool> Function()? _confirmLeaveTentCreation;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  AppRoutePath get currentConfiguration => _path;

  Future<void> showTentDetail(String tentId) {
    return _setPathGuarded(AppRoutePath.tentDetail(tentId));
  }

  Future<void> showTentCreation() {
    return _setPathGuarded(AppRoutePath.tentCreation());
  }

  Future<void> showSection(NavigationSection section, {bool hasPreviousAppRoute = true}) {
    return _setPathGuarded(
      AppRoutePath.section(section, hasPreviousAppRoute: hasPreviousAppRoute),
    );
  }

  /// Unguarded on purpose: only reachable from the tent list/detail routes or
  /// from a forced logout, never from an in-progress tent creation.
  void showHome({bool hasPreviousAppRoute = false}) {
    _setPath(
      AppRoutePath.section(NavigationSection.tents, hasPreviousAppRoute: hasPreviousAppRoute),
    );
  }

  /// Leaves the tent creation route after the user already confirmed the
  /// discard, so the leave guard must not prompt a second time.
  void leaveTentCreationConfirmed() {
    _confirmLeaveTentCreation = null;
    if (BrowserNavigation.canGoBack && _path.hasPreviousAppRoute) {
      BrowserNavigation.back();
    } else {
      showHome();
    }
  }

  void setCreationLeaveHandler(Future<bool> Function()? handler) {
    _confirmLeaveTentCreation = handler;
  }

  void completeInitialization() {
    if (!_isInitializing) return;
    _isInitializing = false;
    notifyListeners();
  }

  void _setPath(AppRoutePath path) {
    if (_path.kind == path.kind &&
        _path.section == path.section &&
        _path.tentId == path.tentId &&
        _path.hasPreviousAppRoute == path.hasPreviousAppRoute &&
        _path.uri == path.uri) {
      return;
    }
    _path = path;
    notifyListeners();
  }

  Future<void> _setPathGuarded(
    AppRoutePath path, {
    bool restoreHistoryOnCancel = false,
  }) async {
    if (_path.kind == AppRouteKind.tentCreation && path.kind != AppRouteKind.tentCreation) {
      final confirmLeave = _confirmLeaveTentCreation;
      if (confirmLeave != null && !await confirmLeave()) {
        if (restoreHistoryOnCancel) {
          BrowserNavigation.forward();
        }
        return;
      }
    }
    _setPath(path);
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) {
    return _setPathGuarded(configuration, restoreHistoryOnCancel: true);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: const ValueKey('app'),
          child: _isInitializing
              ? const Scaffold(body: Center(child: AppProgressIndicator()))
              : AuthGate(
                  routePath: _path,
                  onSelectSection: showSection,
                  onOpenTentDetail: showTentDetail,
                  onCreateTent: showTentCreation,
                  onReturnToRoot: showHome,
                  onLeaveTentCreation: leaveTentCreationConfirmed,
                  onCreationLeaveHandlerChanged: setCreationLeaveHandler,
                  onBrowserBack: BrowserNavigation.canGoBack && _path.hasPreviousAppRoute
                      ? BrowserNavigation.back
                      : null,
                ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}
