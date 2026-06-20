import 'package:client/models/tag.dart';
import 'package:client/providers/tent_filter_provider.dart';
import 'package:client/utils/app_theme.dart';
import 'package:client/views/widgets/tent_tag_filter_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TentTagFilterSheet', () {
    testWidgets('shows tags sorted by tent count and toggles selection', (
      tester,
    ) async {
      String? toggledTagId;

      await tester.pumpWidget(
        _testApp(
          selection: const {'tag-high'},
          child: TentTagFilterSheet(
            tags: [_tagLow, _tagHigh, _tagUnused],
            onToggleTag: (tagId) => toggledTagId = tagId,
            onClearTags: () {},
          ),
        ),
      );

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList();

      expect(
        labels.indexOf('Groupe A (8)'),
        lessThan(labels.indexOf('Stock nord (2)')),
      );
      expect(
        labels.indexOf('Stock nord (2)'),
        lessThan(labels.indexOf('Inutilisée (0)')),
      );

      await tester.tap(find.text('Stock nord (2)'));

      expect(toggledTagId, 'tag-low');
    });

    testWidgets('search filters tags by name', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: TentTagFilterSheet(
            tags: [_tagLow, _tagHigh, _tagUnused],
            onToggleTag: (_) {},
            onClearTags: () {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'stock');
      await tester.pump();

      expect(find.text('Stock nord (2)'), findsOneWidget);
      expect(find.text('Groupe A (8)'), findsNothing);
    });

    testWidgets('clear all button calls callback', (tester) async {
      var cleared = false;

      await tester.pumpWidget(
        _testApp(
          selection: const {'tag-high'},
          child: TentTagFilterSheet(
            tags: [_tagHigh],
            onToggleTag: (_) {},
            onClearTags: () => cleared = true,
          ),
        ),
      );

      await tester.tap(find.text('Effacer tout'));

      expect(cleared, isTrue);
    });
  });
}

Widget _testApp({Set<String>? selection, required Widget child}) {
  return ProviderScope(
    overrides: [
      tentListFilterProvider.overrideWith(
        () => _TestFilterNotifier(selection ?? const {}),
      ),
    ],
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory, extensions: const [AppTheme.semanticColorsForTests]),
      home: Scaffold(body: child),
    ),
  );
}

class _TestFilterNotifier extends TentListFilterNotifier {
  final Set<String> _selection;

  _TestFilterNotifier(this._selection);

  @override
  TentListFilterState build() => TentListFilterState(
    selectedTagIds: _selection,
  );
}

final _tagHigh = Tag(
  id: 'tag-high',
  name: 'Groupe A',
  color: '#4CAF50',
  createdAt: DateTime.utc(2026, 6, 1),
  tentCount: 8,
);

final _tagLow = Tag(
  id: 'tag-low',
  name: 'Stock nord',
  color: '#2196F3',
  createdAt: DateTime.utc(2026, 6, 1),
  tentCount: 2,
);

final _tagUnused = Tag(
  id: 'tag-unused',
  name: 'Inutilisée',
  color: '#9E9E9E',
  createdAt: DateTime.utc(2026, 6, 1),
  tentCount: 0,
);
