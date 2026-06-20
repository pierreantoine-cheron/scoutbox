import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/models/tent.dart';
import 'package:client/providers/tent_filter_provider.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/widgets/tent_list_filter_bar.dart';

void main() {
  group('TentListFilterBar', () {
    late TextEditingController searchController;
    late Set<TentOverallState> selectedStates;
    late Set<int> selectedSizes;
    late Set<String> selectedModelIds;
    late Set<String> selectedTagIds;

    setUp(() {
      searchController = TextEditingController();
      selectedStates = {};
      selectedSizes = {};
      selectedModelIds = {};
      selectedTagIds = {};
    });

    tearDown(() {
      searchController.dispose();
    });

    Widget buildBar({bool isDesktop = true}) {
      return MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
        home: Scaffold(
          body: TentListFilterBar(
            isDesktop: isDesktop,
            searchController: searchController,
            selectedStates: selectedStates,
            selectedSizes: selectedSizes,
            selectedModelIds: selectedModelIds,
            selectedTagIds: selectedTagIds,
            availableSizes: const [4, 6, 8],
            availableModelOptions: const [
              TentTypeFilterOption(id: 'shape-1', label: 'Canadienne'),
              TentTypeFilterOption(id: 'shape-2', label: 'Cabanon'),
            ],
            allTags: [_tagA, _tagB],
            isFilteredMode: false,
            archiveFilter: ArchiveFilter.active,
            visibleTentCount: 3,
            onSearchChanged: (_) {},
            onToggleState: (_) {},
            onToggleSize: (_) {},
            onToggleModel: (_) {},
            onToggleTag: (_) {},
            onArchiveFilterChanged: (_) {},
            onClearAll: () {},
            onManageTags: () {},
          ),
        ),
      );
    }

    Future<void> expandFilterPanel(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
    }

    testWidgets('renders state filter chips on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));
      await expandFilterPanel(tester);

      expect(find.text('Bon état'), findsOneWidget);
      expect(find.text('À réparer'), findsOneWidget);
      expect(find.text('Inutilisable'), findsOneWidget);
    });

    testWidgets('renders size filter chips on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));
      await expandFilterPanel(tester);

      expect(find.text('4 places'), findsOneWidget);
      expect(find.text('6 places'), findsOneWidget);
      expect(find.text('8 places'), findsOneWidget);
    });

    testWidgets('renders shape filter chips on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));
      await expandFilterPanel(tester);

      expect(find.text('Canadienne'), findsOneWidget);
      expect(find.text('Cabanon'), findsOneWidget);
    });

    testWidgets('calls archive filter callback from segmented toggle', (
      tester,
    ) async {
      ArchiveFilter? selectedArchiveFilter;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: selectedStates,
              selectedSizes: selectedSizes,
              selectedModelIds: selectedModelIds,
              selectedTagIds: selectedTagIds,
              availableSizes: const [],
              availableModelOptions: const [],
              allTags: const [],
              isFilteredMode: false,
              archiveFilter: ArchiveFilter.active,
              visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onArchiveFilterChanged: (filter) {
                selectedArchiveFilter = filter;
              },
              onClearAll: () {},
            ),
          ),
        ),
      );

      await expandFilterPanel(tester);
      await tester.tap(find.text('Archivées'));

      expect(selectedArchiveFilter, ArchiveFilter.archived);
    });

    testWidgets('calls onToggleState when state chip is tapped', (
      tester,
    ) async {
      TentOverallState? toggledState;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: selectedStates,
              selectedSizes: selectedSizes,
              selectedModelIds: selectedModelIds,
              selectedTagIds: selectedTagIds,
              availableSizes: const [],
              availableModelOptions: const [],
              allTags: const [],
              isFilteredMode: false,
              archiveFilter: ArchiveFilter.active,
              visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (s) => toggledState = s,
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onArchiveFilterChanged: (_) {},
              onClearAll: () {},
            ),
          ),
        ),
      );

      await expandFilterPanel(tester);
      await tester.tap(find.text('Bon état'));
      expect(toggledState, TentOverallState.good);
    });

    testWidgets('calls onClearAll when Effacer les filtres is tapped', (tester) async {
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: const {TentOverallState.good},
              selectedSizes: selectedSizes,
              selectedModelIds: selectedModelIds,
              selectedTagIds: selectedTagIds,
              availableSizes: const [],
              availableModelOptions: const [],
              allTags: const [],
              isFilteredMode: true,
              archiveFilter: ArchiveFilter.active,
              visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onArchiveFilterChanged: (_) {},
              onClearAll: () => cleared = true,
            ),
          ),
        ),
      );

      await expandFilterPanel(tester);
      await tester.tap(find.text('Effacer les filtres'));
      expect(cleared, isTrue);
    });

    testWidgets('does not show Effacer les filtres when not in filtered mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar(isDesktop: true));

      expect(find.text('Effacer les filtres'), findsNothing);
    });

    testWidgets('shows Filtres button on mobile with secondary filters', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar(isDesktop: false));

      expect(find.text('Aucun filtre actif'), findsOneWidget);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('renders tag chips with counts on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));
      await expandFilterPanel(tester);

      expect(find.text('ÉTIQUETTES'), findsOneWidget);
      expect(find.text('Groupe A'), findsOneWidget);
      expect(find.text('À réparer'), findsAtLeast(1));
    });

    testWidgets('calls onToggleTag when desktop tag chip is tapped', (
      tester,
    ) async {
      String? toggledTagId;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: selectedStates,
              selectedSizes: selectedSizes,
              selectedModelIds: selectedModelIds,
              selectedTagIds: selectedTagIds,
              availableSizes: const [],
              availableModelOptions: const [],
              allTags: [_tagA],
              isFilteredMode: false,
              archiveFilter: ArchiveFilter.active,
              visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (tagId) => toggledTagId = tagId,
              onArchiveFilterChanged: (_) {},
              onClearAll: () {},
              onManageTags: () {},
            ),
          ),
        ),
      );

      await expandFilterPanel(tester);
      await tester.tap(find.text('Groupe A'));

      expect(toggledTagId, 'tag-a');
    });

    testWidgets('omits tag row when no tags exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: selectedStates,
              selectedSizes: selectedSizes,
              selectedModelIds: selectedModelIds,
              selectedTagIds: selectedTagIds,
              availableSizes: const [],
              availableModelOptions: const [],
              allTags: const [],
              isFilteredMode: false,
              archiveFilter: ArchiveFilter.active,
              visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onArchiveFilterChanged: (_) {},
              onClearAll: () {},
              onManageTags: () {},
            ),
          ),
        ),
      );

      await expandFilterPanel(tester);

      expect(find.text('Étiquettes'), findsNothing);
    });
  });
}

final _tagA = Tag(
  id: 'tag-a',
  name: 'Groupe A',
  color: '#4CAF50',
  createdAt: DateTime.utc(2026, 6, 1),
  tentCount: 5,
);

final _tagB = Tag(
  id: 'tag-b',
  name: 'Patrouille B',
  color: '#FFC107',
  createdAt: DateTime.utc(2026, 6, 1),
  tentCount: 2,
);
