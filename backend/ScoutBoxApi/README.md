# ScoutBoxApi

## JWT configuration (required)

`Jwt:Key` is required to start the API. The app will fail at startup if:

- `Jwt:Key` is missing
- `Jwt:Key` is the placeholder value `__SET_JWT_KEY_IN_ENV__`
- `Jwt:Key` is shorter than 32 characters

The key is intentionally not stored in source control. Set it through environment variables or local secrets.

## Option 1: Environment variable

Set `Jwt__Key` before starting the API.

Linux/macOS:

```bash
export Jwt__Key="replace-with-a-random-secret-at-least-32-characters"
dotnet run
```

PowerShell:

```powershell
$env:Jwt__Key = "replace-with-a-random-secret-at-least-32-characters"
dotnet run
```

## Option 2: .NET user secrets (local development)

From `backend/ScoutBoxApi`:

```bash
dotnet user-secrets init
dotnet user-secrets set "Jwt:Key" "replace-with-a-random-secret-at-least-32-characters"
dotnet run
```

## Notes

- Keep this key private and never commit it.
- For production, prefer a secret manager (platform secrets, vault, etc.).
- If you rotate the key, previously issued access tokens become invalid.

## Staging deployment

The shared staging environment is exposed at `https://staging-api.scoutbox.app`.

Production-oriented defaults live in `appsettings.Production.json`:

- SQLite database path: `/app/data/scoutbox.db`
- uploads path: `/app/uploads`

At deployment time, set the matching environment variables so the container uses persistent storage instead of ephemeral storage.

In particular, set `Server__Url` from the deployment environment because the public server URL depends on where the application is installed.

See `docs/deployment/staging.md` for the full staging deployment checklist.
