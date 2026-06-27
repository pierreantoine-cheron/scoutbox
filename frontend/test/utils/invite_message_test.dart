import 'package:flutter_test/flutter_test.dart';
import 'package:client/utils/invite_message.dart';

void main() {
  group('composeInviteMessage', () {
    test('includes all required sections', () {
      final message = composeInviteMessage(
        serverUrl: 'https://tentes.mon-groupe.fr',
        inviteCode: 'SCOUT-ABCDE',
      );

      expect(message, contains('Vous avez été invité à rejoindre Scoutbox'));
      expect(message, contains('https://www.scoutbox.app'));
      expect(message, contains('scoutbox.app/register'));
      expect(message, contains('SCOUT-ABCDE'));
      expect(message, contains('https://tentes.mon-groupe.fr'));
      expect(message, contains('ne peut être utilisé qu\'une seule fois'));
      expect(message, contains('expire au bout de 30 jours'));
    });

    test('HTTPS link is properly URL-encoded', () {
      final message = composeInviteMessage(
        serverUrl: 'https://tentes.groupe.fr/path',
        inviteCode: 'CODE-XYZ',
      );

      expect(message, contains(
        'https://www.scoutbox.app/register?server=https%3A%2F%2Ftentes.groupe.fr%2Fpath&invite=CODE-XYZ',
      ));
    });

    test('no scoutbox:// deep link in message', () {
      final message = composeInviteMessage(
        serverUrl: 'https://test.fr',
        inviteCode: 'ABC',
      );

      expect(message, isNot(contains('scoutbox://')));
    });

    test('manual fallback section still present', () {
      final message = composeInviteMessage(
        serverUrl: 'https://test.fr',
        inviteCode: 'ABC',
      );

      expect(message, contains('- URL du serveur : https://test.fr'));
      expect(message, contains('- Code d\'invitation : ABC'));
    });

    test('no emojis in message', () {
      final message = composeInviteMessage(
        serverUrl: 'https://test.fr',
        inviteCode: 'ABC',
      );

      final hasEmoji = RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      expect(hasEmoji.hasMatch(message), isFalse);
    });
  });
}
