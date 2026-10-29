import 'package:client/models/activity_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

ActivityItem item({
  String action = 'tent_created',
  String? tentName = 'Tente Atlas',
  String? subjectName,
  String actorDisplayName = 'Jean',
  DateTime? occurredAt,
  List<Map<String, dynamic>> details = const [],
}) {
  return ActivityItem.fromJson({
    'id': 'evt-1',
    'action': action,
    'category': 'tents',
    'occurredAt': (occurredAt ?? DateTime.utc(2026, 5, 19, 12)).toIso8601String(),
    'actorUserId': 'user-1',
    'actorDisplayName': actorDisplayName,
    'tentId': tentName == null ? null : 'tent-1',
    'tentName': tentName,
    'subjectName': subjectName,
    'details': details,
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  group('ActivityItem parsing', () {
    test('parses every journal field', () {
      final parsed = ActivityItem.fromJson({
        'id': 'evt-1',
        'action': 'part_state_changed',
        'category': 'parts',
        'occurredAt': '2026-05-19T10:30:00Z',
        'actorUserId': 'user-1',
        'actorDisplayName': 'Jean Dupont',
        'tentId': 'tent-1',
        'tentName': 'Tente Atlas',
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
      });

      expect(parsed.id, 'evt-1');
      expect(parsed.category, 'parts');
      expect(parsed.occurredAt, DateTime.utc(2026, 5, 19, 10, 30));
      expect(parsed.tentId, 'tent-1');
      expect(parsed.tentName, 'Tente Atlas');
      expect(parsed.subjectName, 'Toile');
      expect(parsed.actorDisplayName, 'Jean Dupont');
      expect(parsed.details.single.label, 'État');
    });

    test('keeps the system account display name', () {
      expect(item(actorDisplayName: 'Système').actorDisplayName, 'Système');
    });

    test('parses a page with its next cursor', () {
      final page = ActivityPage.fromJson({
        'items': [],
        'nextCursor': 'cursor-token',
      });

      expect(page.items, isEmpty);
      expect(page.nextCursor, 'cursor-token');
    });
  });

  group('ActivityItem wording', () {
    final cases = <String, String>{
      'tent_created': 'Tente créée',
      'tent_updated': 'Informations mises à jour',
      'tent_archived': 'Tente archivée',
      'tent_unarchived': 'Tente désarchivée',
      'part_comments_changed': 'Commentaire de Toile modifié',
      'part_added': 'Pièce ajoutée : Toile',
      'part_deleted': 'Pièce supprimée : Toile',
      'tag_assigned': 'Étiquette ajoutée : Groupe A',
      'tag_removed': 'Étiquette retirée : Groupe A',
      'tag_created': 'Étiquette créée : Groupe A',
      'tag_renamed': 'Étiquette renommée : Groupe A',
      'tag_deleted': 'Étiquette supprimée : Groupe A',
      'model_created': 'Modèle créé : Canadienne',
      'model_renamed': 'Modèle renommé : Canadienne',
      'model_deleted': 'Modèle supprimé : Canadienne',
      'invite_created': 'Invitation créée',
      'user_registered_from_invite': 'Compte créé',
    };

    for (final entry in cases.entries) {
      test('${entry.key} has French wording', () {
        final parsed = item(
          action: entry.key,
          tentName: null,
          subjectName: _subjectFor(entry.key),
        );

        expect(parsed.buildSummary(), entry.value);
        expect(parsed.buildSummary(), isNot(startsWith('Action ')));
      });
    }

    test('part state change names both states', () {
      final parsed = item(
        action: 'part_state_changed',
        subjectName: 'Toile',
        details: [
          {
            'label': 'État',
            'oldValue': 'Good',
            'newValue': 'NeedsRepair',
            'value': null,
            'valueType': 'state',
          },
        ],
      );

      expect(parsed.buildSummary(), 'État de Toile changé de Bon état à À réparer');
    });

    test('rename with before and after names both values', () {
      final parsed = item(
        action: 'tag_renamed',
        tentName: null,
        subjectName: 'Groupe B',
        details: [
          {
            'label': 'Étiquette',
            'oldValue': 'Groupe A',
            'newValue': 'Groupe B',
            'value': null,
            'valueType': 'old_new',
          },
        ],
      );

      expect(parsed.buildSummary(), 'Étiquette renommée de Groupe A à Groupe B');
    });

    test('legacy rename without before and after still renders', () {
      final parsed = item(
        action: 'model_renamed',
        tentName: null,
        subjectName: 'Canadienne',
      );

      expect(parsed.buildSummary(), 'Modèle renommé : Canadienne');
    });

    test('unknown action never exposes the raw action code', () {
      final parsed = item(action: 'something_new', tentName: null);

      expect(parsed.buildSummary(), 'Activité enregistrée');
      expect(parsed.buildSummary(), isNot(contains('something_new')));
    });
  });

  group('ActivityItem day headings', () {
    final now = DateTime(2026, 5, 19, 18);

    test('today reads Aujourd\'hui', () {
      final parsed = item(occurredAt: DateTime(2026, 5, 19, 8));

      expect(parsed.localDayLabel(now: now), "Aujourd'hui");
    });

    test('yesterday reads Hier', () {
      final parsed = item(occurredAt: DateTime(2026, 5, 18, 23));

      expect(parsed.localDayLabel(now: now), 'Hier');
    });

    test('older days read the French date', () {
      final parsed = item(occurredAt: DateTime(2026, 5, 16, 12));

      expect(parsed.localDayLabel(now: now), 'Samedi 16 mai 2026');
    });
  });
}

String? _subjectFor(String action) {
  if (action.startsWith('part_')) return 'Toile';
  if (action.startsWith('tag_')) return 'Groupe A';
  if (action.startsWith('model_')) return 'Canadienne';
  return null;
}
