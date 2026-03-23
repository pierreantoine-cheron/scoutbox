import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _serverUrlKey = 'server_url';

  Future<bool> validateServer(String serverUrl) async {
    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: serverUrl,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final response = await dio.get('/api/health');
      return response.statusCode == 200;
    } on DioException catch (e) {
      // Server might not have health endpoint, try root
      if (e.response == null) {
        try {
          final dio = Dio(
            BaseOptions(
              baseUrl: serverUrl,
              connectTimeout: const Duration(seconds: 5),
            ),
          );
          final response = await dio.get('/');
          return response.statusCode != null;
        } catch (_) {
          return false;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<AuthResult> register({
    required String serverUrl,
    required String inviteCode,
    required String username,
    required String password,
  }) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: serverUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    try {
      final response = await dio.post(
        '/api/auth/register',
        data: {
          'inviteCode': inviteCode,
          'username': username,
          'password': password,
          'serverUrl': serverUrl,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AuthResult.success(
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
          accessTokenExpires: DateTime.parse(
            data['accessTokenExpires'] as String,
          ),
          refreshTokenExpires: DateTime.parse(
            data['refreshTokenExpires'] as String,
          ),
        );
      } else {
        return AuthResult.failure('Erreur inattendue: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.data != null) {
        final data = e.response!.data as Map<String, dynamic>;
        final errorMessage = data['error'] as String? ?? 'Erreur inconnue';
        return AuthResult.failure(errorMessage);
      }
      return AuthResult.failure('Erreur de connexion au serveur');
    } catch (e) {
      return AuthResult.failure('Erreur inattendue: $e');
    }
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  Future<void> saveServerUrl(String serverUrl) async {
    await _secureStorage.write(key: _serverUrlKey, value: serverUrl);
  }

  Future<String?> getServerUrl() async {
    return await _secureStorage.read(key: _serverUrlKey);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<void> logout() async {
    await clearTokens();
    await _secureStorage.delete(key: _serverUrlKey);
  }
}

class AuthResult {
  final bool success;
  final String? error;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? accessTokenExpires;
  final DateTime? refreshTokenExpires;

  AuthResult._({
    required this.success,
    this.error,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpires,
    this.refreshTokenExpires,
  });

  factory AuthResult.success({
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpires,
    required DateTime refreshTokenExpires,
  }) {
    return AuthResult._(
      success: true,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpires: accessTokenExpires,
      refreshTokenExpires: refreshTokenExpires,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(success: false, error: error);
  }
}
