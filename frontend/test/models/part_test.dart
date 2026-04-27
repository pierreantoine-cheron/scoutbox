import 'package:client/models/part.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Part.fromJson', () {
    test('parses all backend states', () {
      final good = Part.fromJson({
        'id': 'p1',
        'partKindId': 'k1',
        'partKindName': 'Toile',
        'displayOrder': 1,
        'state': 'Good',
        'comments': null,
        'createdAt': '2026-04-01T10:00:00Z',
        'updatedAt': '2026-04-01T10:00:00Z',
      });

      final needsRepair = Part.fromJson({
        'id': 'p2',
        'partKindId': 'k2',
        'partKindName': 'Piquet',
        'displayOrder': 2,
        'state': 'NeedsRepair',
        'comments': 'Plié',
        'createdAt': '2026-04-01T10:00:00Z',
        'updatedAt': '2026-04-01T10:00:00Z',
      });

      final missing = Part.fromJson({
        'id': 'p3',
        'partKindId': 'k3',
        'partKindName': 'Mât',
        'displayOrder': 3,
        'state': 'Missing',
        'comments': null,
        'createdAt': '2026-04-01T10:00:00Z',
        'updatedAt': '2026-04-01T10:00:00Z',
      });

      final unusable = Part.fromJson({
        'id': 'p4',
        'partKindId': 'k4',
        'partKindName': 'Hauban',
        'displayOrder': 4,
        'state': 'Unusable',
        'comments': null,
        'createdAt': '2026-04-01T10:00:00Z',
        'updatedAt': '2026-04-01T10:00:00Z',
      });

      expect(good.state, PartState.good);
      expect(needsRepair.state, PartState.needsRepair);
      expect(missing.state, PartState.missing);
      expect(unusable.state, PartState.unusable);
    });

    test('throws FormatException for unknown backend state', () {
      expect(
        () => Part.fromJson({
          'id': 'p1',
          'partKindId': 'k1',
          'partKindName': 'Toile',
          'displayOrder': 1,
          'state': 'Broken',
          'comments': null,
          'createdAt': '2026-04-01T10:00:00Z',
          'updatedAt': '2026-04-01T10:00:00Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws FormatException for invalid timestamp', () {
      expect(
        () => Part.fromJson({
          'id': 'p1',
          'partKindId': 'k1',
          'partKindName': 'Toile',
          'displayOrder': 1,
          'state': 'Good',
          'comments': null,
          'createdAt': 'not-a-date',
          'updatedAt': '2026-04-01T10:00:00Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
