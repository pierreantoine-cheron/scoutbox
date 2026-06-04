// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:client/models/part.dart';
import 'package:client/models/part_kind.dart';
import 'package:client/models/tag.dart';
import 'package:client/models/tent.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/models/tent_history_item.dart';
import 'package:client/providers/success_indicator_provider.dart';
import 'package:client/providers/tent_models_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/views/screens/tent_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    binding.window.physicalSizeTestValue = const Size(1200, 1200);
    binding.window.devicePixelRatioTestValue = 1;
  });

  tearDownAll(() {
    binding.window.clearPhysicalSizeTestValue();
    binding.window.clearDevicePixelRatioTestValue();
  });

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
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const TentDetailScreen(tentId: 'tent-1'),
          ),
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
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: const TentDetailScreen(tentId: 'tent-1'),
          ),
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

    testWidgets('shows part state and fallback comments without expanding', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Toile extérieure'), findsOneWidget);
      expect(find.text('Bon état'), findsWidgets);
      expect(find.textContaining('Ajouter un commentaire'), findsWidgets);
    });

    testWidgets('shows assigned tags in tags section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _StaticTentRepository(
                _buildTent(tags: [_tag('tag-1', 'Groupe A')]),
              ),
            ),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Étiquettes'), findsAtLeast(1));
      expect(find.text('Groupe A'), findsOneWidget);
    });

    testWidgets('shows empty tag state when no tags are assigned', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(_SuccessTentRepository()),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aucune étiquette assignée'), findsOneWidget);
      expect(
        find.text('Appuyez sur + pour ajouter des étiquettes'),
        findsOneWidget,
      );
    });
  });

  group('TentDetailScreen inline editing', () {
    testWidgets('shows edit icons on editable fields', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    });

    testWidgets('opens name field editor on tap', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Valider'), findsOneWidget);
      expect(find.byTooltip('Annuler'), findsOneWidget);
    });

    testWidgets('cancelling name edit with no changes returns to read-only', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(repo.updateCallCount, equals(0));
    });

    testWidgets('cancelling name edit with changes discards local value', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField.first, 'Nouveau nom');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(repo.updateCallCount, equals(0));
    });

    testWidgets(
      'confirming valid name edit updates field and shows new value',
      (tester) async {
        final repo = _EditableTentRepository();
        final container = ProviderContainer(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: _testApp()),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Tente Atlas'));
        await tester.pumpAndSettle();

        final textField = find.byType(TextField);
        await tester.enterText(textField.first, 'Tente Renommée');
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Valider'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        expect(repo.updateCallCount, equals(1));
        expect(find.text('Tente Renommée'), findsOneWidget);
        expect(container.read(successIndicatorProvider), equals(1));
        expect(find.byTooltip('Valider'), findsNothing);
      },
    );

    testWidgets('update failure shows inline error banner', (tester) async {
      final repo = _FailingUpdateTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField.first, 'Tente Erreur');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Valider'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Une erreur est survenue'), findsOneWidget);
      expect(find.byType(TextButton), findsAtLeast(1));
      expect(find.byTooltip('Valider'), findsOneWidget);
    });

    testWidgets('retry resubmits the failed attempted value', (tester) async {
      final repo = _FlakyUpdateTentRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _testApp()),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField.first, 'Tente Retentée');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Valider'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TextButton), findsAtLeast(1));

      await tester.ensureVisible(find.text('Réessayer').last);
      await tester.tap(find.text('Réessayer').last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.updateCallCount, equals(2));
      expect(find.text('Tente Retentée'), findsOneWidget);
      expect(container.read(successIndicatorProvider), equals(1));
    });

    testWidgets('subsequent edits keep previously saved field values', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Tente Renommée');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Valider'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('6 places'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '8');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Valider'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.updateCallCount, equals(2));
      expect(find.text('Tente Renommée'), findsOneWidget);
      expect(find.text('8 places'), findsOneWidget);
    });

    testWidgets('parts remain read-only when fields are edited inline', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.text('Éléments'), findsOneWidget);
      expect(find.text('Toile extérieure'), findsOneWidget);
    });

    testWidgets('archive button is enabled for active tent', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      final archiveButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Archiver'),
      );

      expect(archiveButton.onPressed, isNotNull);
    });

    testWidgets('archive confirmation can be canceled without API call', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Archiver'));
      await tester.pumpAndSettle();

      expect(find.text('Archiver la tente'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(repo.archiveCallCount, equals(0));
    });

    testWidgets('archive confirms and calls repository once', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Archiver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(repo.archiveCallCount, equals(1));
    });

    testWidgets('archive failure keeps user on detail and shows error', (
      tester,
    ) async {
      final repo = _ArchiveFailingTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Archiver'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pump();

      expect(
        find.text('Impossible d\'archiver la tente. Réessayez.'),
        findsOneWidget,
      );
      expect(find.text('Tente Atlas'), findsOneWidget);
    });

    testWidgets('archived tent shows archiving chip and disables editing', (
      tester,
    ) async {
      final repo = _ArchivedTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Archivée'), findsOneWidget);

      final archiveButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Archiver'),
      );
      expect(archiveButton.onPressed, isNull);

      // Tap name field — should not enter edit mode
      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<PartState>).first);
      await tester.pumpAndSettle();
      expect(find.text('À réparer'), findsNothing);
    });

    testWidgets('comments field shows character counter when editing', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Une tente de test.'));
      await tester.pumpAndSettle();

      expect(find.textContaining('/500'), findsWidgets);
    });

    testWidgets('size field opens editor on tap', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('6 places'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Valider'), findsOneWidget);
      expect(find.byTooltip('Annuler'), findsOneWidget);

      await tester.tap(find.byTooltip('Annuler'));
      await tester.pumpAndSettle();
    });

    testWidgets('overall state shows dropdown arrow', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);
    });

    testWidgets('selecting the current overall state does not update', (
      tester,
    ) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<TentOverallState>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bon état').last);
      await tester.pumpAndSettle();

      expect(repo.updateCallCount, equals(0));
      expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);
    });

    testWidgets('model chip shows model name and dropdown', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(repo),
            tentModelsProvider.overrideWith(() => _FixedModelsNotifier()),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsWidgets);

      await tester.tap(find.text('Canadienne'));
      await tester.pumpAndSettle();

      expect(find.text('Tipi'), findsOneWidget);

      await tester.tap(find.text('Tipi'));
      await tester.pumpAndSettle();

      expect(repo.updateCallCount, equals(1));
    });

    testWidgets('part state selection updates row and fires success feedback', (
      tester,
    ) async {
      final repo = _EditableTentRepository();
      final container = ProviderContainer(
        overrides: [tentRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _testApp()),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byType(PopupMenuButton<PartState>).first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('À réparer').last,
          matching: find.byType(PopupMenuItem<PartState>),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.partUpdateCallCount, equals(1));
      expect(find.text('À réparer'), findsWidgets);
      expect(container.read(successIndicatorProvider), equals(1));
    });

    testWidgets('part comment editor enforces max length', (tester) async {
      final repo = _EditableTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Ajouter un commentaire'));
      await tester.pumpAndSettle();

      final textFields = tester.widgetList<TextField>(find.byType(TextField));
      final commentField = textFields.firstWhere(
        (tf) => tf.maxLength == 500,
        orElse: () => fail('No comment TextField with maxLength 500 found'),
      );

      expect(commentField.maxLength, equals(500));
      expect(repo.partUpdateCallCount, equals(0));
    });

    testWidgets(
      'failed selected part removal keeps selection and shows error',
      (tester) async {
        final repo = _FailingRemovePartRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [tentRepositoryProvider.overrideWithValue(repo)],
            child: _testApp(),
          ),
        );

        await tester.pumpAndSettle();
        await tester.longPress(find.text('Toile extérieure'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Supprimer les pièces sélectionnées'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Supprimer'));
        await tester.pumpAndSettle();

        expect(
          find.text('Une erreur est survenue. Veuillez réessayer.'),
          findsOneWidget,
        );
        expect(find.byTooltip('Annuler la sélection'), findsOneWidget);
      },
    );

    testWidgets('add sheet disables submit for empty search results', (
      tester,
    ) async {
      final repo = _PartKindTentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ajouter une pièce'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Double toit'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'introuvable');
      await tester.pumpAndSettle();

      expect(find.text('Aucun type de pièce trouvé'), findsOneWidget);
      final addButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Ajouter').last,
          matching: find.byType(FilledButton),
        ),
      );
      expect(addButton.onPressed, isNull);
    });

    testWidgets('removed part disappears after prior tent edit', (
      tester,
    ) async {
      final repo = _PartRemovalAfterEditRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Tente Modifiée');
      await tester.tap(find.byTooltip('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('Toile extérieure'), findsOneWidget);

      await tester.longPress(find.text('Toile extérieure'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Supprimer les pièces sélectionnées'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();

      expect(find.text('Toile extérieure'), findsNothing);
      expect(find.text('Aucun élément associé à cette tente.'), findsOneWidget);

      await tester.tap(find.byTooltip('Ajouter une pièce'));
      await tester.pumpAndSettle();

      expect(find.text('Toile extérieure'), findsOneWidget);
      expect(
        find.text('Toutes les pièces sont déjà présentes sur cette tente.'),
        findsNothing,
      );
    });

    testWidgets(
      'selecting the current part state does not update or fire success',
      (tester) async {
        final repo = _EditableTentRepository();
        final container = ProviderContainer(
          overrides: [tentRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(container: container, child: _testApp()),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byType(PopupMenuButton<PartState>).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.ancestor(
            of: find.text('Bon état').last,
            matching: find.byType(PopupMenuItem<PartState>),
          ),
        );
        await tester.pumpAndSettle();

        expect(repo.partUpdateCallCount, equals(0));
        expect(container.read(successIndicatorProvider), equals(0));
      },
    );
  });

  group('TentDetailScreen history section', () {
    setUpAll(() async {
      await initializeDateFormatting('fr_FR');
    });

    testWidgets('shows history loading then content', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _HistorySuccessRepository(),
            ),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Historique'), findsOneWidget);
      expect(find.textContaining('Tente créée le'), findsOneWidget);
    });

    // Error/retry behavior is tested in tent_history_provider_test.dart

    testWidgets('shows history category filters', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _HistorySuccessRepository(),
            ),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tout'), findsOneWidget);
      expect(find.text('Tente'), findsOneWidget);
      expect(find.text('États'), findsOneWidget);
      expect(find.text('Pièces'), findsOneWidget);
      expect(find.text('Étiquettes'), findsAtLeast(1));
      expect(find.text('Archive'), findsOneWidget);
    });

    testWidgets('shows tag audit events in history', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _HistorySuccessRepository(),
            ),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('Étiquette ajoutée : Patrouille'),
        findsOneWidget,
      );
    });

    testWidgets('archived tent still shows history', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _HistoryArchivedRepository(),
            ),
          ],
          child: _testApp(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Historique'), findsOneWidget);
      expect(find.textContaining('Tente créée le'), findsOneWidget);
      expect(find.textContaining('Tente archivée le'), findsOneWidget);
    });
  });
}

Widget _testApp() {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: const TentDetailScreen(tentId: 'tent-1'),
  );
}

Tent _buildTent({List<Tag> tags = const []}) {
  return Tent(
    id: 'tent-1',
    name: 'Tente Atlas',
    size: 6,
    tentModelId: 'shape-1',
    tentModelName: 'Canadienne',
    overallState: TentOverallState.good,
    comments: 'Une tente de test.',
    createdAt: DateTime.utc(2026, 4, 10, 9),
    updatedAt: DateTime.utc(2026, 4, 12, 18, 30),
    parts: [
      const Part(
        id: 'part-1',
        partKindId: 'kind-1',
        partKindName: 'Toile extérieure',
        displayOrder: 1,
        state: PartState.good,
        comments: null,
      ),
    ],
    tags: tags,
  );
}

Tag _tag(String id, String name) {
  return Tag(
    id: id,
    name: name,
    color: '#2196F3',
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: 1,
  );
}

class _StaticTentRepository extends TentRepository {
  final Tent tent;

  _StaticTentRepository(this.tent);

  @override
  Future<Tent> getTent(String id) async => tent;
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

class _EditableTentRepository extends TentRepository {
  int updateCallCount = 0;
  int archiveCallCount = 0;
  int partUpdateCallCount = 0;
  PartState _currentPartState = PartState.good;
  String _currentName = 'Tente Atlas';
  int _currentSize = 6;
  TentOverallState _currentState = TentOverallState.good;
  String? _currentComments = 'Une tente de test.';

  @override
  Future<Tent> getTent(String id) async => Tent(
    id: id,
    name: _currentName,
    size: _currentSize,
    tentModelId: 'shape-1',
    tentModelName: 'Canadienne',
    overallState: _currentState,
    comments: _currentComments,
    createdAt: DateTime.utc(2026, 4, 10, 9),
    updatedAt: DateTime.utc(2026, 4, 12, 18, 30),
    parts: [
      Part(
        id: 'part-1',
        partKindId: 'kind-1',
        partKindName: 'Toile extérieure',
        displayOrder: 1,
        state: _currentPartState,
        comments: null,
      ),
    ],
  );

  @override
  Future<Tent> updateTent({
    required String id,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    String? tentModelId,
  }) async {
    updateCallCount++;
    _currentName = name;
    _currentSize = size;
    _currentState = overallState;
    _currentComments = comments;
    final modelName = tentModelId == 'shape-2' ? 'Tipi' : 'Canadienne';
    return Tent(
      id: id,
      name: name,
      size: size,
      tentModelId: tentModelId ?? 'shape-1',
      tentModelName: modelName,
      overallState: overallState,
      comments: comments,
      createdAt: DateTime.utc(2026, 4, 10, 9),
      updatedAt: DateTime.utc(2026, 4, 13, 10),
      parts: [
        Part(
          id: 'part-1',
          partKindId: 'kind-1',
          partKindName: 'Toile extérieure',
          displayOrder: 1,
          state: _currentPartState,
          comments: null,
        ),
      ],
    );
  }

  @override
  Future<Part> updatePartState({
    required String id,
    required PartState state,
    required String? comments,
  }) async {
    partUpdateCallCount++;
    _currentPartState = state;
    return Part(
      id: id,
      partKindId: 'kind-1',
      partKindName: 'Toile extérieure',
      displayOrder: 1,
      state: state,
      comments: comments,
      createdAt: DateTime.utc(2026, 4, 10, 9),
      updatedAt: DateTime.utc(2026, 4, 13, 10),
    );
  }

  @override
  Future<Tent> archiveTent(String id) async {
    archiveCallCount++;
    return Tent(
      id: id,
      name: _currentName,
      size: _currentSize,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: _currentState,
      isArchived: true,
      comments: _currentComments,
      createdAt: DateTime.utc(2026, 4, 10, 9),
      updatedAt: DateTime.utc(2026, 4, 13, 10),
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
}

class _ArchiveFailingTentRepository extends _EditableTentRepository {
  @override
  Future<Tent> archiveTent(String id) async {
    throw const TentRepositoryException(
      message: 'Impossible d\'archiver la tente. Réessayez.',
    );
  }
}

class _FailingRemovePartRepository extends _EditableTentRepository {
  @override
  Future<void> removePart({required String partId}) async {
    throw const TentRepositoryException(message: 'Suppression impossible.');
  }
}

class _PartKindTentRepository extends _EditableTentRepository {
  @override
  Future<List<PartKind>> getPartKinds() async => const [
    PartKind(id: 'kind-1', name: 'Toile extérieure', displayOrder: 1),
    PartKind(id: 'kind-2', name: 'Double toit', displayOrder: 2),
  ];

  @override
  Future<List<Part>> addPartsToTent({
    required String tentId,
    required List<String> partKindIds,
  }) async => const [];
}

class _PartRemovalAfterEditRepository extends _PartKindTentRepository {
  bool _hasPart = true;

  @override
  Future<Tent> getTent(String id) async {
    final tent = await super.getTent(id);
    if (_hasPart) return tent;
    return Tent(
      id: tent.id,
      name: tent.name,
      size: tent.size,
      tentModelId: tent.tentModelId,
      tentModelName: tent.tentModelName,
      overallState: tent.overallState,
      isArchived: tent.isArchived,
      comments: tent.comments,
      createdAt: tent.createdAt,
      updatedAt: tent.updatedAt,
      parts: const [],
    );
  }

  @override
  Future<void> removePart({required String partId}) async {
    _hasPart = false;
  }
}

class _ArchivedTentRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async => Tent(
    id: id,
    name: 'Tente Atlas',
    size: 6,
    tentModelId: 'shape-1',
    tentModelName: 'Canadienne',
    overallState: TentOverallState.good,
    isArchived: true,
    comments: 'Une tente de test.',
    createdAt: DateTime.utc(2026, 4, 10, 9),
    updatedAt: DateTime.utc(2026, 4, 13, 10),
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

class _FailingUpdateTentRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async => _buildTent();

  @override
  Future<Tent> updateTent({
    required String id,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    String? tentModelId,
  }) async {
    throw const TentRepositoryException(
      message: 'Impossible de mettre à jour la tente.',
    );
  }
}

class _FlakyUpdateTentRepository extends _EditableTentRepository {
  @override
  Future<Tent> updateTent({
    required String id,
    required String name,
    required int size,
    required TentOverallState overallState,
    String? comments,
    String? tentModelId,
  }) async {
    updateCallCount++;
    if (updateCallCount == 1) {
      throw const TentRepositoryException(
        message: 'Impossible de mettre à jour la tente.',
      );
    }

    _currentName = name;
    _currentSize = size;
    _currentState = overallState;
    _currentComments = comments;
    return Tent(
      id: id,
      name: name,
      size: size,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: overallState,
      comments: comments,
      createdAt: DateTime.utc(2026, 4, 10, 9),
      updatedAt: DateTime.utc(2026, 4, 13, 10),
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
}

class _HistorySuccessRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async => _buildTent();

  @override
  Future<List<TentHistoryItem>> getTentHistory({
    required String tentId,
    String? category,
    int limit = 50,
  }) async {
    final items = [
      TentHistoryItem(
        id: 'h-1',
        action: 'tent_created',
        category: 'tent_info',
        occurredAt: DateTime.utc(2026, 5, 19, 10, 0),
        actorDisplayName: 'Jean',
        details: [],
      ),
      TentHistoryItem(
        id: 'h-2',
        action: 'tent_updated',
        category: 'tent_info',
        occurredAt: DateTime.utc(2026, 5, 19, 11, 0),
        actorDisplayName: 'Jean',
        details: [
          const TentHistoryDetail(
            label: 'Nom',
            oldValue: 'Ancien nom',
            newValue: 'Nouveau nom',
            valueType: 'old_new',
          ),
        ],
      ),
      TentHistoryItem(
        id: 'h-3',
        action: 'tag_assigned',
        category: 'tags',
        occurredAt: DateTime.utc(2026, 5, 19, 12, 0),
        actorDisplayName: 'Jean',
        subjectName: 'Patrouille',
        details: const [
          TentHistoryDetail(
            label: 'Étiquette',
            value: 'Patrouille',
            valueType: 'tag',
          ),
        ],
      ),
    ];

    if (category != null) {
      return items.where((i) => i.category == category).toList();
    }

    return items;
  }
}

class _HistoryArchivedRepository extends TentRepository {
  @override
  Future<Tent> getTent(String id) async => Tent(
    id: id,
    name: 'Tente Archivée',
    size: 4,
    tentModelId: 'shape-1',
    tentModelName: 'Canadienne',
    overallState: TentOverallState.good,
    isArchived: true,
    comments: null,
    createdAt: DateTime.utc(2026, 4, 10, 9),
    updatedAt: DateTime.utc(2026, 4, 13, 10),
    parts: const [],
  );

  @override
  Future<List<TentHistoryItem>> getTentHistory({
    required String tentId,
    String? category,
    int limit = 50,
  }) async {
    return [
      TentHistoryItem(
        id: 'h-1',
        action: 'tent_created',
        category: 'tent_info',
        occurredAt: DateTime.utc(2026, 4, 10, 9, 0),
        actorDisplayName: 'Jean',
        details: [],
      ),
      TentHistoryItem(
        id: 'h-2',
        action: 'tent_archived',
        category: 'archive',
        occurredAt: DateTime.utc(2026, 4, 13, 10, 0),
        actorDisplayName: 'Jean',
        details: [],
      ),
    ];
  }
}

class _FixedModelsNotifier extends TentModelsNotifier {
  @override
  Future<List<TentModel>> build() async => const [
    TentModel(
      id: 'shape-1',
      name: 'Canadienne',
      displayOrder: 1,
      isActive: true,
    ),
    TentModel(id: 'shape-2', name: 'Tipi', displayOrder: 2, isActive: true),
  ];
}
