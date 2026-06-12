import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/models/tent.dart';
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
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
            visibleTentCount: 3,
            onSearchChanged: (_) {},
            onToggleState: (_) {},
            onToggleSize: (_) {},
            onToggleModel: (_) {},
            onToggleTag: (_) {},
            onClearAll: () {},
            onManageTags: () {},
          ),
        ),
      );
    }


    testWidgets('renders state filter chips on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));

      expect(find.text('Bon état'), findsOneWidget);
      expect(find.text('À réparer'), findsOneWidget);
      expect(find.text('Inutilisable'), findsOneWidget);
    });

    testWidgets('renders size filter chips on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));

      expect(find.text('4 places'), findsOneWidget);
      expect(find.text('6 places'), findsOneWidget);
      expect(find.text('8 places'), findsOneWidget);
    });

    testWidgets('renders shape filter chips on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));

      expect(find.text('Canadienne'), findsOneWidget);
      expect(find.text('Cabanon'), findsOneWidget);
    });

    testWidgets('calls onToggleState when state chip is tapped', (
      tester,
    ) async {
      TentOverallState? toggledState;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
            visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (s) => toggledState = s,
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onClearAll: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Bon état'));
      expect(toggledState, TentOverallState.good);
    });

    testWidgets('calls onClearAll when Effacer tout is tapped', (tester) async {
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
            visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onClearAll: () => cleared = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Effacer tout'));
      expect(cleared, isTrue);
    });

    testWidgets('does not show Effacer tout when not in filtered mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar(isDesktop: true));

      expect(find.text('Effacer tout'), findsNothing);
    });

    testWidgets('shows Filtres button on mobile with secondary filters', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar(isDesktop: false));

      expect(find.text('Filtres'), findsOneWidget);
    });



    testWidgets('renders tag chips with counts on desktop', (tester) async {
      await tester.pumpWidget(buildBar(isDesktop: true));

      expect(find.text('Étiquettes'), findsOneWidget);
      expect(find.text('Groupe A (5)'), findsOneWidget);
      expect(find.text('À réparer (2)'), findsOneWidget);
    });

    testWidgets('calls onToggleTag when desktop tag chip is tapped', (
      tester,
    ) async {
      String? toggledTagId;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
            visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (tagId) => toggledTagId = tagId,
              onClearAll: () {},
              onManageTags: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Groupe A (5)'));

      expect(toggledTagId, 'tag-a');
    });

    testWidgets('shows no tag message and manage action when no tags exist', (
      tester,
    ) async {
      var manageTags = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
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
            visibleTentCount: 3,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleModel: (_) {},
              onToggleTag: (_) {},
              onClearAll: () {},
              onManageTags: () => manageTags = true,
            ),
          ),
        ),
      );

      expect(find.text('Aucune étiquette disponible'), findsOneWidget);
      await tester.tap(find.text('Créer des étiquettes'));

      expect(manageTags, isTrue);
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
  name: 'À réparer',
  color: '#FFC107',
  createdAt: DateTime.utc(2026, 6, 1),
  tentCount: 2,
);
