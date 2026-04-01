import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/constants.dart';

/// Secure storage service for sensitive data
///
/// Provides a centralized interface for storing:
/// - Access tokens
/// - Refresh tokens
/// - Server URL
///
/// Uses FlutterSecureStorage for platform-specific secure storage:
/// - Android: EncryptedSharedPreferences
/// - iOS: Keychain
class SecureStorageService {
  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Save access token
  static Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: StorageKeys.accessToken, value: token);
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: StorageKeys.accessToken);
  }

  /// Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: StorageKeys.refreshToken, value: token);
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: StorageKeys.refreshToken);
  }

  /// Save access token expiration
  static Future<void> saveAccessTokenExpires(DateTime expires) async {
    await _secureStorage.write(
      key: StorageKeys.accessTokenExpires,
      value: expires.toIso8601String(),
    );
  }

  /// Get access token expiration
  static Future<DateTime?> getAccessTokenExpires() async {
    final value = await _secureStorage.read(
      key: StorageKeys.accessTokenExpires,
    );
    return value != null ? DateTime.parse(value) : null;
  }

  /// Save refresh token expiration
  static Future<void> saveRefreshTokenExpires(DateTime expires) async {
    await _secureStorage.write(
      key: StorageKeys.refreshTokenExpires,
      value: expires.toIso8601String(),
    );
  }

  /// Get refresh token expiration
  static Future<DateTime?> getRefreshTokenExpires() async {
    final value = await _secureStorage.read(
      key: StorageKeys.refreshTokenExpires,
    );
    return value != null ? DateTime.parse(value) : null;
  }

  /// Save both tokens at once
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    DateTime? accessTokenExpires,
    DateTime? refreshTokenExpires,
  }) async {
    final futures = [
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ];

    if (accessTokenExpires != null) {
      futures.add(saveAccessTokenExpires(accessTokenExpires));
    }
    if (refreshTokenExpires != null) {
      futures.add(saveRefreshTokenExpires(refreshTokenExpires));
    }

    await Future.wait(futures);
  }

  /// Save server URL
  static Future<void> saveServerUrl(String url) async {
    await _secureStorage.write(key: StorageKeys.serverUrl, value: url);
  }

  /// Get server URL
  static Future<String?> getServerUrl() async {
    return await _secureStorage.read(key: StorageKeys.serverUrl);
  }

  /// Save remember username preference
  static Future<void> saveRememberUsernamePreference(bool value) async {
    await _secureStorage.write(
      key: StorageKeys.rememberUsername,
      value: value.toString(),
    );
  }

  /// Get remember username preference
  static Future<bool> getRememberUsernamePreference() async {
    final value = await _secureStorage.read(key: StorageKeys.rememberUsername);
    return value == 'true';
  }

  /// Save remembered username
  static Future<void> saveRememberedUsername(String username) async {
    await _secureStorage.write(
      key: StorageKeys.rememberedUsername,
      value: username,
    );
  }

  /// Get remembered username
  static Future<String?> getRememberedUsername() async {
    return await _secureStorage.read(key: StorageKeys.rememberedUsername);
  }

  /// Delete access token
  static Future<void> deleteAccessToken() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
  }

  /// Delete refresh token
  static Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: StorageKeys.refreshToken);
  }

  /// Delete access token expiration
  static Future<void> deleteAccessTokenExpires() async {
    await _secureStorage.delete(key: StorageKeys.accessTokenExpires);
  }

  /// Delete refresh token expiration
  static Future<void> deleteRefreshTokenExpires() async {
    await _secureStorage.delete(key: StorageKeys.refreshTokenExpires);
  }

  /// Delete both tokens
  static Future<void> deleteTokens() async {
    await Future.wait([
      deleteAccessToken(),
      deleteRefreshToken(),
      deleteAccessTokenExpires(),
      deleteRefreshTokenExpires(),
    ]);
  }

  /// Clear only auth tokens, preserving server URL and remembered username
  ///
  /// Used when session expires but user should see prefilled login form.
  static Future<void> clearAuthTokens() async {
    await deleteTokens();
  }

  /// Delete server URL
  static Future<void> deleteServerUrl() async {
    await _secureStorage.delete(key: StorageKeys.serverUrl);
  }

  /// Delete remember username preference
  static Future<void> deleteRememberUsernamePreference() async {
    await _secureStorage.delete(key: StorageKeys.rememberUsername);
  }

  /// Delete remembered username
  static Future<void> deleteRememberedUsername() async {
    await _secureStorage.delete(key: StorageKeys.rememberedUsername);
  }

  /// Clear all stored data (logout)
  static Future<void> clearAll() async {
    await Future.wait([
      deleteTokens(),
      deleteServerUrl(),
      deleteRememberUsernamePreference(),
      deleteRememberedUsername(),
    ]);
  }
}
