import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/providers/auth_provider.dart';
import 'package:client/models/auth_state.dart';
import 'package:client/models/tent.dart';
import 'package:client/models/tent_model.dart';
import 'package:client/providers/app_bar_config_provider.dart';
import 'package:client/providers/tent_list_provider.dart';
import 'package:client/providers/tent_models_provider.dart';
import 'package:client/repositories/tent_repository.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/screens/tent_list_screen.dart';
import 'package:client/views/widgets/async_error_view.dart';

void main() {
  group('TentListScreen', () {
    testWidgets('no logout button in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier([
                const Tent(
                  id: '1',
                  name: 'Tente A',
                  size: 6,
                  tentModelId: 'shape-1',
                  tentModelName: 'Canadienne',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
              ]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.logout), findsNothing);
    });

    testWidgets('opens tent creation screen from empty-state action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _TentListAndModelsTestRepository(),
            ),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const []),
            ),
            tentModelsProvider.overrideWith(() => _TentModelsTestNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucune tente disponible'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun modèle de tente disponible pour le moment.'),
        findsOneWidget,
      );
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
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nom'), findsOneWidget);
      expect(find.text('État'), findsWidgets);
      expect(find.text('Taille'), findsWidgets);
      expect(find.text('Modèle'), findsOneWidget);
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
              () => _TentListTestNotifier([
                const Tent(
                  id: 't1',
                  name: 'Zulu',
                  size: 2,
                  tentModelId: 'shape-1',
                  tentModelName: 'null',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
                const Tent(
                  id: 't2',
                  name: 'Alpha',
                  size: 4,
                  tentModelId: 'shape-2',
                  tentModelName: 'Canadienne',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
              ]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
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

    testWidgets('keeps blank shape values last in both sort directions', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier([
                const Tent(
                  id: 't1',
                  name: 'Alpha',
                  size: 2,
                  tentModelId: 'shape-1',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
                const Tent(
                  id: 't2',
                  name: 'Bravo',
                  size: 4,
                  tentModelId: 'shape-2',
                  tentModelName: 'null',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
              ]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modèle'));
      await tester.pumpAndSettle();

      var textOrder = _extractTextData(tester);
      expect(textOrder.indexOf('Bravo') < textOrder.indexOf('Alpha'), isTrue);

      await tester.tap(find.text('Modèle'));
      await tester.pumpAndSettle();

      textOrder = _extractTextData(tester);
      expect(textOrder.indexOf('Bravo') < textOrder.indexOf('Alpha'), isTrue);
    });

    testWidgets('keeps blank model values last in both sort directions', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier([
                const Tent(
                  id: 't1',
                  name: 'Alpha',
                  size: 2,
                  tentModelId: 'shape-1',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
                Tent(
                  id: 't2',
                  name: 'Bravo',
                  size: 4,
                  tentModelId: 'shape-2',
                  tentModelName: 'Canadienne',
                  overallState: TentOverallState.good,
                  comments: null,
                  updatedAt: DateTime.utc(2026, 4, 12, 10, 30),
                ),
              ]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Modèle'));
      await tester.pumpAndSettle();

      var textOrder = _extractTextData(tester);
      expect(textOrder.indexOf('Bravo') < textOrder.indexOf('Alpha'), isTrue);

      await tester.tap(find.text('Modèle'));
      await tester.pumpAndSettle();

      textOrder = _extractTextData(tester);
      expect(textOrder.indexOf('Bravo') < textOrder.indexOf('Alpha'), isTrue);
    });

    testWidgets('opens detail screen from desktop row tap', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _TentListAndModelsTestRepository(),
            ),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
    });

    testWidgets('refreshes desktop table from app bar action', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));
      final notifier = _RefreshTrackingTentListNotifier(_buildSampleTents());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tentListProvider.overrideWith(() => notifier)],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Actualiser la liste'));
      await tester.pump();

      expect(notifier.refreshCallCount, equals(1));
    });

    testWidgets('renders cards and opens detail screen on tap on mobile', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _TentListAndModelsTestRepository(),
            ),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Canadienne'), findsOneWidget);

      await tester.tap(find.text('Tente Atlas'));
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsOneWidget);
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
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsOneWidget);
      expect(find.text('Nom'), findsNothing);
    });

    testWidgets('renders long desktop refresh warning without overflow', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));
      const warning = TentRepositoryException(
        code: 'NETWORK_ERROR',
        message:
            'Message très long pour vérifier que la carte d\'avertissement reste lisible sur plusieurs lignes sans couper le tableau.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSampleTents()),
            ),
            tentListRefreshIssueProvider.overrideWithValue(warning),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Les données affichées peuvent être anciennes.'),
        findsOneWidget,
      );
      expect(find.text('Nom'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders loading skeleton state', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(() => _LoadingTentListNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('renders inline error state and retries', (
      WidgetTester tester,
    ) async {
      var retryCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: AsyncErrorView(
              message: 'Erreur serveur. Réessayez.',
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
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
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
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune tente trouv\u00e9e'),
        findsOneWidget,
      );
    });

    testWidgets('renders persistent filter controls on desktop and mobile', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildFilteringSampleTents()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);
      expect(find.text('Bon état'), findsWidgets);
      expect(find.text('À réparer'), findsWidgets);
      expect(find.text('Inutilisable'), findsWidgets);

      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpAndSettle();

      expect(find.text('Bon état'), findsWidgets);
      expect(find.text('À réparer'), findsWidgets);
      expect(find.text('Inutilisable'), findsWidgets);
    });

    testWidgets('filters list by state chip and clears all filters', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildFilteringSampleTents()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucune tente trouv\u00e9e'),
        findsOneWidget,
      );
      await _expandFilterPanel(tester);
      expect(find.text('Effacer les filtres'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsOneWidget);
    });

    testWidgets('applies debounced search and supports clear search action', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildFilteringSampleTents()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'at');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Tente Boreale'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsOneWidget);
    });

    testWidgets('shows filtered empty state and clear-all restores list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildFilteringSampleTents()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);
      await tester.tap(find.text('Bon état').first);
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsNothing);
      expect(find.text('Effacer les filtres'), findsOneWidget);

      await tester.tap(find.text('Effacer les filtres'));
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsOneWidget);
    });

    testWidgets('desktop renders inline size and type filters', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);

      expect(find.text('État'), findsWidgets);
      expect(find.text('Taille'), findsWidgets);
      expect(find.text('Modèle'), findsOneWidget);
      expect(find.text('2 places'), findsOneWidget);
      expect(find.text('4 places'), findsOneWidget);
      expect(find.text('6 places'), findsOneWidget);
      expect(find.text('Canadienne'), findsWidgets);
      expect(find.text('null'), findsWidgets);
    });

    testWidgets('desktop size and type filters follow archive filter', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(1200, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildArchiveFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildArchiveModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(find.text('4 places'), findsOneWidget);
      expect(find.text('8 places'), findsNothing);
      expect(find.text('Canadienne'), findsWidgets);
      expect(find.text('Dome'), findsNothing);

      await tester.tap(find.text('Archivées'));
      await tester.pumpAndSettle();

      expect(find.text('4 places'), findsNothing);
      expect(find.text('8 places'), findsOneWidget);
      expect(find.text('Canadienne'), findsNothing);
      expect(find.text('Dome'), findsWidgets);
    });

    testWidgets('mobile renders compact expandable filters', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aucun filtre actif'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('4 places'), findsNothing);
    });

    testWidgets(
      'mobile filter sheet opens and closing keeps applied size filter',
      (WidgetTester tester) async {
        await _setViewportSize(tester, const Size(600, 900));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tentListProvider.overrideWith(
                () => _TentListTestNotifier(
                  _buildSecondaryFilteringSampleTents(),
                ),
              ),
              tentModelsProvider.overrideWith(
                () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
              ),
            ],
            child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await _expandFilterPanel(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text('4 places'));
        await tester.pumpAndSettle();

        expect(find.text('Tente Boreale'), findsOneWidget);
        expect(find.text('Tente Atlas'), findsNothing);
        expect(find.text('Tente Cerise'), findsNothing);

        await _expandFilterPanel(tester);
        await tester.pumpAndSettle();

        expect(find.text('Tente Boreale'), findsOneWidget);
        expect(find.text('4 places'), findsOneWidget);
      },
    );

    testWidgets(
      'dismissing mobile sheet outside keeps already-applied changes',
      (WidgetTester tester) async {
        await _setViewportSize(tester, const Size(600, 900));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tentListProvider.overrideWith(
                () => _TentListTestNotifier(
                  _buildSecondaryFilteringSampleTents(),
                ),
              ),
              tentModelsProvider.overrideWith(
                () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
              ),
            ],
            child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await _expandFilterPanel(tester);
        await tester.pumpAndSettle();

        await tester.tap(find.text('null').first);
        await tester.pumpAndSettle();

        await _expandFilterPanel(tester);
        await tester.pumpAndSettle();

        expect(find.text('Tente Boreale'), findsOneWidget);
        expect(find.text('Tente Atlas'), findsNothing);
        expect(find.text('null'), findsWidgets);
      },
    );

    testWidgets('mobile shape filter updates results immediately', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Canadienne').first);
      await tester.pumpAndSettle();

      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsNothing);
      expect(find.text('Tente Cerise'), findsNothing);
    });

    testWidgets('mobile filter sheet updates chip selection while open', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('4 places'));
      await tester.pumpAndSettle();
      expect(find.text('Tente Boreale'), findsOneWidget);

      await tester.tap(find.text('4 places').last);
      await tester.pumpAndSettle();
      expect(find.text('Tente Atlas'), findsOneWidget);
    });

    testWidgets('mobile filter sheet scrolls on short viewports', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 700));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildManyFilterOptionsTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildManyModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('effacer tout resets secondary filters and search', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(_buildModelOptionsMetadata()),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'te');
      await tester.pump(const Duration(milliseconds: 400));
      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('null').first);
      await tester.pumpAndSettle();

      expect(find.text('Effacer les filtres'), findsOneWidget);
      await tester.tap(find.text('Effacer les filtres'));
      await tester.pumpAndSettle();

      expect(find.text('Aucun filtre actif'), findsOneWidget);
      expect(find.text('Tente Atlas'), findsOneWidget);
      expect(find.text('Tente Boreale'), findsOneWidget);
      expect(find.text('Tente Cerise'), findsOneWidget);
    });

    testWidgets('type filters still available when shape metadata fails', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(() => _TentModelsFailingNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsWidgets);
      expect(find.text('null'), findsWidgets);
    });

    testWidgets('type filters still available while shape metadata loads', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(() => _TentModelsLoadingNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsWidgets);
      expect(find.text('null'), findsWidgets);
      expect(find.text('Dome'), findsWidgets);
    });

    testWidgets('type options include raw shape ids missing from metadata', (
      WidgetTester tester,
    ) async {
      await _setViewportSize(tester, const Size(600, 900));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(_buildSecondaryFilteringSampleTents()),
            ),
            tentModelsProvider.overrideWith(
              () => _TentModelsLoadedNotifier(const [
                TentModel(
                  id: 'shape-1',
                  name: 'Canadienne',
                  displayOrder: 1,
                  isActive: true,
                ),
              ]),
            ),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const TentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _expandFilterPanel(tester);
      await tester.pumpAndSettle();

      expect(find.text('Canadienne'), findsWidgets);
      expect(find.text('null'), findsWidgets);
      expect(find.text('Dome'), findsWidgets);
    });

    testWidgets('opens tent creation screen from fab', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tentRepositoryProvider.overrideWithValue(
              _TentListAndModelsTestRepository(),
            ),
            tentListProvider.overrideWith(
              () => _TentListTestNotifier(const [
                Tent(
                  id: '1',
                  name: 'Tente A',
                  size: 6,
                  tentModelId: 'shape-1',
                  tentModelName: 'Canadienne',
                  overallState: TentOverallState.good,
                  comments: null,
                ),
              ]),
            ),
            tentModelsProvider.overrideWith(() => _TentModelsTestNotifier()),
          ],
          child: MaterialApp(theme: AppTheme.minimal().copyWith(splashFactory: NoSplash.splashFactory), home: const _TentListTestShell()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Aucun modèle de tente disponible pour le moment.'),
        findsOneWidget,
      );
    });
  });
}

class _TentListTestShell extends ConsumerWidget {
  const _TentListTestShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appBarConfig = ref.watch(appBarConfigProvider);
    return Scaffold(
      appBar: AppBar(
        title: appBarConfig.title,
        actions: appBarConfig.actions,
      ),
      floatingActionButton: appBarConfig.fab,
      body: const TentListScreen(),
    );
  }
}

Future<void> _setViewportSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _expandFilterPanel(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.expand_more).first);
  await tester.pumpAndSettle();
}

List<String> _extractTextData(WidgetTester tester) {
  return find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .toList();
}

List<Tent> _buildSampleTents() {
  return const [
    Tent(
      id: 't1',
      name: 'Tente Atlas',
      size: 6,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.needsRepair,
      comments: null,
    ),
  ];
}

List<Tent> _buildFilteringSampleTents() {
  return const [
    Tent(
      id: 't1',
      name: 'Tente Atlas',
      size: 6,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
    ),
    Tent(
      id: 't2',
      name: 'Tente Boreale',
      size: 4,
      tentModelId: 'shape-2',
      tentModelName: 'null',
      overallState: TentOverallState.needsRepair,
      comments: null,
    ),
  ];
}

List<Tent> _buildSecondaryFilteringSampleTents() {
  return const [
    Tent(
      id: 't1',
      name: 'Tente Atlas',
      size: 6,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
    ),
    Tent(
      id: 't2',
      name: 'Tente Boreale',
      size: 4,
      tentModelId: 'shape-2',
      tentModelName: 'null',
      overallState: TentOverallState.needsRepair,
      comments: null,
    ),
    Tent(
      id: 't3',
      name: 'Tente Cerise',
      size: 2,
      tentModelId: 'shape-3',
      tentModelName: 'Dome',
      overallState: TentOverallState.unusable,
      comments: null,
    ),
  ];
}

List<Tent> _buildArchiveFilteringSampleTents() {
  return const [
    Tent(
      id: 't1',
      name: 'Tente Active',
      size: 4,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
    ),
    Tent(
      id: 't2',
      name: 'Tente Active 2',
      size: 6,
      tentModelId: 'shape-2',
      tentModelName: 'Tipi',
      overallState: TentOverallState.good,
      comments: null,
    ),
    Tent(
      id: 't3',
      name: 'Tente Archivée',
      size: 8,
      tentModelId: 'shape-3',
      tentModelName: 'Dome',
      overallState: TentOverallState.good,
      comments: null,
      isArchived: true,
    ),
  ];
}

List<Tent> _buildManyFilterOptionsTents() {
  return [
    for (var index = 1; index <= 12; index++)
      Tent(
        id: 't$index',
        name: 'Tente $index',
        size: index,
        tentModelId: 'shape-$index',
        tentModelName: 'Type $index',
        overallState: TentOverallState.good,
        comments: null,
      ),
  ];
}

List<TentModel> _buildModelOptionsMetadata() {
  return const [
    TentModel(
      id: 'shape-1',
      name: 'Canadienne',
      displayOrder: 1,
      isActive: true,
    ),
    TentModel(id: 'shape-2', name: 'null', displayOrder: 2, isActive: true),
  ];
}

List<TentModel> _buildArchiveModelOptionsMetadata() {
  return const [
    TentModel(
      id: 'shape-1',
      name: 'Canadienne',
      displayOrder: 1,
      isActive: true,
    ),
    TentModel(id: 'shape-2', name: 'Tipi', displayOrder: 2, isActive: true),
    TentModel(id: 'shape-3', name: 'Dome', displayOrder: 3, isActive: true),
  ];
}

List<TentModel> _buildManyModelOptionsMetadata() {
  return [
    for (var index = 1; index <= 12; index++)
      TentModel(
        id: 'shape-$index',
        name: 'Type $index',
        displayOrder: index,
        isActive: true,
      ),
  ];
}

class _TentListAndModelsTestRepository extends TentRepository {
  @override
  Future<List<Tent>> getTents() async {
    return const [];
  }

  @override
  Future<Tent> getTent(String id) async {
    return Tent(
      id: id,
      name: 'Tente Atlas',
      size: 6,
      tentModelId: 'shape-1',
      tentModelName: 'Canadienne',
      overallState: TentOverallState.good,
      comments: null,
      createdAt: DateTime.utc(2026, 4, 10, 9),
      updatedAt: DateTime.utc(2026, 4, 12, 18, 30),
    );
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

class _TentModelsTestNotifier extends TentModelsNotifier {
  @override
  Future<List<TentModel>> build() async => const [];
}

class _TentModelsLoadedNotifier extends TentModelsNotifier {
  final List<TentModel> shapes;

  _TentModelsLoadedNotifier(this.shapes);

  @override
  Future<List<TentModel>> build() async => shapes;
}

class _TentModelsFailingNotifier extends TentModelsNotifier {
  @override
  Future<List<TentModel>> build() {
    throw Exception('network');
  }
}

class _TentModelsLoadingNotifier extends TentModelsNotifier {
  @override
  Future<List<TentModel>> build() => Completer<List<TentModel>>().future;
}
