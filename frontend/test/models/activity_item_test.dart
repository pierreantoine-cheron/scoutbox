import 'package:client/models/activity_item.dart';
import 'package:flutter/material.dart';
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
      'part_kind_created': 'Modèle de pièce créé : Toit',
      'part_kind_renamed': 'Modèle de pièce renommé : Toit',
      'part_kind_deleted': 'Modèle de pièce supprimé : Toit',
      'tag_assigned': 'Étiquette ajoutée : Groupe A',
      'tag_removed': 'Étiquette retirée : Groupe A',
      'tag_created': 'Étiquette créée : Groupe A',
      'tag_renamed': 'Étiquette renommée : Groupe A',
      'tag_color_changed': "Couleur de l'étiquette modifiée : Groupe A",
      'tag_deleted': 'Étiquette supprimée : Groupe A',
      'model_created': 'Modèle de tente créé : Canadienne',
      'model_renamed': 'Modèle de tente renommé : Canadienne',
      'model_deleted': 'Modèle de tente supprimé : Canadienne',
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

    test('part kind rename shows the old name before the new one', () {
      final parsed = item(
        action: 'part_kind_renamed',
        tentName: null,
        subjectName: 'Double toit',
        details: [
          {
            'label': 'Modèle de pièce',
            'oldValue': 'Toit',
            'newValue': 'Double toit',
            'value': null,
            'valueType': 'old_new',
          },
        ],
      );

      expect(
        parsed.buildSummary(),
        'Modèle de pièce renommé : Toit → Double toit',
      );
    });

    test('part kind deletion shows its counts and omits the zero ones', () {
      final parsed = item(
        action: 'part_kind_deleted',
        tentName: null,
        subjectName: 'Toit',
        details: [
          {
            'label': 'Tentes',
            'value': '2',
            'valueType': 'count',
          },
          {
            'label': 'Pièces',
            'value': '1',
            'valueType': 'count',
          },
          {
            'label': 'Modèles de tente',
            'value': '0',
            'valueType': 'count',
          },
        ],
      );

      expect(
        parsed.buildSummary(),
        'Modèle de pièce supprimé : Toit (2 tentes, 1 pièce)',
      );
    });

    test('part kind deletion without counts reads plainly', () {
      final parsed = item(
        action: 'part_kind_deleted',
        tentName: null,
        subjectName: 'Toit',
        details: [
          {
            'label': 'Tentes',
            'value': '0',
            'valueType': 'count',
          },
        ],
      );

      expect(parsed.buildSummary(), 'Modèle de pièce supprimé : Toit');
    });

    test('a cascade part deletion says the modèle de pièce was deleted', () {
      final parsed = item(
        action: 'part_deleted',
        tentName: null,
        subjectName: 'Toit',
        details: [
          {
            'label': 'Raison',
            'value': 'part_kind_deleted',
            'valueType': 'reason',
          },
        ],
      );

      expect(
        parsed.buildSummary(),
        'Pièce supprimée : Toit (modèle de pièce supprimé)',
      );
    });

    test('a cascade model component change names the removed kind and says why', () {
      final parsed = item(
        action: 'model_components_changed',
        tentName: null,
        subjectName: 'Canadienne',
        details: [
          {
            'label': 'Modèle de pièce retiré',
            'value': 'Toit',
            'valueType': 'removed_component',
          },
          {
            'label': 'Raison',
            'value': 'part_kind_deleted',
            'valueType': 'reason',
          },
        ],
      );

      expect(
        parsed.buildSummary(),
        'Modèle de pièce retiré : Toit (modèle de pièce supprimé)',
      );
    });

    test('legacy rename without before and after still renders', () {
      final parsed = item(
        action: 'model_renamed',
        tentName: null,
        subjectName: 'Canadienne',
      );

      expect(parsed.buildSummary(), 'Modèle de tente renommé : Canadienne');
    });

    test('component changes name the before and after sets', () {
      final parsed = item(
        action: 'model_components_changed',
        tentName: null,
        subjectName: 'Canadienne',
        details: [
          {
            'label': 'Modèles de pièce',
            'oldValue': 'Toit, Double toit',
            'newValue': 'Toit, Tapis de sol',
            'value': null,
            'valueType': 'components',
          },
        ],
      );

      expect(
        parsed.buildSummary(),
        'Modèles de pièce changés de Toit, Double toit à Toit, Tapis de sol',
      );
    });

    test('component changes read an empty set as aucun', () {
      final parsed = item(
        action: 'model_components_changed',
        tentName: null,
        subjectName: 'Canadienne',
        details: [
          {
            'label': 'Modèles de pièce',
            'oldValue': '',
            'newValue': 'Toit',
            'value': null,
            'valueType': 'components',
          },
        ],
      );

      expect(parsed.buildSummary(), 'Modèles de pièce changés de aucun à Toit');
    });

    test('component changes without a detail still speak the vocabulary', () {
      final parsed = item(action: 'model_components_changed', tentName: null);

      expect(
        parsed.buildSummary(),
        'Modèles de pièce du modèle de tente modifiés',
      );
    });

    test('a part with no resolved name names the part as unknown', () {
      final parsed = item(action: 'part_added', tentName: null);

      expect(parsed.buildSummary(), 'Pièce ajoutée : Pièce inconnue');
    });

    test('a tent model with no resolved name names the tent model', () {
      final parsed = item(action: 'model_created', tentName: null);

      expect(
        parsed.buildSummary(),
        'Modèle de tente créé : Modèle de tente inconnu',
      );
    });

    test('a tag with no resolved name names the tag', () {
      final parsed = item(action: 'tag_created', tentName: null);

      expect(parsed.buildSummary(), 'Étiquette créée : Étiquette inconnue');
    });

    test('a part kind with no resolved name names the part kind', () {
      final parsed = item(action: 'part_kind_created', tentName: null);

      expect(
        parsed.buildSummary(),
        'Modèle de pièce créé : Modèle de pièce inconnu',
      );
    });

    test('a part state change with no resolved name names the part', () {
      final parsed = item(action: 'part_state_changed', tentName: null);

      expect(parsed.buildSummary(), 'État de Pièce inconnue changé de ? à ?');
    });

    test('a tent action with no subject does not borrow part vocabulary', () {
      for (final action in [
        'tent_created',
        'tent_updated',
        'tent_archived',
        'tent_unarchived',
      ]) {
        final parsed = item(action: action, tentName: null);
        final summary = parsed.buildSummary();

        expect(summary, isNot(contains('Pièce inconnue')), reason: action);
        expect(summary, isNot(contains('Modèle de pièce inconnu')), reason: action);
        expect(summary, isNot(contains('Modèle de tente inconnu')), reason: action);
        expect(summary, isNot(contains('Étiquette inconnue')), reason: action);
      }
    });

    testWidgets('buildSummarySpan reads like buildSummary', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                final normal = theme.textTheme.bodyMedium ?? const TextStyle();
                final bold = normal.copyWith(fontWeight: FontWeight.w600);

                for (final action in [
                  'part_added',
                  'part_deleted',
                  'part_kind_created',
                  'part_kind_renamed',
                  'part_kind_deleted',
                  'model_created',
                  'model_renamed',
                  'model_components_changed',
                  'tag_created',
                ]) {
                  final parsed = item(
                    action: action,
                    tentName: null,
                    subjectName: _subjectFor(action),
                  );
                  expect(
                    parsed.buildSummarySpan(normal, bold).toPlainText(),
                    parsed.buildSummary(),
                    reason: action,
                  );
                }

                final partKindRename = item(
                  action: 'part_kind_renamed',
                  tentName: null,
                  subjectName: 'Double toit',
                  details: [
                    {
                      'label': 'Modèle de pièce',
                      'oldValue': 'Toit',
                      'newValue': 'Double toit',
                      'value': null,
                      'valueType': 'old_new',
                    },
                  ],
                );
                expect(
                  partKindRename.buildSummarySpan(normal, bold).toPlainText(),
                  partKindRename.buildSummary(),
                );

                final componentChange = item(
                  action: 'model_components_changed',
                  tentName: null,
                  subjectName: 'Canadienne',
                  details: [
                    {
                      'label': 'Modèles de pièce',
                      'oldValue': 'Toit, Double toit',
                      'newValue': 'Toit, Tapis de sol',
                      'value': null,
                      'valueType': 'components',
                    },
                  ],
                );
                expect(
                  componentChange.buildSummarySpan(normal, bold).toPlainText(),
                  componentChange.buildSummary(),
                );
                expect(
                  componentChange.actionDotColor(theme.colorScheme),
                  theme.colorScheme.tertiary,
                );

                final kindDeletion = item(
                  action: 'part_kind_deleted',
                  tentName: null,
                  subjectName: 'Toit',
                  details: [
                    {
                      'label': 'Tentes',
                      'value': '3',
                      'valueType': 'count',
                    },
                  ],
                );
                expect(
                  kindDeletion.buildSummarySpan(normal, bold).toPlainText(),
                  kindDeletion.buildSummary(),
                );
                expect(
                  kindDeletion.actionDotColor(theme.colorScheme),
                  theme.colorScheme.error,
                );

                final cascadePartDeletion = item(
                  action: 'part_deleted',
                  tentName: null,
                  subjectName: 'Toit',
                  details: [
                    {
                      'label': 'Raison',
                      'value': 'part_kind_deleted',
                      'valueType': 'reason',
                    },
                  ],
                );
                expect(
                  cascadePartDeletion.buildSummarySpan(normal, bold).toPlainText(),
                  cascadePartDeletion.buildSummary(),
                );

                final cascadeComponentChange = item(
                  action: 'model_components_changed',
                  tentName: null,
                  subjectName: 'Canadienne',
                  details: [
                    {
                      'label': 'Modèle de pièce retiré',
                      'value': 'Toit',
                      'valueType': 'removed_component',
                    },
                    {
                      'label': 'Raison',
                      'value': 'part_kind_deleted',
                      'valueType': 'reason',
                    },
                  ],
                );
                expect(
                  cascadeComponentChange.buildSummarySpan(normal, bold).toPlainText(),
                  cascadeComponentChange.buildSummary(),
                );

                final unresolved = item(action: 'part_added', tentName: null);
                expect(
                  unresolved.buildSummarySpan(normal, bold).toPlainText(),
                  'Pièce ajoutée : Pièce inconnue',
                );

                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    test('tent model changes read as modèle de tente', () {
      final parsed = item(
        action: 'tent_updated',
        tentName: 'Tente Atlas',
        details: [
          {
            'label': 'Modèle de tente',
            'oldValue': 'Marabout',
            'newValue': 'Cabanon',
            'value': null,
            'valueType': 'old_new',
          },
        ],
      );

      expect(parsed.buildSummary(), 'Modèle de tente changé de Marabout à Cabanon');
    });

    test('unknown action never exposes the raw action code', () {
      final parsed = item(action: 'something_new', tentName: null);

      expect(parsed.buildSummary(), 'Activité enregistrée');
      expect(parsed.buildSummary(), isNot(contains('something_new')));
    });

    test('each event type carries its own icon', () {
      final icons = {
        'tent_created': Icons.add_circle_outline,
        'tent_archived': Icons.archive_outlined,
        'part_state_changed': Icons.swap_horiz,
        'part_kind_created': Icons.category_outlined,
        'part_kind_renamed': Icons.edit_outlined,
        'part_kind_deleted': Icons.delete_outline,
        'tag_assigned': Icons.label_outlined,
        'tag_color_changed': Icons.palette_outlined,
        'model_created': Icons.grid_view_outlined,
        'model_components_changed': Icons.dashboard_customize_outlined,
        'invite_created': Icons.mail_outline,
      };

      for (final entry in icons.entries) {
        expect(item(action: entry.key).actionIcon, entry.value, reason: entry.key);
      }
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
  if (action.startsWith('part_kind_')) return 'Toit';
  if (action.startsWith('part_')) return 'Toile';
  if (action.startsWith('tag_')) return 'Groupe A';
  if (action.startsWith('model_')) return 'Canadienne';
  return null;
}
