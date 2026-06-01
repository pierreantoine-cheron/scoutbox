import 'package:client/models/tent.dart';
import 'package:client/models/tag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tent.fromJson', () {
    test('parses updatedAt when valid', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
        'updatedAt': '2026-04-12T10:30:00Z',
      });

      expect(tent.updatedAt, isNotNull);
      expect(tent.updatedAt?.toUtc(), DateTime.utc(2026, 4, 12, 10, 30));
    });

    test('keeps updatedAt null when field is missing', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
      });

      expect(tent.updatedAt, isNull);
    });

    test('throws FormatException when timestamp is invalid', () {
      expect(
        () => Tent.fromJson({
          'id': 't1',
          'name': 'Tente Atlas',
          'size': 6,
          'tentModelId': 'shape-1',
          'tentModelName': 'Canadienne',
          'overallState': 'Good',
          'comments': null,
          'updatedAt': 'not-a-date',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('parses detail payload with parts and createdAt', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'NeedsRepair',
        'comments': 'Commentaires tente',
        'createdAt': '2026-04-11T08:30:00Z',
        'updatedAt': '2026-04-12T10:30:00Z',
        'parts': [
          {
            'id': 'p1',
            'partKindId': 'kind-1',
            'partKindName': 'Toile',
            'displayOrder': 1,
            'state': 'Good',
            'comments': null,
            'createdAt': '2026-04-11T08:30:00Z',
            'updatedAt': '2026-04-12T10:30:00Z',
          },
        ],
      });

      expect(tent.createdAt?.toUtc(), DateTime.utc(2026, 4, 11, 8, 30));
      expect(tent.parts, hasLength(1));
      expect(tent.parts.first.partKindName, equals('Toile'));
    });

    test('uses empty part list when parts field is missing', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
      });

      expect(tent.parts, isEmpty);
    });

    test('parses tags array', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
        'tags': [
          {
            'id': 'tag-1',
            'name': 'Groupe A',
            'color': '#F44336',
            'createdAt': '2026-06-01T10:00:00Z',
            'tentCount': 1,
          },
        ],
      });

      expect(tent.tags, hasLength(1));
      expect(tent.tags.first.name, equals('Groupe A'));
      expect(tent.tags.first.color, equals('#F44336'));
    });

    test('uses empty tag list when tags field is missing or null', () {
      final withoutTags = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
      });
      final nullTags = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
        'tags': null,
      });

      expect(withoutTags.tags, isEmpty);
      expect(nullTags.tags, isEmpty);
    });

    test('copyWith can replace tags', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentModelId': 'shape-1',
        'tentModelName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
      });

      final updated = tent.copyWith(
        tags: [
          Tag(
            id: 'tag-1',
            name: 'Groupe A',
            color: '#F44336',
            createdAt: DateTime.utc(2026, 6, 1),
            tentCount: 1,
          ),
        ],
      );

      expect(updated.tags, hasLength(1));
      expect(updated.tags.first.id, equals('tag-1'));
    });
  });
}
