import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_bar_config_provider.dart';
import '../providers/route_observer_provider.dart';

mixin RouteAwareAppBarMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, RouteAware {
  RouteObserver<ModalRoute<dynamic>>? _routeObserver;
  ModalRoute<dynamic>? _subscribedRoute;

  void subscribeRouteObserver() {
    _routeObserver ??= ref.read(routeObserverProvider);
    final route = ModalRoute.of(context);
    if (route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        _routeObserver!.unsubscribe(this as RouteAware);
      }
      _routeObserver!.subscribe(this as RouteAware, route);
      _subscribedRoute = route;
    }
  }

  void unsubscribeRouteObserver() {
    _routeObserver?.unsubscribe(this as RouteAware);
    _subscribedRoute = null;
  }

  void dispatchAppBarConfig() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      ref.read(appBarConfigProvider.notifier).set(buildAppBarConfig());
    });
  }

  AppBarConfig buildAppBarConfig();
}
