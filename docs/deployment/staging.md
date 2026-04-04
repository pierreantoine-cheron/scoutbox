# Staging Deployment

This document describes the shared staging deployment contract for ScoutBox.

## Target

- Public API URL: `https://staging-api.scoutbox.app`
- Host: VPS
- Scope: single shared staging environment

## Application

- Service: `backend/ScoutBoxApi`
- Build source: GitHub repository
- Runtime: Docker image built from `backend/ScoutBoxApi/Dockerfile`
- Public health check: `GET /api/health`

## Persistent Storage

Provide persistent storage for these paths:

- `/app/data`
  Purpose: SQLite database files
- `/app/uploads`
  Purpose: uploaded photos and future file storage

The production configuration expects the SQLite database at:

```text
Data Source=/app/data/scoutbox.db
```

## Environment Variables

Set these at deployment time:

```text
ASPNETCORE_ENVIRONMENT=Production
ConnectionStrings__DefaultConnection=Data Source=/app/data/scoutbox.db
Jwt__Key=<random secret with at least 32 characters>
Jwt__Issuer=ScoutBoxApi
Jwt__Audience=ScoutBoxApp
Server__Url=https://staging-api.scoutbox.app
Storage__UploadsRoot=/app/uploads
```

`Server__Url` should stay aligned with the public staging domain so future invite links and external URLs are generated correctly.

## Configuration Split

Keep stable, non-secret runtime defaults in `backend/ScoutBoxApi/appsettings.Production.json`:

- `ConnectionStrings:DefaultConnection`
- `Storage:UploadsRoot`

Set environment-specific and secret values at deployment time:

- `Jwt__Key`
- `Jwt__Issuer`
- `Jwt__Audience`
- `Server__Url`

`Server__Url` is deployment-specific and should not be treated as a source-controlled default because it depends on the installed public domain.

## Reverse Proxy Requirements

The API is configured to trust forwarded headers from a reverse proxy. This is required when TLS is terminated before requests reach the application container.

Without forwarded headers, ASP.NET can mis-detect the original request scheme and produce incorrect HTTPS redirect behavior.

## First Deploy Checklist

1. Create an application from the GitHub repository.
2. Point it at `backend/ScoutBoxApi/Dockerfile`.
3. Attach persistent storage for `/app/data` and `/app/uploads`.
4. Set all required environment variables.
5. Deploy the application.
6. Confirm `https://staging-api.scoutbox.app/api/health` returns `200`.
7. Check container logs for startup migration output.
8. Check container logs for the seeded first invite code on an empty database.

## Operational Notes

- The API applies EF Core migrations automatically at startup.
- On first startup with an empty database, the app seeds the `ADMIN-SETUP` invite code.
- The invite code is written to application logs.
- SQLite WAL mode is enabled during startup.

## Backup Scope

Back up both of these paths:

- `/app/data`
- `/app/uploads`

For SQLite backups, include all related files if present:

- `scoutbox.db`
- `scoutbox.db-wal`
- `scoutbox.db-shm`
