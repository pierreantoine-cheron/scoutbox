import 'package:flutter_test/flutter_test.dart';

import 'package:client/services/deep_link_service.dart';

void main() {
  group('DeepLinkService.parseInviteLink', () {
    test('returns InviteLinkData for valid scoutbox://register URI', () {
      final uri = Uri.parse(
        'scoutbox://register?server=https://tentes.groupe.fr&invite=SCOUT-2024',
      );
      final result = DeepLinkService.parseInviteLink(uri);
      expect(result, isNotNull);
      expect(result!.serverUrl, equals('https://tentes.groupe.fr'));
      expect(result.inviteCode, equals('SCOUT-2024'));
    });

    test('returns null for non-scoutbox scheme', () {
      final uri = Uri.parse(
        'https://tentes.groupe.fr/register?server=https://example.com&invite=TEST',
      );
      expect(DeepLinkService.parseInviteLink(uri), isNull);
    });

    test('returns null for non-register host', () {
      final uri = Uri.parse(
        'scoutbox://other?server=https://example.com&invite=TEST',
      );
      expect(DeepLinkService.parseInviteLink(uri), isNull);
    });

    test('returns null when server parameter is missing', () {
      final uri = Uri.parse('scoutbox://register?invite=TEST');
      expect(DeepLinkService.parseInviteLink(uri), isNull);
    });

    test('returns null when invite parameter is missing', () {
      final uri = Uri.parse('scoutbox://register?server=https://example.com');
      expect(DeepLinkService.parseInviteLink(uri), isNull);
    });

    test('returns null when both parameters are empty', () {
      final uri = Uri.parse('scoutbox://register?server=&invite=');
      expect(DeepLinkService.parseInviteLink(uri), isNull);
    });

    test('correctly URL-decodes server URL and invite code', () {
      final uri = Uri.parse(
        'scoutbox://register?server=https%3A%2F%2Ftentes.groupe.fr&invite=SCOUT-2024',
      );
      final result = DeepLinkService.parseInviteLink(uri);
      expect(result, isNotNull);
      expect(result!.serverUrl, equals('https://tentes.groupe.fr'));
      expect(result.inviteCode, equals('SCOUT-2024'));
    });

    test('handles special characters in server URL', () {
      final uri = Uri.parse(
        'scoutbox://register?server=https%3A%2F%2Fmy-server.com%2Fpath&invite=CODE-123',
      );
      final result = DeepLinkService.parseInviteLink(uri);
      expect(result, isNotNull);
      expect(result!.serverUrl, equals('https://my-server.com/path'));
    });

    test('does not decode query parameters twice', () {
      final uri = Uri.parse(
        'scoutbox://register?server=https%3A%2F%2Fmy-server.com%2Fpath%252Fencoded&invite=CODE%2525',
      );
      final result = DeepLinkService.parseInviteLink(uri);
      expect(result, isNotNull);
      expect(result!.serverUrl, equals('https://my-server.com/path%2Fencoded'));
      expect(result.inviteCode, equals('CODE%25'));
    });

    test('returns null for null-like input on empty host', () {
      final uri = Uri.parse('scoutbox://');
      expect(DeepLinkService.parseInviteLink(uri), isNull);
    });
  });

  group('parseWebQueryParams', () {
    test('returns InviteLinkData for valid web URL params', () {
      final uri = Uri.parse('https://web.scoutbox.app?server=https://tentes.fr&invite=SCOUT123');
      final result = DeepLinkService.parseWebQueryParams(uri);
      expect(result, isNotNull);
      expect(result!.serverUrl, 'https://tentes.fr');
      expect(result.inviteCode, 'SCOUT123');
    });

    test('URL-decodes parameter values', () {
      final uri = Uri.parse(
        'https://web.scoutbox.app?server=https%3A%2F%2Ftentes.fr%2Fpath&invite=CODE%20XYZ',
      );
      final result = DeepLinkService.parseWebQueryParams(uri);
      expect(result, isNotNull);
      expect(result!.serverUrl, 'https://tentes.fr/path');
      expect(result.inviteCode, 'CODE XYZ');
    });

    test('returns null when server param is missing', () {
      final uri = Uri.parse('https://web.scoutbox.app?invite=SCOUT123');
      expect(DeepLinkService.parseWebQueryParams(uri), isNull);
    });

    test('returns null when invite param is missing', () {
      final uri = Uri.parse('https://web.scoutbox.app?server=https://tentes.fr');
      expect(DeepLinkService.parseWebQueryParams(uri), isNull);
    });

    test('returns null when both params are missing', () {
      final uri = Uri.parse('https://web.scoutbox.app');
      expect(DeepLinkService.parseWebQueryParams(uri), isNull);
    });

    test('returns null for empty parameter values', () {
      final uri = Uri.parse('https://web.scoutbox.app?server=&invite=');
      expect(DeepLinkService.parseWebQueryParams(uri), isNull);
    });
  });
}
