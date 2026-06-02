import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';
import 'package:client/models/tent.dart';
import 'package:client/views/widgets/tent_card.dart';
import 'package:client/views/widgets/tent_tag_chips.dart';

Tent _sampleTent({
  String name = 'Tente Test',
  int size = 6,
  String? modelName = 'Canadienne',
  TentOverallState state = TentOverallState.good,
  List<Tag> tags = const [],
}) {
  return Tent(
    id: 'tent-1',
    name: name,
    size: size,
    tentModelId: 'shape-1',
    tentModelName: modelName,
    overallState: state,
    isArchived: false,
    comments: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    parts: const [],
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

void main() {
  group('TentCard', () {
    testWidgets('renders tent name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(
              tent: _sampleTent(name: 'Tente Familiale'),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Tente Familiale'), findsOneWidget);
    });

    testWidgets('renders size with singular label for 1', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(tent: _sampleTent(size: 1), onTap: () {}),
          ),
        ),
      );

      expect(find.text('1 place'), findsOneWidget);
    });

    testWidgets('renders size with plural label for more than 1', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(tent: _sampleTent(size: 4), onTap: () {}),
          ),
        ),
      );

      expect(find.text('4 places'), findsOneWidget);
    });

    testWidgets('renders shape name when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(tent: _sampleTent(), onTap: () {}),
          ),
        ),
      );

      expect(find.text('Canadienne'), findsOneWidget);
    });

    testWidgets('renders state badge for tent state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(
              tent: _sampleTent(state: TentOverallState.needsRepair),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('À réparer'), findsOneWidget);
    });

    testWidgets('renders "Voir le detail" text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(tent: _sampleTent(), onTap: () {}),
          ),
        ),
      );

      expect(find.text('Voir le detail'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: TentCard(tent: _sampleTent(), onTap: () => tapped = true),
          ),
        ),
      );

      await tester.tap(find.text('Tente Test'));
      expect(tapped, isTrue);
    });

    testWidgets('renders assigned tags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: TentCard(
              tent: _sampleTent(tags: [_tag('tag-1', 'Patrouille')]),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byType(TentTagChips), findsOneWidget);
      expect(find.text('Patrouille'), findsOneWidget);
    });

    testWidgets('hides tag area when no tags are assigned', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(tent: _sampleTent(), onTap: () {}),
          ),
        ),
      );

      expect(find.byType(TentTagChips), findsNothing);
    });

    testWidgets('shows overflow for many tags', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: TentCard(
              tent: _sampleTent(
                tags: [
                  _tag('tag-1', 'A'),
                  _tag('tag-2', 'B'),
                  _tag('tag-3', 'C'),
                  _tag('tag-4', 'D'),
                ],
              ),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped with tags', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: Scaffold(
            body: TentCard(
              tent: _sampleTent(tags: [_tag('tag-1', 'Patrouille')]),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Patrouille'));
      expect(tapped, isTrue);
    });

    testWidgets('has semantics label with tent name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(tent: _sampleTent(), onTap: () {}),
          ),
        ),
      );

      // Semantics node should contain tent name
      final node = tester.getSemantics(find.byType(Card));
      expect(node.label, contains('Tente Test'));
    });

    testWidgets('does not render shape name when empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TentCard(
              tent: _sampleTent(modelName: ''),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Canadienne'), findsNothing);
    });
  });
}
