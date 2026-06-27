String composeInviteMessage({
  required String serverUrl,
  required String inviteCode,
  required String inviteLink,
}) {
  return 'Vous avez été invité à rejoindre Scoutbox\n'
      '\n'
      'Vous pouvez télécharger l\'application ou ouvrir l\'interface web ici :\n'
      'https://www.scoutbox.app\n'
      '\n'
      'Si vous avez installé l\'application, ouvrez ce lien dans votre navigateur pour préremplir votre inscription :\n'
      '$inviteLink\n'
      '\n'
      'Sinon, voici les informations d\'inscription manuelle :\n'
      '- URL du serveur : $serverUrl\n'
      '- Code d\'invitation : $inviteCode\n'
      '\n'
      'Attention, le code d\'invitation ne peut être utilisé qu\'une seule fois et expire au bout de 30 jours.';
}
