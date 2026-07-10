# Versioning

## Current approach (Coolify build args)

The APK build uses environment variables injected via Coolify build args:

| Build arg     | Description                  | Example value  |
|---------------|------------------------------|----------------|
| `APP_FLAVOR`   | `production` or `staging`    | `production`   |
| `VERSION_NAME` | Semantic version             | `0.1.2`        |
| `VERSION_CODE` | Integer build number         | `3`            |

`compute-version.sh` sources these and applies the `-staging` suffix to `VERSION_NAME` when `APP_FLAVOR=staging`.

To bump a version: update `VERSION_NAME` and `VERSION_CODE` in the Coolify service configuration and redeploy.

---

## Reference: git‑based versioning (for CI pipelines)

When the `.git` directory is available in the build context (e.g. full clone, no `.dockerignore` exclusion), the version can be derived automatically:

```bash
BASE_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
COMMIT_COUNT=$(git rev-list --count HEAD)
SHORT_SHA=$(git rev-parse --short HEAD)
```

- `BASE_VERSION` — latest annotated tag with `v` prefix stripped
- `COMMIT_COUNT` — total commits on the branch, used as `VERSION_CODE`
- `SHORT_SHA` — abbreviated commit hash for traceability

The full version string emitted by `flutter build apk` then becomes `--build-name=${BASE_VERSION} --build-number=${COMMIT_COUNT}`.

To use this approach in a CI pipeline:
1. Ensure the pipeline performs a full clone (not shallow)
2. Keep `.git/` out of `.dockerignore` files
3. Tag releases with `vX.Y.Z` and push tags to the remote
