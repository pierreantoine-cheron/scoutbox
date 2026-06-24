import '../models/auth_response.dart';
import '../utils/constants.dart';
import '../services/api_client.dart';

class AuthRepository {
  const AuthRepository();

  Future<AuthResponse> register({
    required String serverUrl,
    required String inviteCode,
    required String username,
    required String password,
  }) async {
    ApiClient.initialize(serverUrl);

    final response = await ApiClient.instance.post(
      ApiRoutes.register,
      data: {
        'inviteCode': inviteCode,
        'username': username,
        'password': password,
      },
    );

    return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AuthResponse> login({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    ApiClient.initialize(serverUrl);

    final response = await ApiClient.instance.post(
      ApiRoutes.login,
      data: {'username': username, 'password': password},
    );

    return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AuthResponse> refreshToken(String refreshToken) async {
    final response = await ApiClient.instance.post(
      ApiRoutes.refresh,
      data: {'refreshToken': refreshToken},
    );

    return AuthResponse.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await ApiClient.instance.post(
      ApiRoutes.logout,
      data: {'refreshToken': refreshToken},
    );
  }
}
