import 'package:flutter/material.dart';

import '../services/browser_navigation.dart';
import '../views/screens/auth_gate.dart';
import '../views/widgets/app_progress_indicator.dart';

class AppRoutePath {
  static const _hasPreviousAppRouteKey = 'hasPreviousAppRoute';

  final Uri uri;
  final bool hasPreviousAppRoute;

  const AppRoutePath(this.uri, {this.hasPreviousAppRoute = false});

  AppRoutePath.home() : uri = Uri(path: '/'), hasPreviousAppRoute = false;

  factory AppRoutePath.tentDetail(String tentId) {
    return AppRoutePath(
      Uri(pathSegments: ['', 'tents', tentId]),
      hasPreviousAppRoute: true,
    );
  }

  factory AppRoutePath.fromRouteInformation(RouteInformation routeInformation) {
    final state = routeInformation.state;
    return AppRoutePath(
      routeInformation.uri,
      hasPreviousAppRoute: state is Map<Object?, Object?> && state[_hasPreviousAppRouteKey] == true,
    );
  }

  Object? get routeInformationState =>
      hasPreviousAppRoute ? const {_hasPreviousAppRouteKey: true} : null;

  String? get tentId {
    final segments = uri.pathSegments;
    if (segments.length != 2 || segments.first != 'tents' || segments.last.isEmpty) {
      return null;
    }
    return segments.last;
  }
}

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
  AppRoutePath _path = AppRoutePath.home();
  bool _isInitializing = true;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  AppRoutePath get currentConfiguration => _path;

  void showTentDetail(String tentId) {
    _setPath(AppRoutePath.tentDetail(tentId));
  }

  void showHome() {
    _setPath(AppRoutePath.home());
  }

  void completeInitialization() {
    if (!_isInitializing) return;
    _isInitializing = false;
    notifyListeners();
  }

  void _setPath(AppRoutePath path) {
    if (_path.uri == path.uri) return;
    _path = path;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(AppRoutePath configuration) async {
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
                  browserTentId: _path.tentId,
                  onOpenTentDetail: showTentDetail,
                  onReturnToRoot: showHome,
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
