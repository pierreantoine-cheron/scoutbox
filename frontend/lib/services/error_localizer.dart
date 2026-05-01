import '../utils/app_config.dart';
import '../utils/constants.dart';

class ErrorLocalizer {
  ErrorLocalizer._();

  static String localize(String? code, {String? fallback}) {
    final message = code != null ? _messages[code] : null;
    if (message != null) return message;

    if (AppConfig.showUnknownBackendDetails &&
        fallback != null &&
        fallback.isNotEmpty) {
      return fallback;
    }

    return 'Une erreur est survenue. Veuillez réessayer.';
  }

  static const _messages = <String, String>{
    ErrorCodes.invalidInvite:
        "Code d'invitation invalide, expiré ou déjà utilisé",
    ErrorCodes.usernameExists: "Ce nom d'utilisateur est déjà pris",
    ErrorCodes.duplicateCode: "Ce code d'invitation existe déjà",
    ErrorCodes.codeGenerationFailed:
        "Impossible de générer un code d'invitation. Veuillez réessayer.",
    ErrorCodes.invalidRefreshToken:
        'Session expirée. Veuillez vous reconnecter.',
    ErrorCodes.invalidCredentials:
        'Identifiants incorrects. Veuillez réessayer.',
    ErrorCodes.unauthorized: 'Accès non autorisé',
    ErrorCodes.internalError:
        'Une erreur interne est survenue. Veuillez réessayer plus tard.',
    ErrorCodes.tentNameRequired: 'Le nom de la tente est requis',
    ErrorCodes.tentNameExists: 'Une tente avec ce nom existe déjà',
    ErrorCodes.invalidTentSize: 'La taille doit être comprise entre 1 et 100',
    ErrorCodes.invalidTentShape: 'La forme de tente sélectionnée est invalide',
    ErrorCodes.invalidTentState: "L'état de la tente est invalide",
    ErrorCodes.tentCreateFailed: 'Erreur serveur. Réessayez',
    ErrorCodes.tentNotFound: 'Tente introuvable',
  };
}
