import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tent.dart';
import 'package:client/views/widgets/tent_list_filter_bar.dart';

void main() {
  group('TentListFilterBar', () {
    late TextEditingController searchController;
    late Set<TentOverallState> selectedStates;
    late Set<int> selectedSizes;
    late Set<String> selectedShapeIds;

    setUp(() {
      searchController = TextEditingController();
      selectedStates = {};
      selectedSizes = {};
      selectedShapeIds = {};
    });

    tearDown(() {
      searchController.dispose();
    });

    Widget buildBar({bool isDesktop = true}) {
      return MaterialApp(
        home: Scaffold(
          body: TentListFilterBar(
            isDesktop: isDesktop,
            searchController: searchController,
            selectedStates: selectedStates,
            selectedSizes: selectedSizes,
            selectedShapeIds: selectedShapeIds,
            availableSizes: const [4, 6, 8],
            availableShapeOptions: const [
              TentTypeFilterOption(id: 'shape-1', label: 'Canadienne'),
              TentTypeFilterOption(id: 'shape-2', label: 'Cabanon'),
            ],
            isFilteredMode: false,
            onSearchChanged: (_) {},
            onToggleState: (_) {},
            onToggleSize: (_) {},
            onToggleShape: (_) {},
            onClearAll: () {},
          ),
        ),
      );
    }

    testWidgets('renders search field', (tester) async {
      await tester.pumpWidget(buildBar());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Rechercher une tente'), findsOneWidget);
    });

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
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: selectedStates,
              selectedSizes: selectedSizes,
              selectedShapeIds: selectedShapeIds,
              availableSizes: const [],
              availableShapeOptions: const [],
              isFilteredMode: false,
              onSearchChanged: (_) {},
              onToggleState: (s) => toggledState = s,
              onToggleSize: (_) {},
              onToggleShape: (_) {},
              onClearAll: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Bon état'));
      expect(toggledState, TentOverallState.good);
    });

    testWidgets('calls onClearAll when Effacer tout is tapped', (
      tester,
    ) async {
      var cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: const {TentOverallState.good},
              selectedSizes: selectedSizes,
              selectedShapeIds: selectedShapeIds,
              availableSizes: const [],
              availableShapeOptions: const [],
              isFilteredMode: true,
              onSearchChanged: (_) {},
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleShape: (_) {},
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

    testWidgets('shows search clear button when text entered', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar());

      searchController.text = 'test';
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('clears search on clear button tap', (tester) async {
      String? searchValue;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentListFilterBar(
              isDesktop: true,
              searchController: searchController,
              selectedStates: selectedStates,
              selectedSizes: selectedSizes,
              selectedShapeIds: selectedShapeIds,
              availableSizes: const [],
              availableShapeOptions: const [],
              isFilteredMode: false,
              onSearchChanged: (v) => searchValue = v,
              onToggleState: (_) {},
              onToggleSize: (_) {},
              onToggleShape: (_) {},
              onClearAll: () {},
            ),
          ),
        ),
      );

      searchController.text = 'search term';
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      expect(searchValue, '');
      expect(searchController.text, '');
    });
  });
}
