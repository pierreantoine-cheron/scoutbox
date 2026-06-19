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
- If uncertain, ask user for clarification

### Flutter/Dart

**Colors and Theme:**
- Do not use direct Flutter `Colors.*` values in widgets or screens
- Use `Theme.of(context).colorScheme` for Material roles such as `primary`, `surface`, `error`, `outline`, and container/on-container pairs
- Use `frontend/lib/utils/app_colors.dart` for ScoutBox-specific semantic colors through `AppSemanticColors`
- Add new app palette values to `AppColors`, expose semantic widget colors through `AppSemanticColors`, and register them in `AppTheme`
- Keep `ColorScheme.fromSeed` seeded from `AppColors.scoutGreen`; do not hardcode seed colors in `ThemeData`

```dart
final colorScheme = Theme.of(context).colorScheme;
final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;

Container(
  color: semanticColors.warningContainer,
  child: Text(
    'À réparer',
    style: TextStyle(color: semanticColors.onWarningContainer),
  ),
);
```

**State Management (Riverpod):**
```dart
@riverpod
class MyNotifier extends _$MyNotifier {
  @override
  MyState build() => const MyState();
  
  Future<void> doSomething() async {
    state = state.copyWith(isLoading: true);
    // ... logic
    state = state.copyWith(isLoading: false);
  }
}
```

### .NET/C# Backend

**Error Handling:**
- Prefer global exception handling with `ApiExceptionFilter` instead of repetitive controller try/catch
- Keep controller try/catch only for local recovery or custom branching that should not be global
- Log known exceptions with `Warning` and unknown exceptions with `Error`
- Return standardized `ErrorResponse(string Error, string Code)` payloads with stable error codes

**Global Exception Filter (`ApiExceptionFilter`):**
- Location: `backend/ScoutBoxApi/Filters/ApiExceptionFilter.cs`
- Registration: `backend/ScoutBoxApi/Program.cs` via `AddControllers(options => options.Filters.Add<ApiExceptionFilter>())`
- Exception mappings:
  - `UnauthorizedAccessException` -> `401` with `AUTH_INVALID_TOKEN`
  - `DbUpdateConcurrencyException` -> `409` with `CONCURRENCY_CONFLICT`
  - Any other `Exception` -> `500` with `INTERNAL_ERROR`

**API Response Pattern:**
```csharp
[HttpPost("endpoint")]
public async Task<IActionResult> Endpoint([FromBody] Request request)
{
    // Validate and process
    // Throw specific exceptions when needed, ApiExceptionFilter maps them to ErrorResponse
    return Ok(new Response { ... });
}
```

**DTOs (Data Transfer Objects):**
Prefer C# records for DTOs - immutable, concise, value-based equality:
```csharp
// CORRECT: Use records for DTOs
public record TentDto(Guid Id, string Name, string Identifier, TentState State);
public record CreateTentRequest(string Name, string Identifier, Guid TentShapeId);
public record AuthResponse(string AccessToken, string RefreshToken, DateTime ExpiresAt);

// WRONG: Don't use classes for simple DTOs
public class TentDto { public Guid Id { get; set; } ... }  // Use record instead

// EXCEPTION: Use class when validation attributes are required
public class UploadRequest
{
    [Required][StringLength(100)] public string FileName { get; set; }
    [Range(1, 10485760)] public long FileSize { get; set; }
}
```

## Architecture Patterns

### Frontend
- **State Management**: Riverpod with code generation
- **Dependency Injection**: Riverpod providers
- **Navigation**: MaterialApp with Navigator
- **Data Layer**: Services (API clients) → Repositories

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

## Refactoring Rules

Project-specific refactoring rules (deduplication patterns, test gotchas, widget conventions) are in the `scoutbox-refactoring-rules` skill. Load it when making structural changes.
