import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/deep_link_service.dart';

void main() {
  group('DeepLinkService', () {
    group('parseInviteLink', () {
      test('returns InviteLinkData for valid invite link', () {
        final uri = Uri.parse(
          'scoutbox://register?server=https://example.com&invite=ABC123',
        );
        final result = DeepLinkService.parseInviteLink(uri);

        expect(result, isNotNull);
        expect(result!.serverUrl, equals('https://example.com'));
        expect(result.inviteCode, equals('ABC123'));
      });

      test('returns null for invalid scheme', () {
        final uri = Uri.parse(
          'https://register?server=https://example.com&invite=ABC123',
        );
        final result = DeepLinkService.parseInviteLink(uri);

        expect(result, isNull);
      });

      test('returns null for invalid path', () {
        final uri = Uri.parse(
          'scoutbox://login?server=https://example.com&invite=ABC123',
        );
        final result = DeepLinkService.parseInviteLink(uri);

        expect(result, isNull);
      });

      test('returns null when server parameter is missing', () {
        final uri = Uri.parse('scoutbox://register?invite=ABC123');
        final result = DeepLinkService.parseInviteLink(uri);

        expect(result, isNull);
      });

      test('returns null when invite parameter is missing', () {
        final uri = Uri.parse('scoutbox://register?server=https://example.com');
        final result = DeepLinkService.parseInviteLink(uri);

        expect(result, isNull);
      });

      test('handles URL encoded server URL', () {
        final uri = Uri.parse(
          'scoutbox://register?server=https%3A%2F%2Ftentes.groupe.fr&invite=SCOUT-2024',
        );
        final result = DeepLinkService.parseInviteLink(uri);

        expect(result, isNotNull);
        expect(result!.serverUrl, equals('https://tentes.groupe.fr'));
        expect(result.inviteCode, equals('SCOUT-2024'));
      });
    });
  });

  group('InviteLinkData', () {
    test('constructor sets properties correctly', () {
      final data = InviteLinkData(
        serverUrl: 'https://test.com',
        inviteCode: 'TEST123',
      );

      expect(data.serverUrl, equals('https://test.com'));
      expect(data.inviteCode, equals('TEST123'));
    });
  });
}
