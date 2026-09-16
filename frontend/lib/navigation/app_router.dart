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

  void showTentDetail(String tentId) {
    _setPath(AppRoutePath.tentDetail(tentId, hasPreviousAppRoute: true));
  }

  void showTentCreation() {
    _setPath(AppRoutePath.tentCreation(hasPreviousAppRoute: true));
  }

  void showSection(NavigationSection section, {bool hasPreviousAppRoute = true}) {
    _setPath(AppRoutePath.section(section, hasPreviousAppRoute: hasPreviousAppRoute));
  }

  void showHome({bool hasPreviousAppRoute = false}) {
    showSection(NavigationSection.tents, hasPreviousAppRoute: hasPreviousAppRoute);
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

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) async {
    if (_path.kind == AppRouteKind.tentCreation &&
        configuration.kind != AppRouteKind.tentCreation) {
      final confirmLeave = _confirmLeaveTentCreation;
      if (confirmLeave != null && !await confirmLeave()) {
        BrowserNavigation.forward();
        return;
      }
    }
    _setPath(configuration);
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
