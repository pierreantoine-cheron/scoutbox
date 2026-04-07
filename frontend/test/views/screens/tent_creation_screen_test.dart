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

    testWidgets('shows success snackbar after successful creation', (
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
        'Tente réussite',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '4',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
      await tester.pump();

      expect(find.text('Tente créée avec succès'), findsOneWidget);
    });

    testWidgets('filters non-digit characters in size field', (
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

      final sizeFinder = find.byKey(const ValueKey('tent-size-input'));
      await tester.enterText(sizeFinder, '12a-3b');
      await tester.pumpAndSettle();

      final sizeField = tester.widget<TextFormField>(sizeFinder);
      expect(sizeField.controller?.text, equals('123'));
    });

    testWidgets('intercepts back button and asks confirmation', (
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

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Quitter la création ?'), findsOneWidget);
      expect(
        find.text('Votre brouillon sera conservé pour plus tard.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Rester'));
      await tester.pumpAndSettle();

      expect(find.text('Créer une tente'), findsOneWidget);
    });

    testWidgets('back confirmation quitter closes the screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: const MaterialApp(home: _TentCreationHostScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ouvrir création'));
      await tester.pumpAndSettle();
      expect(find.text('Créer une tente'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();

      expect(find.text('Écran hôte'), findsOneWidget);
      expect(find.text('Créer une tente'), findsNothing);
    });

    testWidgets('shows empty state when no shape is available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _EmptyShapesTentRepository(),
            ),
          ],
          child: const MaterialApp(home: TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune forme de tente disponible pour le moment.'),
        findsOneWidget,
      );
      final continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuer'),
      );
      expect(continueButton.onPressed, isNull);
    });

    testWidgets('shows error state and retries shape loading', (
      WidgetTester tester,
    ) async {
      final repo = _RetryableShapesTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Impossible de charger les formes de tentes.'),
        findsOneWidget,
      );

      repo.fail = false;
      await tester.tap(find.widgetWithText(ElevatedButton, 'Réessayer'));
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsOneWidget);
    });

    testWidgets('validates name field at widget level', (
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

      await tester.enterText(find.byKey(const ValueKey('tent-name-input')), '');
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '6',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
      await tester.pumpAndSettle();

      expect(find.text('Le nom de la tente est requis'), findsOneWidget);
    });

    testWidgets('validates size boundaries at widget level', (
      WidgetTester tester,
    ) async {
      Future<void> submitWithSize(String name, String size) async {
        await tester.enterText(
          find.byKey(const ValueKey('tent-name-input')),
          name,
        );
        await tester.enterText(
          find.byKey(const ValueKey('tent-size-input')),
          size,
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Créer'));
        await tester.pumpAndSettle();
      }

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

      await submitWithSize('Tente Min', '1');
      expect(find.text('La taille doit être un nombre positif'), findsNothing);

      await submitWithSize('Tente Max', '100');
      expect(find.text('La taille doit être un nombre positif'), findsNothing);

      await submitWithSize('Tente TooBig', '101');
      expect(
        find.text('La taille doit être un nombre positif'),
        findsOneWidget,
      );
    });

    testWidgets('validates comments max length', (WidgetTester tester) async {
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

      final commentsField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('tent-comments-input')),
      );

      final validator = commentsField.validator;
      expect(validator, isNotNull);
      expect(
        validator!.call('a' * 501),
        equals('Le commentaire ne doit pas dépasser 500 caractères'),
      );
    });
  });
}

class _TentCreationHostScreen extends StatelessWidget {
  const _TentCreationHostScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Écran hôte')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TentCreationScreen()),
            );
          },
          child: const Text('Ouvrir création'),
        ),
      ),
    );
  }
}

class _EmptyShapesTentRepository extends _SuccessTentRepository {
  @override
  Future<List<TentShape>> getTentShapes() async {
    return const [];
  }
}

class _RetryableShapesTentRepository extends _SuccessTentRepository {
  bool fail = true;

  @override
  Future<List<TentShape>> getTentShapes() async {
    if (fail) {
      throw Exception('network');
    }

    return super.getTentShapes();
  }
}

class _SuccessTentRepository extends TentRepository {
  @override
  Future<List<TentShape>> getTentShapes() async {
    return const [
      TentShape(id: '1', name: 'Canadienne', displayOrder: 1, isActive: true),
      TentShape(id: '2', name: 'Tipi', displayOrder: 2, isActive: true),
    ];
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentShapeId,
    required TentOverallState overallState,
    String? comments,
  }) async {
    return Tent(
      id: 'tent-1',
      name: name,
      size: size,
      tentShapeId: tentShapeId,
      overallState: overallState,
      comments: comments,
    );
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
