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

    testWidgets('renders desktop table for wide screens', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('Etat'), findsOneWidget);
      expect(find.text('Taille'), findsOneWidget);
      expect(find.text('Forme'), findsOneWidget);
      expect(find.text('Derniere mise a jour'), findsOneWidget);
      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Forme: Canadienne'), findsNothing);
    });

    testWidgets('sorts desktop rows ascending then descending', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const [
                Tent(
                  id: 't1',
                  name: 'Zulu',
                  size: 2,
                  tentShapeId: 'shape-1',
                  tentShapeName: 'Tipi',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
                Tent(
                  id: 't2',
                  name: 'Alpha',
                  size: 4,
                  tentShapeId: 'shape-2',
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

      expect(find.text('Zulu').evaluate().single.widget, isA<Text>());

      await tester.tap(find.text('Nom'));
      await tester.pumpAndSettle();

      final textsAfterAsc = find
          .byType(Text)
          .evaluate()
          .map((element) {
            final text = element.widget as Text;
            return text.data;
          })
          .whereType<String>()
          .toList();
      expect(
        textsAfterAsc.indexOf('Alpha') < textsAfterAsc.indexOf('Zulu'),
        isTrue,
      );

      await tester.tap(find.text('Nom'));
      await tester.pumpAndSettle();

      final textsAfterDesc = find
          .byType(Text)
          .evaluate()
          .map((element) {
            final text = element.widget as Text;
            return text.data;
          })
          .whereType<String>()
          .toList();
      expect(
        textsAfterDesc.indexOf('Zulu') < textsAfterDesc.indexOf('Alpha'),
        isTrue,
      );
    });

    testWidgets('opens detail stub from desktop row tap', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la tente'), findsOneWidget);
    });

    testWidgets('renders cards and opens detail stub on tap on mobile', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Canadienne'), findsOneWidget);

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.text('Détail de la tente'), findsOneWidget);
    });

    testWidgets('keeps mobile cards below desktop breakpoint', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(767, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
          ],
          child: const MaterialApp(home: TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsOneWidget);
      expect(find.text('Nom'), findsNothing);
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

Future<void> _setViewportSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

List<Tent> _buildSampleTents() {
  return const [
    Tent(
      id: 't1',
      name: 'Tente Atlas',
      size: 6,
      tentShapeId: 'shape-1',
      tentShapeName: 'Canadienne',
      overallState: TentOverallState.needsRepair,
      comments: null,
    ),
  ];
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
