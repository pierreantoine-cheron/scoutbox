# AGENTS.md - ScoutBox Project Guide

## Project Overview

ScoutBox is a scout group tent inventory management system with a Flutter/Dart frontend and .NET backend.
It is not an enterprise product, and it doesn't host sensitive data, so it should't have superfluous security features

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
- if uncertain, ask user for clarification


### Flutter/Dart

**Imports Order:**
1. Dart SDK imports
2. Flutter SDK imports
3. Third-party packages (alphabetical)
4. Project-relative imports

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user.dart';
import '../providers/auth_provider.dart';
```

**Naming Conventions:**
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE` for private static
- Private members: prefix with `_`

**Formatting:**
- Use `dart format .` before commits
- Single quotes for strings (enforced by linter)
- Prefer const constructors when possible
- Final locals by default (enforced by linter)
- use commas to help format Widgets and functions

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

**Error Handling:**
- Use try/catch with specific exception types
- Return result objects for async operations that can fail
- Display user-friendly error messages

**Testing:**
- Unit tests: `test/services/`, `test/models/`
- Widget tests: `test/views/`, `test/widgets/`
- Use `group()` and descriptive `test()` names
- Follow AAA pattern: Arrange, Act, Assert

### .NET/C# Backend

**Naming Conventions:**
- Files: `PascalCase.cs` matching class name
- Classes: `PascalCase`
- Properties: `PascalCase`
- Methods: `PascalCase`
- Local variables: `camelCase`
- Private fields: `_camelCase` with underscore prefix

**File Organization:**
```
using System.Collections;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Models;

namespace ScoutBoxApi.Controllers;

public class MyController : ControllerBase
{
    private readonly IService _service;
    private readonly ILogger<MyController> _logger;
    
    // Constructor
    public MyController(IService service, ILogger<MyController> logger)
    {
        _service = service;
        _logger = logger;
    }
}
```

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

**Testing:**
- Use xUnit with `[Fact]` attribute
- Test file naming: `{Class}Tests.cs`
- In-memory database for unit tests
- Follow AAA pattern: Arrange, Act, Assert
- Use `Assert.IsType<T>()` and `Assert.Equal()`

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

## Refactoring Rules (learned)

### Backend (C#)

**Extract shared helpers when duplicated 3+ times:**
When the same private helper appears in three or more services, extract it to a static utility class in `backend/ScoutBoxApi/Services/`. Examples:
- `DbExceptionHelper.cs` — `IsConstraintViolation(DbUpdateException, params string[])` / `IsAnyConstraintViolation(...)`
- `EntityFactory.cs` — `SetCreationAudit<T>(entity, userId)` for common audit field initialization

**DTO static factories over duplicated mappings:**
When the same DTO mapping (`new PartDto(...)`) appears in multiple services, add a static factory method to the DTO record itself (e.g., `PartDto.FromPart(Part)`). This keeps the mapping next to the type it creates.

**Entity interfaces for shared field sets:**
When multiple entities share the same set of fields, extract an interface (e.g., `IAuditableEntity` for `Id`, `CreatedAt`, `UpdatedAt`, `CreatedByUserId`, `UpdatedByUserId`). Use it with a generic static helper.

### Frontend (Dart)

**Mixins for screen lifecycle boilerplate:**
When multiple screens share the same `RouteAware` + `AppBarConfig` lifecycle, extract to a mixin with `on ConsumerState<T>, RouteAware` constraint. Cast `this as RouteAware` when passing to `RouteObserver` methods. Each screen implements `AppBarConfig buildAppBarConfig()`.

**Shared dialog function over copy-pasted AlertDialogs:**
Extract repeated confirmation dialogs to a single top-level function with `title`, `content`, `confirmLabel`, `cancelLabel`, `isDestructive`, and `barrierDismissible` parameters. Return `Future<bool>`.

**Merge near-duplicate screens with mode parameter:**
When two screens share ~70% code, merge into one widget with an enum `mode` parameter. Keep thin `StatelessWidget` wrapper classes for backward compatibility with widget tests that use `find.byType()`.

**Error handling consistency across providers:**
Always use `ErrorLocalizer.localize(e.code, fallback: e.message)` when catching `TentRepositoryException`. Never use raw `e.message` directly:
- Known error codes → mapped French message
- Unknown codes in dev builds → raw backend message preserved
- Unknown codes in production → safe generic fallback

**Barrel exports for new widgets:**
When adding a new file under `frontend/lib/views/widgets/`, add it to the `widgets.dart` barrel export.
