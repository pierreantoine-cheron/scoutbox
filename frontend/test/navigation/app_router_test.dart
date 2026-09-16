import 'package:client/navigation/app_router.dart';
import 'package:client/providers/navigation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = AppRouteInformationParser();

  test('parses a tent detail URL', () async {
    final path = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/tents/tent-1')),
    );

    expect(path.tentId, 'tent-1');
    expect(path.hasPreviousAppRoute, isFalse);
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

  test('parses every full-screen destination', () async {
    final cases = {
      '/': (AppRouteKind.section, NavigationSection.tents),
      '/tags': (AppRouteKind.section, NavigationSection.tags),
      '/parts': (AppRouteKind.section, NavigationSection.parts),
      '/models': (AppRouteKind.section, NavigationSection.models),
      '/settings': (AppRouteKind.section, NavigationSection.settings),
      '/tents/new': (AppRouteKind.tentCreation, NavigationSection.tents),
    };

    for (final entry in cases.entries) {
      final path = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse(entry.key)),
      );

      expect(path.kind, entry.value.$1);
      expect(path.section, entry.value.$2);
      expect(parser.restoreRouteInformation(path).uri.path, entry.key);
    }
  });

  test('canonicalizes unknown URLs to the tents section', () async {
    final path = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/unknown/path')),
    );

    expect(path.kind, AppRouteKind.section);
    expect(path.section, NavigationSection.tents);
    expect(parser.restoreRouteInformation(path).uri.path, '/');
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

    router.showTentCreation();
    expect(router.currentConfiguration.kind, AppRouteKind.tentCreation);

    router.showSection(NavigationSection.settings);
    expect(router.currentConfiguration.section, NavigationSection.settings);
    expect(router.currentConfiguration.uri.path, '/settings');
  });

  test('retains a tent draft when browser navigation is cancelled', () async {
    final router = AppRouterDelegate();
    addTearDown(router.dispose);
    router.showTentCreation();
    router.setCreationLeaveHandler(() async => false);

    await router.setNewRoutePath(AppRoutePath.section(NavigationSection.tags));

    expect(router.currentConfiguration.kind, AppRouteKind.tentCreation);
  });

  test('leaves a tent draft after discard is confirmed', () async {
    final router = AppRouterDelegate();
    addTearDown(router.dispose);
    router.showTentCreation();
    router.setCreationLeaveHandler(() async => true);

    await router.setNewRoutePath(AppRoutePath.section(NavigationSection.tags));

    expect(router.currentConfiguration.section, NavigationSection.tags);
  });
}
