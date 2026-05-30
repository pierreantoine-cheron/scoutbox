import 'constants.dart';

class TentValidators {
  TentValidators._();

  static String? validateName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'Le nom de la tente est requis';
    }

    if (trimmed.length > ValidationConstants.tentNameMaxLength) {
      return 'Le nom ne doit pas dépasser ${ValidationConstants.tentNameMaxLength} caractères';
    }

    return null;
  }

  static String? validateSize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return 'La taille doit être un nombre positif';
    }

    final parsedSize = int.tryParse(trimmed);
    if (parsedSize == null ||
        parsedSize < ValidationConstants.tentMinSize ||
        parsedSize > ValidationConstants.tentMaxSize) {
      return 'La taille doit être un nombre positif';
    }

    return null;
  }

  static String? validateComments(String? value) {
    if (value == null) {
      return null;
    }

    if (value.length > ValidationConstants.tentCommentsMaxLength) {
      return 'Le commentaire ne doit pas dépasser ${ValidationConstants.tentCommentsMaxLength} caractères';
    }

    return null;
  }
}
