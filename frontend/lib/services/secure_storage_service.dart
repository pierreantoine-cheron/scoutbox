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

  /// Save both tokens at once
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
    ]);
  }

  /// Save server URL
  static Future<void> saveServerUrl(String url) async {
    await _secureStorage.write(key: StorageKeys.serverUrl, value: url);
  }

  /// Get server URL
  static Future<String?> getServerUrl() async {
    return await _secureStorage.read(key: StorageKeys.serverUrl);
  }

  /// Delete access token
  static Future<void> deleteAccessToken() async {
    await _secureStorage.delete(key: StorageKeys.accessToken);
  }

  /// Delete refresh token
  static Future<void> deleteRefreshToken() async {
    await _secureStorage.delete(key: StorageKeys.refreshToken);
  }

  /// Delete both tokens
  static Future<void> deleteTokens() async {
    await Future.wait([deleteAccessToken(), deleteRefreshToken()]);
  }

  /// Delete server URL
  static Future<void> deleteServerUrl() async {
    await _secureStorage.delete(key: StorageKeys.serverUrl);
  }

  /// Clear all stored data (logout)
  static Future<void> clearAll() async {
    await Future.wait([deleteTokens(), deleteServerUrl()]);
  }
}
