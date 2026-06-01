import 'package:flutter_test/flutter_test.dart';
import 'package:client/models/tag.dart';

void main() {
  group('Tag', () {
    test('parses valid JSON', () {
      final tag = Tag.fromJson({
        'id': 'tag-1',
        'name': 'À réparer',
        'color': '#F44336',
        'createdAt': '2026-06-01T08:10:45Z',
        'tentCount': 2,
      });

      expect(tag.id, equals('tag-1'));
      expect(tag.name, equals('À réparer'));
      expect(tag.color, equals('#F44336'));
      expect(tag.createdAt.toUtc().year, equals(2026));
      expect(tag.tentCount, equals(2));
    });

    test('throws FormatException for malformed response', () {
      expect(
        () => Tag.fromJson({
          'id': 'tag-1',
          'name': 'Groupe A',
          'color': '#2196F3',
          'createdAt': 'not-a-date',
          'tentCount': 0,
        }),
        throwsFormatException,
      );
    });
  });
}
