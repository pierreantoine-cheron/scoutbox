import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<SharedPreferences> _getFallbackPrefs() {
    return SharedPreferences.getInstance();
  }

  static Future<void> _writeValue(String key, String value) async {
    if (!kIsWeb) {
      await _secureStorage.write(key: key, value: value);
      return;
    }

    var secureWriteFailed = false;
    try {
      await _secureStorage.write(key: key, value: value);
    } catch (e) {
      secureWriteFailed = true;
      debugPrint('Secure web write failed for $key: $e');
    }

    try {
      final prefs = await _getFallbackPrefs();
      await prefs.setString(key, value);
    } catch (e) {
      if (secureWriteFailed) {
        rethrow;
      }
      debugPrint('Fallback web write failed for $key: $e');
    }
  }

  static Future<String?> _readValue(String key) async {
    if (!kIsWeb) {
      return await _secureStorage.read(key: key);
    }

    try {
      final secureValue = await _secureStorage.read(key: key);
      if (secureValue != null) {
        return secureValue;
      }
    } catch (e) {
      debugPrint('Secure web read failed for $key: $e');
    }

    try {
      final prefs = await _getFallbackPrefs();
      return prefs.getString(key);
    } catch (e) {
      debugPrint('Fallback web read failed for $key: $e');
      return null;
    }
  }

  static Future<void> _deleteValue(String key) async {
    if (!kIsWeb) {
      await _secureStorage.delete(key: key);
      return;
    }

    try {
      await _secureStorage.delete(key: key);
    } catch (e) {
      debugPrint('Secure web delete failed for $key: $e');
    }

    try {
      final prefs = await _getFallbackPrefs();
      await prefs.remove(key);
    } catch (e) {
      debugPrint('Fallback web delete failed for $key: $e');
    }
  }

  /// Save access token
  static Future<void> saveAccessToken(String token) async {
    await _writeValue(StorageKeys.accessToken, token);
  }

  /// Get access token
  static Future<String?> getAccessToken() async {
    return await _readValue(StorageKeys.accessToken);
  }

  /// Save refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _writeValue(StorageKeys.refreshToken, token);
  }

  /// Get refresh token
  static Future<String?> getRefreshToken() async {
    return await _readValue(StorageKeys.refreshToken);
  }

  /// Save access token expiration
  static Future<void> saveAccessTokenExpires(DateTime expires) async {
    await _writeValue(
      StorageKeys.accessTokenExpires,
      expires.toIso8601String(),
    );
  }

  /// Get access token expiration
  static Future<DateTime?> getAccessTokenExpires() async {
    final value = await _readValue(StorageKeys.accessTokenExpires);
    return value != null ? DateTime.parse(value) : null;
  }

  /// Save refresh token expiration
  static Future<void> saveRefreshTokenExpires(DateTime expires) async {
    await _writeValue(
      StorageKeys.refreshTokenExpires,
      expires.toIso8601String(),
    );
  }

  /// Get refresh token expiration
  static Future<DateTime?> getRefreshTokenExpires() async {
    final value = await _readValue(StorageKeys.refreshTokenExpires);
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
    await _writeValue(StorageKeys.serverUrl, url);
  }

  /// Get server URL
  static Future<String?> getServerUrl() async {
    return await _readValue(StorageKeys.serverUrl);
  }

  /// Save remember username preference
  static Future<void> saveRememberUsernamePreference(bool value) async {
    await _writeValue(StorageKeys.rememberUsername, value.toString());
  }

  /// Get remember username preference
  static Future<bool> getRememberUsernamePreference() async {
    final value = await _readValue(StorageKeys.rememberUsername);
    return value == 'true';
  }

  /// Save remembered username
  static Future<void> saveRememberedUsername(String username) async {
    await _writeValue(StorageKeys.rememberedUsername, username);
  }

  /// Get remembered username
  static Future<String?> getRememberedUsername() async {
    return await _readValue(StorageKeys.rememberedUsername);
  }

  /// Delete access token
  static Future<void> deleteAccessToken() async {
    await _deleteValue(StorageKeys.accessToken);
  }

  /// Delete refresh token
  static Future<void> deleteRefreshToken() async {
    await _deleteValue(StorageKeys.refreshToken);
  }

  /// Delete access token expiration
  static Future<void> deleteAccessTokenExpires() async {
    await _deleteValue(StorageKeys.accessTokenExpires);
  }

  /// Delete refresh token expiration
  static Future<void> deleteRefreshTokenExpires() async {
    await _deleteValue(StorageKeys.refreshTokenExpires);
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
    await _deleteValue(StorageKeys.serverUrl);
  }

  /// Delete remember username preference
  static Future<void> deleteRememberUsernamePreference() async {
    await _deleteValue(StorageKeys.rememberUsername);
  }

  /// Delete remembered username
  static Future<void> deleteRememberedUsername() async {
    await _deleteValue(StorageKeys.rememberedUsername);
  }

  /// Save current username (persists across sessions, not cleared on logout)
  static Future<void> saveCurrentUsername(String username) async {
    await _writeValue(StorageKeys.currentUsername, username);
  }

  /// Get current username
  static Future<String?> getCurrentUsername() async {
    return await _readValue(StorageKeys.currentUsername);
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
