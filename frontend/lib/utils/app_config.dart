/// Compile-time configuration for the ScoutBox application.
///
/// These settings are determined at build time using --dart-define flags.
/// Defaults are production-safe so missing flags result in release behavior.
///
/// Usage:
/// ```bash
/// # Beta build (detailed errors and logging enabled)
/// flutter run --dart-define=SCOUTBOX_CHANNEL=beta
///
/// # Release build (safe defaults)
/// flutter build apk
/// flutter build apk --dart-define=SCOUTBOX_CHANNEL=release
/// ```
class AppConfig {
  const AppConfig._();

  /// Build channel: 'beta' or 'release'
  static const String channel = String.fromEnvironment(
    'SCOUTBOX_CHANNEL',
    defaultValue: 'release',
  );

  /// True when running in beta channel
  static bool get isBetaChannel => channel == 'beta';

  /// True when running in release channel
  static bool get isReleaseChannel => channel == 'release';

  /// Whether to show detailed backend error messages for unknown codes.
  ///
  /// - Beta/debug: true (show backend message for diagnostics)
  /// - Release: false (use generic French fallback for safety)
  static bool get showUnknownBackendDetails => isBetaChannel;

  /// Whether to enable HTTP request/response logging.
  ///
  /// - Beta/debug: true (verbose logging for development)
  /// - Release: false (no sensitive data logging)
  static bool get enableHttpLogging => isBetaChannel;
}
