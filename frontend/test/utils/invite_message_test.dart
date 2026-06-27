import 'package:flutter_test/flutter_test.dart';
import 'package:client/utils/invite_message.dart';

void main() {
  group('composeInviteMessage', () {
    test('includes all required sections', () {
      final message = composeInviteMessage(
        serverUrl: 'https://tentes.mon-groupe.fr',
        inviteCode: 'SCOUT-ABCDE',
        inviteLink: 'scoutbox://register?server=https%3A%2F%2Ftentes.mon-groupe.fr&invite=SCOUT-ABCDE',
      );

      expect(message, contains('Vous avez été invité à rejoindre Scoutbox'));
      expect(message, contains('https://www.scoutbox.app'));
      expect(message, contains('SCOUT-ABCDE'));
      expect(message, contains('https://tentes.mon-groupe.fr'));
      expect(message, contains('scoutbox://register'));
      expect(message, contains('ne peut être utilisé qu\'une seule fois'));
      expect(message, contains('expire au bout de 30 jours'));
    });

    test('interpolates serverUrl, inviteCode, and inviteLink correctly', () {
      final message = composeInviteMessage(
        serverUrl: 'http://localhost:5000',
        inviteCode: 'TEST-12345',
        inviteLink: 'scoutbox://register?server=http%3A%2F%2Flocalhost%3A5000&invite=TEST-12345',
      );

      expect(message, contains('- URL du serveur : http://localhost:5000'));
      expect(message, contains('- Code d\'invitation : TEST-12345'));
      expect(message, contains('scoutbox://register?server=http%3A%2F%2Flocalhost%3A5000&invite=TEST-12345'));
    });

    test('handles special characters in server URL', () {
      final message = composeInviteMessage(
        serverUrl: 'https://tentes.groupe.fr/path?param=value',
        inviteCode: 'CODE-XYZ',
        inviteLink: 'scoutbox://register?server=https%3A%2F%2Ftentes.groupe.fr%2Fpath%3Fparam%3Dvalue&invite=CODE-XYZ',
      );

      expect(message, contains('- URL du serveur : https://tentes.groupe.fr/path?param=value'));
    });

    test('message uses correct French text', () {
      final message = composeInviteMessage(
        serverUrl: 'https://test.fr',
        inviteCode: 'ABC',
        inviteLink: 'scoutbox://register?server=test&invite=ABC',
      );

      expect(message, contains('Vous avez été invité'));
      expect(message, contains('ouvrir l\'interface web ici'));
      expect(message, contains('préremplir votre inscription'));
      expect(message, contains('informations d\'inscription manuelle'));
      expect(message, contains('ne peut être utilisé'));
    });

    test('no emojis in message', () {
      final message = composeInviteMessage(
        serverUrl: 'https://test.fr',
        inviteCode: 'ABC',
        inviteLink: 'scoutbox://register?server=test&invite=ABC',
      );

      final hasEmoji = RegExp(
        r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}]',
        unicode: true,
      );
      expect(hasEmoji.hasMatch(message), isFalse);
    });
  });
}
