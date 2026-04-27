import 'dart:async';

import 'package:client/models/part.dart';
import 'package:client/models/tent.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/views/screens/tent_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TentDetailScreen', () {
    testWidgets('renders loading then detail content', (tester) async {
      final completer = Completer<Tent>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _CompleterTentRepository(completer.future),
            ),
          ],
          child: const MaterialApp(home: TentDetailScreen(tentId: 'tent-1')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(_buildTent());
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Commentaires'), findsOneWidget);
      expect(find.text('Une tente de test.'), findsOneWidget);
    });

    testWidgets('renders french error and retries', (tester) async {
      final repository = _SwitchingTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(home: TentDetailScreen(tentId: 'tent-1')),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('Impossible de charger le détail de la tente'),
        findsOneWidget,
      );
      expect(find.text('Réessayer'), findsOneWidget);

      repository.shouldFail = false;
      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(repository.callCount, greaterThanOrEqualTo(2));
    });

    testWidgets('expands part rows and shows fallback comments', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: const MaterialApp(home: TentDetailScreen(tentId: 'tent-1')),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Toile extérieure'), findsOneWidget);

      await tester.tap(find.text('Toile extérieure'));
      await tester.pumpAndSettle();

      expect(find.text('Bon état'), findsWidgets);
      expect(find.textContaining('Aucun commentaire'), findsWidgets);
    });
  });
}

Tent _buildTent() {
  return Tent(
    id: 'tent-1',
    name: 'Tente Atlas',
    size: 6,
    tentShapeId: 'shape-1',
    tentShapeName: 'Canadienne',
    overallState: TentOverallState.good,
    comments: 'Une tente de test.',
    createdAt: DateTime.utc(2026, 4, 10, 9),
    updatedAt: DateTime.utc(2026, 4, 12, 18, 30),
    parts: const [
      Part(
        id: 'part-1',
        partKindId: 'kind-1',
        partKindName: 'Toile extérieure',
        displayOrder: 1,
        state: PartState.good,
        comments: null,
      ),
    ],
  );
}

class _CompleterTentRepository extends TentRepository {
  final Future<Tent> _future;

  _CompleterTentRepository(this._future);

  @override
  Future<Tent> getTent(String id) => _future;
}

class _SuccessTentRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async => _buildTent();
}

class _SwitchingTentRepository extends TentRepository {
  int callCount = 0;
  bool shouldFail = true;

  @override
  Future<Tent> getTent(String id) async {
    callCount++;
    if (shouldFail) {
      throw const TentRepositoryException(
        message: 'Impossible de charger le détail de la tente.',
      );
    }
    return _buildTent();
  }
}
