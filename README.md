# ScoutBox

Application for managing scout group tent inventory.

## Description

ScoutBox helps scout leaders track tents, tent shapes, parts, condition, comments, and history. The project is intentionally kept simple enough for occasional volunteer contributors to understand and maintain.

## Tech Stack

- **Frontend**: Flutter/Dart
  - State Management: Riverpod with code generation
  - HTTP Client: Dio
  - Secure Storage: flutter_secure_storage
  - Localization: flutter_localizations + intl

- **Backend**: .NET 10 Web API
  - ORM: Entity Framework Core 10 with SQLite
  - Authentication: JWT tokens
  - API Documentation: Swagger/OpenAPI
  - Pattern: Controllers with services/repositories where useful

- **Database**: SQLite (lightweight, serverless)

## Development Setup

### Prerequisites

- Flutter SDK with Dart compatible with `frontend/pubspec.yaml`
- .NET SDK 10+
- Android Studio, Xcode, or a browser target for Flutter development
- Git

### Backend Startup

```bash
cd backend/ScoutBoxApi
dotnet restore
dotnet run
```

API will be available at `http://localhost:5169`.

With the HTTPS launch profile, it is also available at `https://localhost:7210`.

Swagger UI is available at `/swagger`, for example `http://localhost:5169/swagger`.

### Frontend Startup

```bash
cd frontend
flutter pub get
flutter run
```

## Architecture

For project structure, coding conventions, and where to add common changes, see `AGENTS.md`. Deployment notes are under `docs/deployment/`.

## Deployment

The shared staging API is exposed at `https://staging-api.scoutbox.app`.

See `docs/deployment/staging.md` for the required runtime configuration, persistent storage paths, and first-deploy checklist.

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
│       └── Filters/
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
└── AGENTS.md             # Contributor and AI-agent project guide
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

Implemented now:

- User registration with invite codes
- Tent inventory management
- Part tracking and management
- Tent shape reference data
- Tent archiving
- Tent and part history through audit events

Planned or deferred:

- Photo documentation
- Tag system for organization
- Real-time collaboration via SSE
- French localization (using real localization tech)
- Offline support

## License

ScoutBox is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). See `LICENSE` for the full text.

## Trademark

The "ScoutBox" name and logo are not licensed for use to promote or endorse modified versions of this project. AGPL-3.0 grants rights to the source code only; it does not grant trademark rights.

---

*ScoutBox - Tent inventory management for scout groups*
