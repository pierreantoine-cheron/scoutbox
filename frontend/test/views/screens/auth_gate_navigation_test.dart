import 'package:client/models/auth_state.dart';
import 'package:client/models/tent.dart';
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
}

Future<void> _pumpAuthenticatedApp(WidgetTester tester) async {
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
      child: MaterialApp(
        theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
        home: const AuthGate(),
      ),
    ),
  );
  await tester.pumpAndSettle();
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
