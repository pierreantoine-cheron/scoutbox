# ScoutBox

Mobile application for managing scout group tent inventory.

## Project Structure

```
scoutbox/
├── backend/          # .NET Web API
├── frontend/         # Flutter application
├── docs/            # Documentation
└── infrastructure/  # Deployment configs
```

## Tech Stack

- **Frontend**: Flutter/Dart (cross-platform iOS/Android)
- **Backend**: .NET 8.0 Web API
- **Database**: SQLite
- **Authentication**: JWT tokens

## Development Setup

### Prerequisites

- Flutter SDK v3.x+
- .NET SDK v10.0+
- Android Studio / Xcode (for mobile development)

### Backend Startup

```bash
cd backend
dotnet run
```

API will be available at `http://localhost:5000`

### Frontend Startup

```bash
cd frontend
flutter pub get
flutter run
```

## Architecture

See [architecture documentation](docs/architecture.md) for detailed system design.

---

*ScoutBox - Tent inventory management for scout groups*
