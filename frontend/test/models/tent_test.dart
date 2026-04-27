import 'package:client/models/tent.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tent.fromJson', () {
    test('parses updatedAt when valid', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentShapeId': 'shape-1',
        'tentShapeName': 'Canadienne',
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
        'tentShapeId': 'shape-1',
        'tentShapeName': 'Canadienne',
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
          'tentShapeId': 'shape-1',
          'tentShapeName': 'Canadienne',
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
        'tentShapeId': 'shape-1',
        'tentShapeName': 'Canadienne',
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
        'tentShapeId': 'shape-1',
        'tentShapeName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
      });

      expect(tent.parts, isEmpty);
    });
  });
}
