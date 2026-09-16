import 'package:client/models/auth_state.dart';
import 'package:client/models/tent.dart';
import 'package:client/navigation/app_router.dart';
import 'package:client/providers/auth_provider.dart';
import 'package:client/providers/tent_list_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/auth_gate.dart';
import 'package:client/views/screens/tent_detail_screen.dart';
import 'package:client/views/screens/tent_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('system back pops a nested page', (
    WidgetTester tester,
  ) async {
    await _pumpAuthenticatedApp(tester);

    expect(find.byType(TentListScreen), findsOneWidget);
    await tester.tap(find.text('Tente Atlas'));
    await tester.pumpAndSettle();

    expect(find.byType(TentDetailScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(TentDetailScreen), findsNothing);
    expect(find.byType(TentListScreen), findsOneWidget);
  });

  testWidgets(
    'app bar back pops a nested page',
    (WidgetTester tester) async {
      await _pumpAuthenticatedApp(tester);

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();
      expect(find.byType(TentDetailScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.byType(TentDetailScreen), findsNothing);
      expect(find.byType(TentListScreen), findsOneWidget);

      expect(find.byType(BackButton), findsNothing);
    },
  );

  testWidgets('browser history restores tent list and detail routes', (
    WidgetTester tester,
  ) async {
    final routerDelegate = AppRouterDelegate()..completeInitialization();
    final routeInformationProvider = _TestRouteInformationProvider();
    addTearDown(routerDelegate.dispose);
    addTearDown(routeInformationProvider.dispose);

    await _pumpAuthenticatedApp(
      tester,
      app: MaterialApp.router(
        theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
        routeInformationProvider: routeInformationProvider,
        routeInformationParser: const AppRouteInformationParser(),
        routerDelegate: routerDelegate,
      ),
    );

    await tester.tap(find.text('Tente Atlas'));
    await tester.pumpAndSettle();
    expect(find.byType(TentDetailScreen), findsOneWidget);
    expect(routerDelegate.currentConfiguration.uri.path, '/tents/tent-1');

    routeInformationProvider.go('/');
    await tester.pumpAndSettle();
    expect(find.byType(TentListScreen), findsOneWidget);
    expect(find.byType(TentDetailScreen), findsNothing);

    routeInformationProvider.go('/tents/tent-1');
    await tester.pumpAndSettle();
    expect(find.byType(TentDetailScreen), findsOneWidget);
  });

  testWidgets('direct detail back reports the tents URL', (WidgetTester tester) async {
    final routerDelegate = AppRouterDelegate()..completeInitialization();
    final routeInformationProvider = _TestRouteInformationProvider('/tents/tent-1');
    addTearDown(routerDelegate.dispose);
    addTearDown(routeInformationProvider.dispose);

    await _pumpAuthenticatedApp(
      tester,
      app: MaterialApp.router(
        theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
        routeInformationProvider: routeInformationProvider,
        routeInformationParser: const AppRouteInformationParser(),
        routerDelegate: routerDelegate,
      ),
    );

    expect(find.byType(TentDetailScreen), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(TentListScreen), findsOneWidget);
    expect(routeInformationProvider.value.uri.path, '/');
  });
}

Future<void> _pumpAuthenticatedApp(WidgetTester tester, {Widget? app}) async {
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWithValue(const AuthState(isAuthenticated: true)),
        tentRepositoryProvider.overrideWithValue(_TentRepositoryStub()),
        tentListProvider.overrideWith(() => _TentListNotifier()),
      ],
      child:
          app ??
          MaterialApp(
            theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
            home: const AuthGate(),
          ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestRouteInformationProvider extends RouteInformationProvider with ChangeNotifier {
  _TestRouteInformationProvider([String location = '/'])
    : _value = RouteInformation(uri: Uri.parse(location));

  RouteInformation _value;

  @override
  RouteInformation get value => _value;

  void go(String location) {
    _value = RouteInformation(uri: Uri.parse(location));
    notifyListeners();
  }

  @override
  void routerReportsNewRouteInformation(
    RouteInformation routeInformation, {
    RouteInformationReportingType type = RouteInformationReportingType.none,
  }) {
    _value = routeInformation;
  }
}

class _TentListNotifier extends TentListNotifier {
  @override
  Future<List<Tent>> build() async => const [
    Tent(
      id: 'tent-1',
      name: 'Tente Atlas',
      size: 6,
      tentModelId: 'model-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
    ),
  ];
}

class _TentRepositoryStub extends TentRepository {
  @override
  Future<List<Tent>> getTents() async => const [];

  @override
  Future<Tent> getTent(String id) async {
    return Tent(
      id: id,
      name: 'Tente Atlas',
      size: 6,
      tentModelId: 'model-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
    );
  }
}
