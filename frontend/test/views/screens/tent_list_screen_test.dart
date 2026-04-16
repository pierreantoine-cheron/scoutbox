import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/providers/auth_provider.dart';
import 'package:client/models/tent.dart';
import 'package:client/models/tent_shape.dart';
import 'package:client/providers/tent_list_provider.dart';
import 'package:client/providers/tent_shapes_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/views/screens/tent_list_screen.dart';

void main() {
  group('TentListScreen', () {
    testWidgets('opens logout dialog and cancels', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const [
                Tent(
                  id: '1',
                  name: 'Tente A',
                  size: 6,
                  tentShapeId: 'shape-1',
                  tentShapeName: 'Canadienne',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter ?'), findsOneWidget);
      expect(find.text('Votre session sera fermée.'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Se déconnecter ?'), findsNothing);
    });

    testWidgets('disables logout button while loading', (
      WidgetTester tester,
    ) async {
      const loadingState = AuthState(isLoading: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWithValue(loadingState),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const []),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.onPressed, isNull);
    });

    testWidgets('opens tent creation screen from empty-state action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _TentListAndShapesTestRepository(),
            ),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const []),
            ),
            tentShapesProvider.overrideWith(() => _TentShapesTestNotifier()),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucune tente disponible'), findsOneWidget);

      await tester.tap(find.text('Créer une tente'));
      await tester.pumpAndSettle();

      expect(find.text('Créer une tente'), findsOneWidget);
    });

    testWidgets('renders cards and opens detail stub on tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const [
                Tent(
                  id: 't1',
                  name: 'Tente Atlas',
                  size: 6,
                  tentShapeId: 'shape-1',
                  tentShapeName: 'Canadienne',
                  overallState: TentOverallState.needsRepair,
                  comments: null,
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Forme: Canadienne'), findsOneWidget);

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la tente'), findsOneWidget);
    });

    testWidgets('renders loading skeleton state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(() => _LoadingTentListNotifier()),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(Card), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('renders inline error state and retries', (
      WidgetTester tester,
    ) async {
      var retryCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentListInlineErrorState(
              error: const TentRepositoryException(
                code: 'INTERNAL_ERROR',
                message: 'Erreur serveur. Réessayez.',
              ),
              onRetry: () async {
                retryCallCount++;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Erreur serveur. Réessayez.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);

      await tester.tap(find.text('Réessayer'));
      await tester.pump();

      expect(retryCallCount, equals(1));
    });

    testWidgets('allows pull-to-refresh from the empty state', (
      WidgetTester tester,
    ) async {
      final notifier = _RefreshTrackingTentListNotifier(const []);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentListProvider.overrideWith(() => notifier)],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, 300));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(notifier.refreshCallCount, equals(1));
    });

    testWidgets('renders filtered empty state when filtering is active', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const []),
            ),
            tentListFilteredModeProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune tente ne correspond à vos critères'),
        findsOneWidget,
      );
      expect(find.text('Effacer les filtres'), findsOneWidget);
    });

    testWidgets('opens tent creation screen from fab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _TentListAndShapesTestRepository(),
            ),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const [
                Tent(
                  id: '1',
                  name: 'Tente A',
                  size: 6,
                  tentShapeId: 'shape-1',
                  tentShapeName: 'Canadienne',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
              ]),
            ),
            tentShapesProvider.overrideWith(() => _TentShapesTestNotifier()),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Créer une tente'), findsOneWidget);
    });
  });
}

class _TentListAndShapesTestRepository extends TentRepository {
  @override
  Future<List<Tent>> getTents() async {
    return const [];
  }
}

class _TentListTestNotifier extends TentListNotifier {
  final List<Tent> tents;

  _TentListTestNotifier(this.tents);

  @override
  Future<List<Tent>> build() async => tents;
}

class _LoadingTentListNotifier extends TentListNotifier {
  @override
  Future<List<Tent>> build() => Completer<List<Tent>>().future;
}

class _RefreshTrackingTentListNotifier extends TentListNotifier {
  final List<Tent> tents;

  _RefreshTrackingTentListNotifier(this.tents);

  int refreshCallCount = 0;

  @override
  Future<List<Tent>> build() async => tents;

  @override
  Future<void> refresh() async {
    refreshCallCount++;
  }
}

class _TentShapesTestNotifier extends TentShapesNotifier {
  @override
  Future<List<TentShape>> build() async => const [];
}
