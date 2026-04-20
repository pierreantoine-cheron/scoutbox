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

    test('keeps updatedAt null when timestamp is invalid', () {
      final tent = Tent.fromJson({
        'id': 't1',
        'name': 'Tente Atlas',
        'size': 6,
        'tentShapeId': 'shape-1',
        'tentShapeName': 'Canadienne',
        'overallState': 'Good',
        'comments': null,
        'updatedAt': 'not-a-date',
      });

      expect(tent.updatedAt, isNull);
    });
  });
}
