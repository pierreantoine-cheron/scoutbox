class AuthState {
  static const Object _unset = Object();

  final bool isLoading;
  final bool isAuthenticated;
  final String? error;
  final String? accessToken;
  final String? errorCode;

  /// True if the user was previously authenticated but the session expired
  final bool isSessionExpired;

  /// True if the refresh token exists and can be used to get new access token
  final bool canRefreshToken;

  /// True when unauthenticated users should land on login screen
  final bool showLoginScreen;

  /// One-time success message to show after logout (not persisted)
  final String? logoutSuccessMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
    this.accessToken,
    this.errorCode,
    this.isSessionExpired = false,
    this.canRefreshToken = false,
    this.showLoginScreen = false,
    this.logoutSuccessMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
    String? accessToken,
    String? errorCode,
    bool? isSessionExpired,
    bool? canRefreshToken,
    bool? showLoginScreen,
    Object? logoutSuccessMessage = _unset,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
      accessToken: accessToken ?? this.accessToken,
      errorCode: errorCode,
      isSessionExpired: isSessionExpired ?? this.isSessionExpired,
      canRefreshToken: canRefreshToken ?? this.canRefreshToken,
      showLoginScreen: showLoginScreen ?? this.showLoginScreen,
      logoutSuccessMessage: identical(logoutSuccessMessage, _unset)
          ? this.logoutSuccessMessage
          : logoutSuccessMessage as String?,
    );
  }
}
