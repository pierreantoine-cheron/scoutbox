// API Routes and validation constants
class ApiRoutes {
  // Base paths
  static const String health = '/api/health';
  static const String authBase = '/api/auth';
  static const String tents = '/api/tents';
  static const String tentShapes = '/api/tent-shapes';

  // Auth endpoints
  static const String register = '$authBase/register';
  static const String login = '$authBase/login';
  static const String refresh = '$authBase/refresh';
  static const String invites = '$authBase/invites';
  static const String logout = '$authBase/logout';
}

// Storage keys
class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String serverUrl = 'server_url';
  static const String rememberUsername = 'remember_username';
  static const String rememberedUsername = 'remembered_username';
  static const String accessTokenExpires = 'access_token_expires';
  static const String refreshTokenExpires = 'refresh_token_expires';
}

// Validation constants matching backend constraints
class ValidationConstants {
  static const int usernameMinLength = 3;
  static const int usernameMaxLength = 50;
  static const int passwordMinLength = 8;
  static const int inviteCodeMaxLength = 64;
  static const int tentNameMaxLength = 100;
  static const int tentCommentsMaxLength = 500;
  static const int tentMinSize = 1;
  static const int tentMaxSize = 100;
}

// Error codes returned by backend
class ErrorCodes {
  static const String invalidInvite = 'INVALID_INVITE';
  static const String usernameExists = 'USERNAME_EXISTS';
  static const String duplicateCode = 'DUPLICATE_CODE';
  static const String codeGenerationFailed = 'CODE_GENERATION_FAILED';
  static const String invalidRefreshToken = 'INVALID_REFRESH_TOKEN';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String unauthorized = 'UNAUTHORIZED';
  static const String internalError = 'INTERNAL_ERROR';
  static const String tentNameRequired = 'TENT_NAME_REQUIRED';
  static const String tentNameExists = 'TENT_NAME_EXISTS';
  static const String invalidTentSize = 'INVALID_TENT_SIZE';
  static const String invalidTentShape = 'INVALID_TENT_SHAPE';
  static const String invalidTentState = 'INVALID_TENT_STATE';
  static const String tentCreateFailed = 'TENT_CREATE_FAILED';
  static const String tentNotFound = 'TENT_NOT_FOUND';
}

// API timeouts
class ApiTimeouts {
  static const Duration healthCheck = Duration(seconds: 5);
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration longTimeout = Duration(seconds: 30);
}
