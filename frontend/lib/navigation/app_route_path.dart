import 'package:flutter/material.dart';

import '../providers/navigation_provider.dart';

enum AppRouteKind { section, tentCreation, tentDetail }

class AppRoutePath {
  static const _hasPreviousAppRouteKey = 'hasPreviousAppRoute';

  final AppRouteKind kind;
  final NavigationSection section;
  final String? tentId;
  final bool hasPreviousAppRoute;
  final Uri uri;

  const AppRoutePath._({
    required this.kind,
    required this.section,
    required this.tentId,
    required this.hasPreviousAppRoute,
    required this.uri,
  });

  factory AppRoutePath.section(
    NavigationSection section, {
    bool hasPreviousAppRoute = false,
    Uri? uri,
  }) {
    return AppRoutePath._(
      kind: AppRouteKind.section,
      section: section,
      tentId: null,
      hasPreviousAppRoute: hasPreviousAppRoute,
      uri: uri ?? _sectionUri(section),
    );
  }

  factory AppRoutePath.tentCreation({bool hasPreviousAppRoute = true}) {
    return AppRoutePath._(
      kind: AppRouteKind.tentCreation,
      section: NavigationSection.tents,
      tentId: null,
      hasPreviousAppRoute: hasPreviousAppRoute,
      uri: Uri(path: '/tents/new'),
    );
  }

  factory AppRoutePath.tentDetail(String tentId, {bool hasPreviousAppRoute = true}) {
    return AppRoutePath._(
      kind: AppRouteKind.tentDetail,
      section: NavigationSection.tents,
      tentId: tentId,
      hasPreviousAppRoute: hasPreviousAppRoute,
      uri: Uri(pathSegments: ['', 'tents', tentId]),
    );
  }

  factory AppRoutePath.fromRouteInformation(RouteInformation routeInformation) {
    final uri = routeInformation.uri;
    final state = routeInformation.state;
    final hasPreviousAppRoute =
        state is Map<Object?, Object?> && state[_hasPreviousAppRouteKey] == true;
    final segments = uri.pathSegments;

    if (segments.isEmpty) {
      return AppRoutePath.section(
        NavigationSection.tents,
        hasPreviousAppRoute: hasPreviousAppRoute,
        uri: uri,
      );
    }

    if (segments.length == 1) {
      final section = switch (segments.single) {
        'tags' => NavigationSection.tags,
        'parts' => NavigationSection.parts,
        'models' => NavigationSection.models,
        'settings' => NavigationSection.settings,
        _ => null,
      };
      if (section != null) {
        return AppRoutePath.section(section, hasPreviousAppRoute: hasPreviousAppRoute);
      }
    }

    if (segments.length == 2 && segments.first == 'tents') {
      if (segments.last == 'new') {
        return AppRoutePath.tentCreation(hasPreviousAppRoute: hasPreviousAppRoute);
      }
      if (segments.last.isNotEmpty) {
        return AppRoutePath.tentDetail(
          segments.last,
          hasPreviousAppRoute: hasPreviousAppRoute,
        );
      }
    }

    return AppRoutePath.section(NavigationSection.tents);
  }

  Object? get routeInformationState =>
      hasPreviousAppRoute ? const {_hasPreviousAppRouteKey: true} : null;

  bool get isLeaf => kind != AppRouteKind.section;

  static Uri _sectionUri(NavigationSection section) {
    return switch (section) {
      NavigationSection.tents => Uri(path: '/'),
      NavigationSection.tags => Uri(path: '/tags'),
      NavigationSection.parts => Uri(path: '/parts'),
      NavigationSection.models => Uri(path: '/models'),
      NavigationSection.settings => Uri(path: '/settings'),
    };
  }
}
