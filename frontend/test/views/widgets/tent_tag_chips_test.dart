import 'package:client/models/tag.dart';
import 'package:client/views/widgets/tent_tag_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TentTagChips', () {
    testWidgets('renders nothing for an empty tag list', (tester) async {
      await tester.pumpWidget(_testApp(const TentTagChips(tags: [])));

      expect(find.byType(TentTagChips), findsOneWidget);
      expect(find.byType(Tooltip), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders one to three tags in received order', (tester) async {
      await tester.pumpWidget(
        _testApp(
          TentTagChips(
            tags: [_tag('tag-1', 'Louveteaux'), _tag('tag-2', 'Patrouille')],
          ),
        ),
      );

      expect(find.text('Louveteaux'), findsOneWidget);
      expect(find.text('Patrouille'), findsOneWidget);
      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('renders first three tags plus overflow chip', (tester) async {
      await tester.pumpWidget(
        _testApp(
          TentTagChips(
            tags: [
              _tag('tag-1', 'A'),
              _tag('tag-2', 'B'),
              _tag('tag-3', 'C'),
              _tag('tag-4', 'D'),
              _tag('tag-5', 'E'),
            ],
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsNothing);
      expect(find.text('E'), findsNothing);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('shows french overflow tooltip with hidden names', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          TentTagChips(
            tags: [
              _tag('tag-1', 'A'),
              _tag('tag-2', 'B'),
              _tag('tag-3', 'C'),
              _tag('tag-4', 'D'),
              _tag('tag-5', 'E'),
            ],
          ),
        ),
      );

      await tester.longPress(find.text('+2'));
      await tester.pumpAndSettle();

      expect(find.text('Étiquettes masquées : D, E'), findsOneWidget);
    });

    testWidgets('exposes french semantics labels for tags and overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(
          TentTagChips(
            tags: [
              _tag('tag-1', 'A'),
              _tag('tag-2', 'B'),
              _tag('tag-3', 'C'),
              _tag('tag-4', 'D'),
            ],
          ),
        ),
      );

      expect(find.bySemanticsLabel('Étiquette : A'), findsOneWidget);
      expect(find.bySemanticsLabel('+1 étiquette : D'), findsOneWidget);
    });

    testWidgets('constrains long names with ellipsis', (tester) async {
      await tester.pumpWidget(
        _testApp(
          SizedBox(
            width: 140,
            child: TentTagChips(
              tags: [_tag('tag-1', 'Nom très très très long')],
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Nom très très très long'));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('calls onTagTap with tapped tag id', (tester) async {
      String? tappedTagId;

      await tester.pumpWidget(
        _testApp(
          TentTagChips(
            tags: [_tag('tag-1', 'Louveteaux')],
            onTagTap: (tagId) => tappedTagId = tagId,
          ),
        ),
      );

      await tester.tap(find.text('Louveteaux'));

      expect(tappedTagId, 'tag-1');
    });
  });
}

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: Scaffold(body: child),
  );
}

Tag _tag(String id, String name, {String color = '#2196F3'}) {
  return Tag(
    id: id,
    name: name,
    color: color,
    createdAt: DateTime.utc(2026, 6, 1),
    tentCount: 1,
  );
}
