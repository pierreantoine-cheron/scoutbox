import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/views/widgets/scout_segmented_toggle.dart';

void main() {
  group('ScoutSegmentedToggle', () {
    testWidgets('renders all labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: ScoutSegmentedToggle<int>(
              options: const [
                SegmentedToggleOption(value: 0, label: 'Actives'),
                SegmentedToggleOption(value: 1, label: 'Toutes'),
                SegmentedToggleOption(value: 2, label: 'Archiv\u00E9es'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Actives'), findsOneWidget);
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('Archiv\u00E9es'), findsOneWidget);
    });

    testWidgets('calls onChanged with correct value on tap', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: ScoutSegmentedToggle<int>(
              options: const [
                SegmentedToggleOption(value: 0, label: 'A'),
                SegmentedToggleOption(value: 1, label: 'B'),
                SegmentedToggleOption(value: 2, label: 'C'),
              ],
              selected: 0,
              onChanged: (v) => selectedIndex = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('B'));
      expect(selectedIndex, equals(1));
    });

    testWidgets('selected item has surface decoration when no color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: ScoutSegmentedToggle<int>(
              options: const [
                SegmentedToggleOption(value: 0, label: 'A'),
                SegmentedToggleOption(value: 1, label: 'B'),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      final selectedContainers = containers.where((c) {
        final decoration = c.decoration;
        return decoration is BoxDecoration &&
            decoration.color != null &&
            decoration.color != Colors.transparent &&
            decoration.boxShadow != null;
      }).toList();

      expect(selectedContainers, hasLength(1));
    });

    testWidgets('applies colored background when color is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: ScoutSegmentedToggle<int>(
              options: const [
                SegmentedToggleOption(value: 0, label: 'A', color: Colors.green, backgroundColor: Color(0xFFDBF3DB)),
                SegmentedToggleOption(value: 1, label: 'B', color: Colors.amber, backgroundColor: Color(0xFFFFEBC1)),
              ],
              selected: 0,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      final greenText = tester.widget<Text>(find.text('A'));
      expect(greenText.style?.color, equals(Colors.green));

      final amberText = tester.widget<Text>(find.text('B'));
      expect(amberText.style?.color, equals(Colors.amber));
    });
  });
}
