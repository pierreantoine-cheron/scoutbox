import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/tent.dart';
import 'package:frontend/models/tent_shape.dart';
import 'package:frontend/repositories/tent_repository.dart';
import 'package:frontend/views/screens/tent_creation_screen.dart';

void main() {
  group('TentCreationScreen', () {
    testWidgets('requires selected shape before continue', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: const MaterialApp(home: TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuer'),
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();

      final enabledContinueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuer'),
      );
      expect(enabledContinueButton.onPressed, isNotNull);
    });

    testWidgets('keeps form values on submit failure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_FailingTentRepository()),
          ],
          child: const MaterialApp(home: TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tent-name-input')),
        'Tente A',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '6',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-comments-input')),
        'Commentaire',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
      await tester.pumpAndSettle();

      expect(find.text('Une tente avec ce nom existe déjà'), findsOneWidget);
      expect(find.text('Tente A'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Commentaire'), findsOneWidget);
    });

    testWidgets('preserves draft when navigating back to shape step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: const MaterialApp(home: TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tent-name-input')),
        'Tente Brouillon',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '8',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-comments-input')),
        'Conserver ce brouillon',
      );

      await tester.tap(find.widgetWithText(TextButton, 'Modifier'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Continuer'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Brouillon'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Conserver ce brouillon'), findsOneWidget);
    });
  });
}

class _SuccessTentRepository extends TentRepository {
  @override
  Future<List<TentShape>> getTentShapes() async {
    return const [
      TentShape(id: '1', name: 'Canadienne', displayOrder: 1, isActive: true),
      TentShape(id: '2', name: 'Tipi', displayOrder: 2, isActive: true),
    ];
  }
}

class _FailingTentRepository extends _SuccessTentRepository {
  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentShapeId,
    required TentOverallState overallState,
    String? comments,
  }) {
    throw const TentRepositoryException(
      code: 'TENT_NAME_EXISTS',
      message: 'Tent name already exists',
    );
  }
}
