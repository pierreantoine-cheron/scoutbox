import 'package:client/models/tent_history_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TentHistoryItem', () {
    test('fromJson parses required fields', () {
      final json = {
        'id': 'evt-1',
        'action': 'tent_created',
        'category': 'tent_info',
        'occurredAt': '2026-05-19T10:30:00Z',
        'actorUserId': 'user-1',
        'actorDisplayName': 'Jean Dupont',
        'subjectName': null,
        'details': <Map<String, dynamic>>[],
        'targetEntityType': 'Tent',
        'targetEntityId': 'tent-1',
      };

      final item = TentHistoryItem.fromJson(json);

      expect(item.id, 'evt-1');
      expect(item.action, 'tent_created');
      expect(item.category, 'tent_info');
      expect(item.occurredAt, DateTime.utc(2026, 5, 19, 10, 30));
      expect(item.actorUserId, 'user-1');
      expect(item.actorDisplayName, 'Jean Dupont');
      expect(item.subjectName, isNull);
      expect(item.details, isEmpty);
      expect(item.targetEntityType, 'Tent');
      expect(item.targetEntityId, 'tent-1');
    });

    test('fromJson uses fallback for null actorDisplayName', () {
      final json = {
        'id': 'evt-2',
        'action': 'tent_updated',
        'category': 'tent_info',
        'occurredAt': '2026-05-19T11:00:00Z',
        'actorDisplayName': null,
        'subjectName': null,
        'details': [],
      };

      final item = TentHistoryItem.fromJson(json);

      expect(item.actorDisplayName, 'Utilisateur supprimé');
    });

    test('fromJson parses details', () {
      final json = {
        'id': 'evt-3',
        'action': 'part_state_changed',
        'category': 'part_state',
        'occurredAt': '2026-05-19T12:00:00Z',
        'actorDisplayName': 'Marie',
        'subjectName': 'Toile',
        'details': [
          {
            'label': 'État',
            'oldValue': 'Good',
            'newValue': 'NeedsRepair',
            'value': null,
            'valueType': 'state',
          },
        ],
      };

      final item = TentHistoryItem.fromJson(json);

      expect(item.details.length, 1);
      expect(item.subjectName, 'Toile');
      expect(item.details[0].label, 'État');
      expect(item.details[0].oldValue, 'Good');
      expect(item.details[0].newValue, 'NeedsRepair');
      expect(item.details[0].value, isNull);
      expect(item.details[0].valueType, 'state');
    });
  });

  group('TentHistoryDetail', () {
    test('fromJson parses old_new value type', () {
      final json = {
        'label': 'Nom',
        'oldValue': 'Old Name',
        'newValue': 'New Name',
        'value': null,
        'valueType': 'old_new',
      };

      final detail = TentHistoryDetail.fromJson(json);

      expect(detail.label, 'Nom');
      expect(detail.oldValue, 'Old Name');
      expect(detail.newValue, 'New Name');
      expect(detail.valueType, 'old_new');
    });

    test('fromJson parses flag value type', () {
      final json = {
        'label': 'Commentaire',
        'oldValue': null,
        'newValue': null,
        'value': 'Commentaire modifié',
        'valueType': 'flag',
      };

      final detail = TentHistoryDetail.fromJson(json);

      expect(detail.label, 'Commentaire');
      expect(detail.value, 'Commentaire modifié');
      expect(detail.valueType, 'flag');
    });
  });
}
