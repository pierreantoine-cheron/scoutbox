import 'package:client/models/tent_history_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TentHistoryItem makeTentUpdatedItem(List<Map<String, dynamic>> details) {
  return TentHistoryItem.fromJson({
    'id': 'evt-upd',
    'action': 'tent_updated',
    'category': 'tent_info',
    'occurredAt': '2026-05-19T12:00:00Z',
    'actorDisplayName': 'Jean',
    'subjectName': null,
    'details': details,
  });
}

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

  group('buildSummary for tent_updated', () {
    test('state change produces descriptive message', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'État',
          'oldValue': 'Good',
          'newValue': 'Unusable',
          'value': null,
          'valueType': 'state',
        },
      ]);

      expect(
        item.buildSummary(),
        'État général de la tente changé de Bon état à Inutilisable',
      );
    });

    test('state change to NeedsRepair', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'État',
          'oldValue': 'Good',
          'newValue': 'NeedsRepair',
          'value': null,
          'valueType': 'state',
        },
      ]);

      expect(
        item.buildSummary(),
        'État général de la tente changé de Bon état à À réparer',
      );
    });

    test('size change formats with places suffix', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'Taille',
          'oldValue': '20',
          'newValue': '12',
          'value': null,
          'valueType': 'old_new',
        },
      ]);

      expect(
        item.buildSummary(),
        'Taille de la tente changée de 20 places à 12 places',
      );
    });

    test('name change produces descriptive message', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'Nom',
          'oldValue': 'Tente A',
          'newValue': 'Tente B',
          'value': null,
          'valueType': 'old_new',
        },
      ]);

      expect(
        item.buildSummary(),
        'Nom de la tente changé de Tente A à Tente B',
      );
    });

    test('model change produces descriptive message', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'Modèle',
          'oldValue': 'Marabout',
          'newValue': 'Cabanon',
          'value': null,
          'valueType': 'old_new',
        },
      ]);

      expect(
        item.buildSummary(),
        'Modèle de la tente changé de Marabout à Cabanon',
      );
    });

    test('comment change produces simple message', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'Commentaire',
          'oldValue': null,
          'newValue': null,
          'value': 'Commentaire modifié',
          'valueType': 'flag',
        },
      ]);

      expect(item.buildSummary(), 'Commentaire modifié');
    });

    test('multiple changes are joined with comma', () {
      final item = makeTentUpdatedItem([
        {
          'label': 'État',
          'oldValue': 'Good',
          'newValue': 'NeedsRepair',
          'value': null,
          'valueType': 'state',
        },
        {
          'label': 'Taille',
          'oldValue': '20',
          'newValue': '12',
          'value': null,
          'valueType': 'old_new',
        },
      ]);

      expect(
        item.buildSummary(),
        'État général de la tente changé de Bon état à À réparer, '
        'Taille de la tente changée de 20 places à 12 places',
      );
    });

    test('empty details fall back to generic message', () {
      final item = makeTentUpdatedItem([]);

      expect(item.buildSummary(), 'Informations mises à jour');
    });
  });

  testWidgets('buildSummarySpan uses bold for values in tent_updated', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) {
        final item = makeTentUpdatedItem([
          {
            'label': 'État',
            'oldValue': 'Good',
            'newValue': 'Unusable',
            'value': null,
            'valueType': 'state',
          },
        ]);
        final span = item.buildSummarySpan(context);
        final plain = span.toPlainText();
        expect(plain, 'État général de la tente changé de Bon état à Inutilisable');

        final children = (span as TextSpan).children!;
        expect(children.length, 4);

        expect((children[0] as TextSpan).text, 'État général de la tente changé de ');
        expect((children[1] as TextSpan).text, 'Bon état');
        expect((children[1] as TextSpan).style!.fontWeight, FontWeight.w600);
        expect((children[2] as TextSpan).text, ' à ');
        expect((children[3] as TextSpan).text, 'Inutilisable');
        expect((children[3] as TextSpan).style!.fontWeight, FontWeight.w600);

        return const SizedBox();
      },
    ))));
  });

  testWidgets('buildSummarySpan uses bold for part_state_changed values', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) {
        final item = TentHistoryItem.fromJson({
          'id': 'evt-part',
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
        });
        final span = item.buildSummarySpan(context);
        final plain = span.toPlainText();
        expect(plain, contains('Toile'));
        expect(plain, contains('Bon état'));
        expect(plain, contains('À réparer'));

        final children = (span as TextSpan).children!;
        expect(children.length, 4);
        expect((children[1] as TextSpan).style!.fontWeight, FontWeight.w600);
        expect((children[3] as TextSpan).style!.fontWeight, FontWeight.w600);

        return const SizedBox();
      },
    ))));
  });

  testWidgets('buildSummarySpan falls back to plain text for other actions', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) {
        final item = TentHistoryItem.fromJson({
          'id': 'evt-1',
          'action': 'tent_created',
          'category': 'tent_info',
          'occurredAt': '2026-05-19T12:00:00Z',
          'actorDisplayName': 'Jean',
          'subjectName': null,
          'details': [],
        });
        final span = item.buildSummarySpan(context);
        expect(span.toPlainText(), 'Tente créée');
        return const SizedBox();
      },
    ))));
  });

  testWidgets('buildSummarySpan bolds tag name for tag_assigned', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) {
        final item = TentHistoryItem.fromJson({
          'id': 'evt-tag',
          'action': 'tag_assigned',
          'category': 'tags',
          'occurredAt': '2026-05-19T12:00:00Z',
          'actorDisplayName': 'Jean',
          'subjectName': 'Bleu',
          'details': [],
        });
        final span = item.buildSummarySpan(context);
        expect(span.toPlainText(), 'Étiquette ajoutée : Bleu');

        final children = (span as TextSpan).children!;
        expect(children.length, 2);
        expect((children[0] as TextSpan).text, 'Étiquette ajoutée : ');
        expect((children[0] as TextSpan).style!.fontWeight, isNot(FontWeight.w600));
        expect((children[1] as TextSpan).text, 'Bleu');
        expect((children[1] as TextSpan).style!.fontWeight, FontWeight.w600);

        return const SizedBox();
      },
    ))));
  });

  testWidgets('buildSummarySpan bolds tag name for tag_removed', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
      builder: (context) {
        final item = TentHistoryItem.fromJson({
          'id': 'evt-tag',
          'action': 'tag_removed',
          'category': 'tags',
          'occurredAt': '2026-05-19T12:00:00Z',
          'actorDisplayName': 'Jean',
          'subjectName': 'Rouge',
          'details': [],
        });
        final span = item.buildSummarySpan(context);
        expect(span.toPlainText(), 'Étiquette retirée : Rouge');

        final children = (span as TextSpan).children!;
        expect(children.length, 2);
        expect((children[0] as TextSpan).text, 'Étiquette retirée : ');
        expect((children[1] as TextSpan).text, 'Rouge');
        expect((children[1] as TextSpan).style!.fontWeight, FontWeight.w600);

        return const SizedBox();
      },
    ))));
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
