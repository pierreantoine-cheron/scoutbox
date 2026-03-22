# ScoutBox

Mobile application for managing scout group tent inventory with real-time collaboration features.

## Description

ScoutBox is a comprehensive tent inventory management system designed for scout groups. It enables leaders to track tents, manage parts, document conditions with photos, and collaborate in real-time across multiple devices.

## Tech Stack

- **Frontend**: Flutter/Dart (cross-platform iOS/Android)
  - State Management: Riverpod with code generation
  - HTTP Client: Dio
  - Secure Storage: flutter_secure_storage
  - Deep Links: app_links
  - Localization: flutter_localizations + intl

- **Backend**: .NET 8.0 Web API
  - ORM: Entity Framework Core 8.0 with SQLite
  - Authentication: JWT tokens
  - API Documentation: Swagger/OpenAPI
  - Pattern: Repository + Service layer architecture

- **Database**: SQLite (lightweight, serverless)

## Development Setup

### Prerequisites

- Flutter SDK v3.x+ (with Dart)
- .NET SDK v8.0+
- Android Studio / Xcode (for mobile development)
- Git

### Backend Startup

```bash
cd backend
dotnet restore
dotnet run
```

API will be available at `http://localhost:5000`

Swagger UI available at `http://localhost:5000/swagger`

### Frontend Startup

```bash
cd frontend
flutter pub get
flutter run
```

## Architecture

See [architecture documentation](docs/architecture.md) for detailed system design, patterns, and conventions.

## Project Structure

```
scoutbox/
├── backend/               # .NET Web API
│   ├── ScoutBoxApi.slnx  # Solution file
│   └── ScoutBoxApi/      # Project folder
│       ├── Controllers/
│       ├── Models/
│       ├── Services/
│       ├── Data/
│       └── Middleware/
├── frontend/              # Flutter application
│   ├── lib/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── views/
│   │   ├── services/
│   │   ├── repositories/
│   │   └── utils/
│   └── test/
├── docs/                 # Documentation
└── infrastructure/       # Deployment configs
```

## Naming Conventions

**Flutter/Dart:**
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`

**C#/.NET:**
- Files: `PascalCase.cs`
- Classes: `PascalCase`
- Variables: `camelCase`
- Properties: `PascalCase`

## Code Generation

**Riverpod (Frontend):**
```bash
cd frontend
flutter pub run build_runner build

# Or watch mode for development
flutter pub run build_runner watch
```

## Features

- User registration with invite codes
- Tent inventory management
- Part tracking and management
- Photo documentation
- Tag system for organization
- Real-time collaboration via SSE
- French localization
- Offline support

---

*ScoutBox - Tent inventory management for scout groups*
