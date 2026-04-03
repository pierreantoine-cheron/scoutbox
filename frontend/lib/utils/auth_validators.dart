import '../utils/constants.dart';

/// Shared validators for authentication forms
///
/// All validators return null for valid input,
/// or an error message string in French for invalid input.
class AuthValidators {
  AuthValidators._();

  /// Validates server URL format
  ///
  /// - Must not be empty or null
  /// - Must start with http:// or https://
  static String? validateServerUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "L'URL du serveur est requise";
    }
    final trimmed = value.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return "L'URL doit commencer par http:// ou https://";
    }
    return null;
  }

  /// Validates username
  ///
  /// - Must not be empty or null
  /// - Must be at least [ValidationConstants.usernameMinLength] characters
  /// - Must not exceed [ValidationConstants.usernameMaxLength] characters
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Le nom d'utilisateur est requis";
    }
    final trimmed = value.trim();
    if (trimmed.length < ValidationConstants.usernameMinLength) {
      return "Le nom d'utilisateur doit contenir au moins ${ValidationConstants.usernameMinLength} caractères";
    }
    if (trimmed.length > ValidationConstants.usernameMaxLength) {
      return "Le nom d'utilisateur ne peut pas dépasser ${ValidationConstants.usernameMaxLength} caractères";
    }
    return null;
  }

  /// Validates invite code
  ///
  /// - Must not be empty or null
  static String? validateInviteCode(String? value) {
    if (value == null || value.isEmpty) {
      return "Le code d'invitation est requis";
    }
    return null;
  }

  /// Validates password
  ///
  /// - Must not be empty or null
  /// - Must be at least [ValidationConstants.passwordMinLength] characters
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < ValidationConstants.passwordMinLength) {
      return 'Le mot de passe doit contenir au moins ${ValidationConstants.passwordMinLength} caractères';
    }
    return null;
  }

  /// Validates password confirmation
  ///
  /// - Must not be empty or null
  /// - Must match the original password
  static String? validatePasswordMatch(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }
    if (value != password) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }
}
