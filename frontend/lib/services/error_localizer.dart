import '../utils/constants.dart';

class ErrorLocalizer {
  ErrorLocalizer._();

  static String localize(String? code, {String? fallback}) {
    final message = code != null ? _messages[code] : null;
    if (message != null) return message;

    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  static const _messages = <String, String>{
    ErrorCodes.invalidInvite: "Code d'invitation invalide, expiré ou déjà utilisé",
    ErrorCodes.usernameExists: "Ce nom d'utilisateur est déjà pris",
    ErrorCodes.codeGenerationFailed:
        "Impossible de générer un code d'invitation. Veuillez réessayer.",
    ErrorCodes.invalidRefreshToken: 'Session expirée. Veuillez vous reconnecter.',
    ErrorCodes.invalidCredentials: 'Identifiants incorrects. Veuillez réessayer.',
    ErrorCodes.unauthorized: 'Accès non autorisé',
    ErrorCodes.internalError: 'Une erreur interne est survenue. Veuillez réessayer plus tard.',
    ErrorCodes.tentNameRequired: 'Le nom de la tente est requis',
    ErrorCodes.tentNameExists: 'Une tente avec ce nom existe déjà',
    ErrorCodes.invalidTentSize: 'La taille doit être comprise entre 1 et 100',
    ErrorCodes.invalidTentModel: 'Le modèle de tente sélectionné est invalide',
    ErrorCodes.invalidTentState: "L'état de la tente est invalide",
    ErrorCodes.tentCreateFailed: 'Erreur serveur. Réessayez',
    ErrorCodes.tentNotFound: 'Tente introuvable',
    ErrorCodes.partNotFound: 'Pièce introuvable.',
    ErrorCodes.invalidPartState: "L'état de la pièce est invalide.",
    ErrorCodes.tentArchived: 'Cette tente est archivée et ne peut plus être modifiée.',
    ErrorCodes.duplicatePart: 'Cette pièce existe déjà sur cette tente.',
    ErrorCodes.invalidPartKind: 'Modèle de pièce invalide.',
    ErrorCodes.invalidRequest: 'Requête invalide. Vérifiez les données saisies.',
    ErrorCodes.tagNameExists: 'Une étiquette avec ce nom existe déjà',
    ErrorCodes.tagNameRequired: 'Le nom de l\'étiquette est requis',
    ErrorCodes.tagNameTooShort: 'Le nom de l\'étiquette doit contenir au moins 2 caractères',
    ErrorCodes.tagNameTooLong: 'Le nom de l\'étiquette doit contenir 30 caractères maximum',
    ErrorCodes.invalidTagColor: 'La couleur sélectionnée est invalide',
    ErrorCodes.tagNotFound:
        'Une étiquette sélectionnée est introuvable. La liste a été actualisée.',
    ErrorCodes.partKindNameExists: 'Un modèle de pièce avec ce nom existe déjà',
    ErrorCodes.partKindNameRequired: 'Le nom du modèle de pièce est requis',
    ErrorCodes.partKindNameTooLong: 'Le nom du modèle de pièce est trop long (60 max)',
    ErrorCodes.partKindNotFound: 'Modèle de pièce introuvable',
    ErrorCodes.tentModelNotFound: 'Ce modèle de tente est introuvable.',
    ErrorCodes.modelInUse:
        'Impossible de supprimer ce modèle de tente car des tentes l\'utilisent encore.',
    ErrorCodes.modelNameExists: 'Un modèle de tente avec ce nom existe déjà.',
    ErrorCodes.modelNameRequired:
        'Le nom du modèle de tente doit contenir au moins 2 caractères.',
    ErrorCodes.modelNameTooLong:
        'Le nom du modèle de tente doit contenir 60 caractères maximum.',
  };
}
