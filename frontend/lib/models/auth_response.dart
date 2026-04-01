/// Data model matching backend AuthResponse DTO
///
/// Backend C# definition:
/// public record AuthResponse(string AccessToken, string RefreshToken,
///   DateTime AccessTokenExpires, DateTime RefreshTokenExpires);
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpires;
  final DateTime refreshTokenExpires;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpires,
    required this.refreshTokenExpires,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      accessTokenExpires: DateTime.parse(json['accessTokenExpires'] as String),
      refreshTokenExpires: DateTime.parse(
        json['refreshTokenExpires'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpires': accessTokenExpires.toIso8601String(),
      'refreshTokenExpires': refreshTokenExpires.toIso8601String(),
    };
  }

  bool get isAccessTokenExpired => DateTime.now().isAfter(accessTokenExpires);
  bool get isRefreshTokenExpired => DateTime.now().isAfter(refreshTokenExpires);

  /// Check if access token is expired with clock skew tolerance
  ///
  /// [tolerance] - Duration to subtract from expiry to account for device clock drift
  /// Default is 30 seconds as recommended for mobile devices.
  bool isAccessTokenExpiredWithTolerance({
    Duration tolerance = const Duration(seconds: 30),
  }) {
    final effectiveExpiry = accessTokenExpires.subtract(tolerance);
    return DateTime.now().isAfter(effectiveExpiry);
  }

  /// Check if refresh token is expired with clock skew tolerance
  ///
  /// [tolerance] - Duration to subtract from expiry to account for device clock drift
  /// Default is 30 seconds as recommended for mobile devices.
  bool isRefreshTokenExpiredWithTolerance({
    Duration tolerance = const Duration(seconds: 30),
  }) {
    final effectiveExpiry = refreshTokenExpires.subtract(tolerance);
    return DateTime.now().isAfter(effectiveExpiry);
  }

  /// Check if access token expires within the specified window
  ///
  /// Returns true if token expires within [window] duration from now.
  /// Useful for proactive refresh decisions.
  bool isAccessTokenExpiringSoon({
    Duration window = const Duration(minutes: 5),
  }) {
    final refreshThreshold = accessTokenExpires.subtract(window);
    return DateTime.now().isAfter(refreshThreshold);
  }
}

/// Data model matching backend ErrorResponse DTO
///
/// Backend C# definition:
/// public record ErrorResponse(string Error, string Code);
class ErrorResponse {
  final String error;
  final String code;

  const ErrorResponse({required this.error, required this.code});

  factory ErrorResponse.fromJson(Map<String, dynamic> json) {
    return ErrorResponse(
      error: json['error'] as String,
      code: json['code'] as String,
    );
  }
}
