# AGENTS.md - ScoutBox Project Guide

## Rules

When developing, reviewing, if a change is worthy to be added as a rule to the project, offer to the user adding it to this file.

## Project Overview

ScoutBox is a scout group tent inventory management system with a Flutter/Dart frontend and .NET backend.
It is not an enterprise product, and it doesn't host sensitive data, so it shouldn't have superfluous security features.

## Build/Lint/Test Commands

### Frontend (Flutter/Dart)

```bash
cd frontend

# Install dependencies
flutter pub get

# Generate Riverpod code (required after provider changes)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch --delete-conflicting-outputs

# Analyze code
dart analyze
# or: flutter analyze

# Format code
dart format .

# Run all tests
flutter test

# Run a single test file
flutter test test/services/deep_link_service_test.dart

# Run a specific test by name
flutter test --name "parseInviteLink"

# Run app (debug)
flutter run

# Run app on specific device
flutter run -d <device_id>
flutter devices  # List available devices
```

### Backend (.NET)

```bash
cd backend/ScoutBoxApi

# Restore dependencies
dotnet restore

# Build
dotnet build

# Run (development with hot reload)
dotnet run

# Run all tests (from backend/ScoutBoxApi.Tests)
cd backend/ScoutBoxApi.Tests
dotnet test

# Run a single test class
dotnet test --filter "FullyQualifiedName~AuthControllerTests"

# Run a single test method
dotnet test --filter "FullyQualifiedName~AuthControllerTests.Register_WithValidInvite_ReturnsOkResult"

# Format code (requires .NET SDK)
dotnet format
```

## Project Structure

```
scoutbox/
├── frontend/                    # Flutter application
│   ├── Dockerfile               # Multi-stage (web/apk targets)
│   ├── nginx/
│   │   ├── web.conf             # SPA fallback for Flutter web
│   │   └── apk.conf             # Serves APK + manifest.json
│   ├── tool/
│   │   ├── compute-version.sh   # Git-based version derivation
│   │   └── build-apk-manifest.sh # Emits manifest.json + copies APK
│   ├── lib/
│   │   ├── main.dart           # App entry point
│   │   ├── models/             # Data models
│   │   ├── providers/          # Riverpod state providers
│   │   ├── services/           # API clients, storage, business logic
│   │   ├── repositories/       # Data access layer
│   │   ├── views/
│   │   │   ├── screens/        # Full-screen widgets
│   │   │   └── widgets/        # Reusable UI components
│   │   └── utils/              # Helpers, constants
│   └── test/                   # Tests mirror lib structure
├── site/                        # Astro marketing/landing site (static SSG)
│   ├── Dockerfile
│   ├── src/
│   │   ├── layouts/BaseLayout.astro
│   │   ├── components/DownloadCard.astro
│   │   └── pages/
│   │       ├── index.astro      # Landing page
│   │       └── register.astro   # Invite registration helper
│   └── public/brand/logo.svg
├── backend/
│   ├── ScoutBoxApi/            # .NET Web API
│   │   ├── Controllers/        # API endpoints
│   │   ├── Filters/            # Global API exception filters
│   │   ├── Models/
│   │   │   ├── DTOs/           # Data transfer objects
│   │   │   └── Entities/       # Database entities
│   │   ├── Data/               # DbContext, migrations
│   │   └── Program.cs          # App entry
│   └── ScoutBoxApi.Tests/      # xUnit tests
└── docs/                       # Architecture documentation
```

## Code Style Guidelines

- Write user-facing error messages in french
- Write internal/API error messages in english
- Use literal French characters (é, è, ê, à, etc.) in Dart strings — never `\u00e9` escape sequences
- If uncertain, ask user for clarification

## Architecture Patterns

### Frontend
- **State Management**: Riverpod with code generation
- **Dependency Injection**: Riverpod providers
- **Navigation**: MaterialApp with Navigator
- **Data Layer**: Services (API clients) -> Repositories

### Backend
- **Pattern**: Repository + Service layer
- **ORM**: Entity Framework Core with SQLite
- **Auth**: JWT Bearer tokens with refresh tokens
- **Rate Limiting**: Fixed window for auth endpoints

## Key Files to Modify

- Adding new API endpoint: `backend/ScoutBoxApi/Controllers/`
- API exception mapping policy: `backend/ScoutBoxApi/Filters/ApiExceptionFilter.cs`
- Global API filter registration: `backend/ScoutBoxApi/Program.cs`
- New data model: `backend/ScoutBoxApi/Models/Entities/`
- New DTO: `backend/ScoutBoxApi/Models/DTOs/`
- New Flutter screen: `frontend/lib/views/screens/`
- New provider: `frontend/lib/providers/` (run build_runner after)
- New reusable widget: `frontend/lib/views/widgets/`
- New service: `frontend/lib/services/`

## Environment Setup

**Frontend:** Copy `.env.example` to `.env` (not tracked)
**Backend:** Set `appsettings.Local.json` or environment variables for:
- `Jwt:Key` (32+ characters)
- `Jwt:Issuer`
- `Jwt:Audience`
- `ConnectionStrings:DefaultConnection`

## Documents edit

When changing a decision from _bmad-output files, replace the old decision with the new, no need to justify or mark as new, do not add history to file, I handle the versionning myself through git.
Use windows-style line endings.

## Frontend Docker & Site

### Coolify Services

| Env | Service | Domain | Dockerfile | Target | Build args |
|---|---|---|---|---|---|
| prod | web | `web.scoutbox.app` | `frontend/Dockerfile` | `--target=web` | (none) |
| prod | apk | `download.scoutbox.app` | `frontend/Dockerfile` | `--target=apk` | `APP_FLAVOR=production` |
| prod | site | `www.scoutbox.app` | `site/Dockerfile` | (single stage) | `PUBLIC_APK_MANIFEST_URL=https://download.scoutbox.app/manifest.json`, `PUBLIC_WEB_APP_URL=https://web.scoutbox.app` |
| staging | web | `web.staging.scoutbox.app` | `frontend/Dockerfile` | `--target=web` | (none) |
| staging | apk | `download.staging.scoutbox.app` | `frontend/Dockerfile` | `--target=apk` | `APP_FLAVOR=staging` |

### Build conventions

- **`APP_FLAVOR` build arg**: used only for the apk target. Values: `production` or `staging`. The web target takes no flavor arg (web builds are environment-agnostic).
- **Versioning**: `versionName` is derived from the latest git tag (`git describe --tags --abbrev=0`). `versionCode` is the commit count (`git rev-list --count HEAD`). The versioning logic lives in `tool/compute-version.sh`.
- **Manifest**: `tool/build-apk-manifest.sh` emits `manifest.json` with version, size, minSdk, and commit hash. It also copies the APK into the nginx runtime image.
- **Full clone required**: Coolify must perform a full git clone for versioning to work. If shallow clones are unavoidable, set `OVERRIDE_VERSION_NAME` and `OVERRIDE_VERSION_CODE` build args to bypass git-based versioning.
- **nginx configs**: `frontend/nginx/web.conf` (SPA fallback), `frontend/nginx/apk.conf` (serves APK + `manifest.json`), `site/nginx/default.conf` (SPA fallback for Astro site).

### No Dart-side environment branching

`SCOUTBOX_CHANNEL` is gone. Staging and prod are identical Dart builds; they differ only in Android packaging identity (`applicationIdSuffix`) and version strings injected via `--build-name`/`--build-number`. Diagnostics gate on `kDebugMode`, not on a build-time channel dart-define.

### Rule: Single `APP_FLAVOR` + `kDebugMode`-only diagnostics

Staging and prod share the same Dart code. The only packaging difference is `applicationIdSuffix=".staging"` in `build.gradle.kts`. Version strings are injected at build time via `--build-name`/`--build-number`. No `--dart-define` flags touch Dart code. Debug/verbose behavior uses `kDebugMode` only.

## Skills

For detailed conventions, load the appropriate skill:

| Skill | When to use |
|-------|-------------|
| `backend-development` | Writing or modifying backend code (controllers, services, repositories, entities, DTOs, filters) |
| `frontend-development` | Writing or modifying frontend code (screens, widgets, providers, models, services, repositories) |
| `scoutbox-refactoring-rules` | Refactoring, fixing test gotchas, deduplicating code, avoiding common pitfalls |
