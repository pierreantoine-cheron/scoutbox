import 'package:client/navigation/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = AppRouteInformationParser();

  test('parses a tent detail URL', () async {
    final path = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/tents/tent-1')),
    );

    expect(path.tentId, 'tent-1');
    final restored = parser.restoreRouteInformation(path);
    expect(restored.uri.path, '/tents/tent-1');
    expect(restored.state, isNull);
  });

  test('preserves invite query parameters on the root URL', () async {
    final path = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/?server=https%3A%2F%2Fapi.test&invite=ABC')),
    );

    final restored = parser.restoreRouteInformation(path).uri;
    expect(path.tentId, isNull);
    expect(restored.queryParameters['server'], 'https://api.test');
    expect(restored.queryParameters['invite'], 'ABC');
  });

  test('restores whether a detail route has an in-app predecessor', () async {
    final routeInformation = parser.restoreRouteInformation(
      AppRoutePath.tentDetail('tent-1'),
    );
    final path = await parser.parseRouteInformation(routeInformation);

    expect(path.tentId, 'tent-1');
    expect(path.hasPreviousAppRoute, isTrue);
  });

  test('router exposes tent detail and home configurations', () {
    final router = AppRouterDelegate();
    addTearDown(router.dispose);

    router.showTentDetail('tent/with spaces');
    expect(router.currentConfiguration.tentId, 'tent/with spaces');
    expect(router.currentConfiguration.hasPreviousAppRoute, isTrue);

    router.showHome();
    expect(router.currentConfiguration.uri.path, '/');
    expect(router.currentConfiguration.tentId, isNull);
  });
}
