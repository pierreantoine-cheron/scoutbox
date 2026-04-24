# ScoutBox Frontend

A Flutter application for ScoutBox - a scout group tent inventory management system.

## Overview

ScoutBox Frontend is a cross-platform mobile application built with Flutter that allows scout leaders to manage tent inventories. The app communicates with a .NET backend API and supports features including:

- User registration with invite codes
- JWT-based authentication with token refresh
- Tent inventory management (list, add, edit tents)

## Setup

### Prerequisites

- Flutter SDK ^3.11.3
- Dart SDK ^3.11.3
- An Android/iOS emulator or physical device

### Installation

```bash
cd frontend

# Install dependencies
flutter pub get

# Generate Riverpod code (required after provider changes)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs
```

## Build Modes

The application supports two build channels with different behavior for error handling and logging:

### Beta Channel

For development and testing with verbose error details and HTTP logging enabled.

```bash
# Run in beta mode
flutter run --dart-define=SCOUTBOX_CHANNEL=beta

# Build APK in beta mode
flutter build apk --dart-define=SCOUTBOX_CHANNEL=beta
```

**Beta behavior:**
- Unknown backend errors show the original backend message for diagnostics
- HTTP request/response logging is enabled (may include sensitive data)
- Useful for debugging API issues during development

### Release Channel (Default)

For production use with safe defaults and minimal logging.

```bash
# Run in release mode (default)
flutter run

# Build APK (default)
flutter build apk

# Explicit release flag
flutter build apk --dart-define=SCOUTBOX_CHANNEL=release
```

**Release behavior:**
- Unknown backend errors show generic French fallback message
- No HTTP payload logging (security best practice)
- Optimized for end-user safety and privacy

### Local Release Command

Use the local release script to bump the app version and build a release APK:

```bash
dart run tool/release.dart patch
```

Supported bump modes:
- `patch`
- `minor`
- `major`

The version source of truth is `pubspec.yaml`. Starting from `0.1.0+1`, the script updates the version, runs `flutter build apk --release`, and copies the APK to:

```text
build/app/outputs/flutter-apk/scoutbox-<version>-<build>.apk
```

Example output:

```text
build/app/outputs/flutter-apk/scoutbox-0.1.1-2.apk
```

## Error Handling Behavior

### Known Backend Error Codes

All error codes from the backend are mapped to user-friendly French messages:

| Code | French Message |
|------|----------------|
| `INVALID_INVITE` | "Code d'invitation invalide, expiré ou déjà utilisé" |
| `USERNAME_EXISTS` | "Ce nom d'utilisateur est déjà pris" |
| `DUPLICATE_CODE` | "Ce code d'invitation existe déjà" |
| `CODE_GENERATION_FAILED` | "Impossible de générer un code d'invitation. Veuillez réessayer." |
| `INVALID_REFRESH_TOKEN` | "Session expirée. Veuillez vous reconnecter." |
| `UNAUTHORIZED` | "Accès non autorisé" |
| `INTERNAL_ERROR` | "Une erreur interne est survenue. Veuillez réessayer plus tard." |

### Unknown Error Codes

| Channel | Behavior |
|---------|----------|
| **Beta** | Shows backend-provided error message (if available) |
| **Release** | Shows generic French fallback: "Une erreur est survenue. Veuillez réessayer." |

### Network and Connection Errors

All network errors (regardless of channel) show French messages:
- Connection error: "Erreur de connexion. Veuillez vérifier votre connexion internet et réessayer."
- Server error: "Erreur serveur ({statusCode}). Veuillez réessayer."
- Unexpected error: "Une erreur inattendue est survenue. Veuillez réessayer."

## Logging Behavior

| Channel | HTTP Logging |
|---------|-------------|
| **Beta** | Enabled - logs request/response bodies (includes sensitive data) |
| **Release** | Disabled - no payload logging |

**Security Note**: Never use beta builds for production or share beta logs externally, as they may contain authentication tokens and other sensitive user data.

## Development

### Code Generation

After modifying any Riverpod providers (files with `@riverpod` annotations), regenerate code:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/views/screens/register_screen_test.dart

# Run tests matching a name pattern
flutter test --name "RegisterScreen"
```

### Code Analysis

```bash
# Analyze code for issues
dart analyze

# Format code
dart format .
```

## Architecture

### State Management

- **Riverpod** with code generation for dependency injection and state management
- Providers located in `lib/providers/`
- Service injection via `authServiceProvider` for testability

### Data Layer

- **Services** (`lib/services/`): API clients, business logic, secure storage
- **Repositories** (`lib/repositories/`): Data access abstraction (future)
- **Models** (`lib/models/`): Data classes with JSON serialization

### UI Layer

- **Screens** (`lib/views/screens/`): Full-page widgets
- **Widgets** (`lib/views/widgets/`): Reusable UI components
- Theme configuration in `lib/main.dart`

## Security

- Sensitive data (tokens, server URL) stored in platform secure storage:
  - Android: EncryptedSharedPreferences
  - iOS: Keychain
- No sensitive data in HTTP logs in release builds
- Token expiration handling with automatic refresh capability

## Environment

Copy `.env.example` to `.env` for local environment variables (not tracked in git):

```bash
cp .env.example .env
```

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   ├── providers/                # Riverpod state providers
│   ├── services/                 # API clients, storage, business logic
│   ├── views/
│   │   ├── screens/              # Full-screen widgets
│   │   └── widgets/              # Reusable UI components
│   └── utils/                    # Constants, configuration
├── test/                         # Tests mirror lib structure
├── pubspec.yaml                  # Dependencies
└── analysis_options.yaml         # Linter rules
```

## Troubleshooting

### Build failures

```bash
# Clean build artifacts
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Riverpod code generation issues

```bash
# Delete generated files and regenerate
find lib -name "*.g.dart" -delete
dart run build_runner build --delete-conflicting-outputs
```
