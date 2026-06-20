import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:client/models/tent.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/tent_creation_screen.dart';

void main() {
  group('TentCreationScreen', () {
    testWidgets('requires selected model before submit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tent-name-input')),
        'TentA',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '6',
      );

      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Créer la tente'),
      );
      expect(submitButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('tent-model-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Créer la tente'),
      );
      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('keeps form values on submit failure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_FailingTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('tent-model-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canadienne'));
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

      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer la tente'));
      await tester.pumpAndSettle();

      expect(find.text('Une tente avec ce nom existe déjà'), findsOneWidget);
      expect(find.text('Tente A'), findsOneWidget);
      expect(find.text('6'), findsWidgets);
      expect(find.text('Commentaire'), findsOneWidget);
    });

    testWidgets('shows success after successful creation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('tent-model-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tent-name-input')),
        'Tente réussite',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '4',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Créer la tente'));
      await tester.pump();
    });

    testWidgets('filters non-digit characters in size field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
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
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
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

      expect(
        find.byKey(const ValueKey('tent-model-dropdown')),
        findsOneWidget,
      );
    });

    testWidgets('back confirmation quitter closes the screen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentCreationHostScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ouvrir création'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tent-model-dropdown')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitter'));
      await tester.pumpAndSettle();

      expect(find.text('Écran hôte'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('tent-model-dropdown')),
        findsNothing,
      );
    });

    testWidgets('shows empty state when no model is available', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _EmptyModelsTentRepository(),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun modèle de tente disponible pour le moment.'),
        findsOneWidget,
      );
    });

    testWidgets('shows error state and retries model loading', (
      WidgetTester tester,
    ) async {
      final repo = _RetryableModelsTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Impossible de charger les modèles de tentes.'),
        findsOneWidget,
      );

      repo.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Réessayer'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('tent-model-dropdown')),
        findsOneWidget,
      );
    });

    testWidgets('validates name field at widget level', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('tent-model-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('tent-name-input')),
        'Un nom',
      );
      await tester.enterText(
        find.byKey(const ValueKey('tent-size-input')),
        '6',
      );
      await tester.pumpAndSettle();

      final enabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Créer la tente'),
      );
      expect(enabledButton.onPressed, isNotNull);

      await tester.enterText(
        find.byKey(const ValueKey('tent-name-input')),
        '',
      );
      await tester.pumpAndSettle();

      final disabledButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Créer la tente'),
      );
      expect(disabledButton.onPressed, isNull);
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
        await tester.tap(find.widgetWithText(ElevatedButton, 'Créer la tente'));
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_FailingTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('tent-model-dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canadienne'));
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
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final commentsField = tester.widget<TextFormField>(
        find.byKey(const ValueKey('tent-comments-input')),
      );
      expect(commentsField.validator, isNotNull);
      expect(
        commentsField.validator!.call('a' * 501),
        equals('Le commentaire ne doit pas dépasser 500 caractères'),
      );
    });

    testWidgets('selects state with segmented button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentCreationScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bon état'), findsOneWidget);
      expect(find.text('À réparer'), findsOneWidget);
      expect(find.text('Inutilisable'), findsOneWidget);
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

class _EmptyModelsTentRepository extends _SuccessTentRepository {
  @override
  Future<List<TentModel>> getTentModels() async {
    return const [];
  }
}

class _RetryableModelsTentRepository extends _SuccessTentRepository {
  bool fail = true;

  @override
  Future<List<TentModel>> getTentModels() async {
    if (fail) {
      throw Exception('network');
    }

    return super.getTentModels();
  }
}

class _SuccessTentRepository extends TentRepository {
  @override
  Future<List<TentModel>> getTentModels() async {
    return const [
      TentModel(id: '1', name: 'Canadienne', displayOrder: 1, isActive: true),
      TentModel(id: '2', name: 'Tipi', displayOrder: 2, isActive: true),
    ];
  }

  @override
  Future<Tent> createTent({
    required String name,
    required int size,
    required String tentModelId,
    required TentOverallState overallState,
    String? comments,
  }) async {
    return Tent(
      id: 'tent-1',
      name: name,
      size: size,
      tentModelId: tentModelId,
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
    required String tentModelId,
    required TentOverallState overallState,
    String? comments,
  }) {
    throw const TentRepositoryException(
      code: 'TENT_NAME_EXISTS',
      message: 'Tent name already exists',
    );
  }
}
