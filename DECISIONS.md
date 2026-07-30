# AutoService — Architecture Decisions & Notes

This file records the key technical decisions made during development and
bring-up so future contributors (or Claude sessions) can understand *why*
things are the way they are.

---

## Database

### Multi-tenancy via Row-Level Security (RLS)
Every table that holds shop-specific data carries a `shop_id` UUID column.
PostgreSQL RLS policies enforce that a connection can only see rows where
`shop_id` matches the session-local variable `app.current_shop_id`.

The variable is set in the `tenantScope` Express middleware:
```sql
SET LOCAL app.current_shop_id = '<uuid>';
```
`SET LOCAL` applies only for the current transaction, so it is reset
automatically at `COMMIT` / `ROLLBACK`.

**Important:** PostgreSQL's `SET` / `SET LOCAL` command is a *configuration
directive*, not a DML statement. It does **not** support parameterised
placeholders (`$1`). The UUID must be inlined into the SQL string. This is
safe because the value always originates from our own signed JWT.

### UUID primary keys
All tables use `gen_random_uuid()` as their default PK. This avoids
enumerable integer IDs in API URLs and is safe under multi-tenant inserts.

### Work-order numbering
`order_no` is a global `SERIAL`. Per-shop sequential numbering (e.g. #1, #2
per shop) was deferred; it would require a `shop_counters` table and an
advisory lock or `FOR UPDATE` to avoid race conditions at scale.

---

## Backend

### Environment & DB connection
All config is read through `src/config/env.ts` (Zod schema). The app will
refuse to start (`process.exit(1)`) if any required variable is missing or
invalid.

The database is connected via a single `DATABASE_URL` connection string.

**Gotcha:** Avoid special characters in `DB_PASSWORD` that are reserved in
URLs — particularly `#` (fragment delimiter), `@`, `/`, `?`, and `&`.
These must be percent-encoded (`%23`, etc.) if used, or avoided entirely in
dev. Recommended dev approach: use alphanumeric passwords for local `.env`.

### CORS
`CORS_ORIGIN` in `.env` is passed directly to the `cors` package as the
single allowed origin. For LAN access over plain HTTP, the Flutter web client
now uses the nginx reverse proxy (same-origin requests) so the CORS header is
irrelevant for the browser. However, `CORS_ORIGIN` must still be set correctly
for any direct API client (e.g. Postman, mobile apps hitting the API directly).

### JWT
Tokens are signed with HS256 and expire in 8 hours (`JWT_EXPIRES_IN`).
Logout is best-effort (stateless JWT — no server-side token revocation).

---

## Frontend

### API base URL — web vs. native
```dart
String get apiBaseUrl {
  if (kIsWeb) {
    return '${Uri.base.origin}/api/v1';  // same-origin → nginx proxy
  }
  return _dartDefineBaseUrl;             // --dart-define=API_BASE_URL=...
}
```
On web, the app always routes API calls through the nginx container at the
same origin the page was loaded from. This means:
- No CORS preflight on any browser, regardless of IP/hostname.
- The nginx `location /api/` block proxies to the `api` container.
- The Flutter web app does **not** need to know the server's IP.

For Android / Windows native builds, pass the API URL at build time:
```bash
flutter build apk --dart-define=API_BASE_URL=http://192.168.1.x:3000/api/v1
```

### Token storage — web vs. native

| Platform | Storage backend | Notes |
|---|---|---|
| Web (any) | `dart:html` `window.localStorage` | No plugin, no Web Crypto, works over HTTP |
| Android | `flutter_secure_storage` → Android Keystore | Encrypted at rest |
| Windows | `flutter_secure_storage` → Windows Credential Manager | Encrypted at rest |

Selected via **conditional import** at compile time:
```dart
import '_storage_stub.dart' if (dart.library.html) '_storage_web.dart';
```

Two alternatives were tried and rejected:

1. **`flutter_secure_storage` on web** — requires `window.crypto.subtle`
   (Web Crypto API), only available in secure contexts (HTTPS/localhost).
   Caused `Null check operator used on a null value` on plain-HTTP LAN access.

2. **`shared_preferences` on web** — requires a Flutter plugin channel absent
   in the web runtime on some mobile browsers.
   Caused `MissingPluginException` on mobile.

3. **`dart:html window.localStorage` via conditional import** ✅ — built-in
   Dart web library, zero plugin overhead, works on any browser over HTTP.
   Tokens are readable by JS (XSS risk), acceptable for an internal LAN tool.
   When HTTPS is added, reconsider `flutter_secure_storage` on web.

### State management
Riverpod `AsyncNotifier` is used for auth state. The initial `build()` call
checks for a stored token and calls `/auth/me` to validate it. Errors from
that call (expired token, network error) silently clear the token and return
`null` (unauthenticated state).

### Routing
`go_router` with a `redirect` guard re-evaluates auth state on every
navigation. The guard is driven by a `ChangeNotifier` that listens to the
`authControllerProvider` — so it updates automatically on login/logout without
recreating the router.

---

## DevOps

### Docker Compose services
| Service | Image | Port |
|---|---|---|
| `postgres` | `postgres:16-alpine` | `127.0.0.1:5432` (localhost only) |
| `api` | `autoservice-api` (built from `backend/`) | `0.0.0.0:3000` |
| `web` | `nginx:1.27-alpine` | `0.0.0.0:8080` |

The `web` service is optional and requires a prior `flutter build web` in
`frontend/`. The built output at `frontend/build/web/` is mounted read-only
into nginx.

### Rebuilding after code changes
- **Backend change:** `docker compose up -d --build api`
- **Frontend change:** `flutter build web --release` → `docker restart repairshop_web`
- **`.env` change:** `docker compose up -d --force-recreate <service>` (a
  simple `restart` does **not** re-read `.env` values baked into the container
  at creation time)

### Persistent data
PostgreSQL data lives in the `pgdata` named Docker volume. To fully reset the
database (e.g. after a password change):
```bash
docker compose down -v   # removes containers AND the pgdata volume
docker compose up -d --build postgres api
```

---

## Known Limitations / Future Work

| Area | Issue | Suggested Fix |
|---|---|---|
| HTTPS | App runs over plain HTTP; Web Crypto unavailable on LAN | Add TLS (self-signed cert or Let's Encrypt via Caddy/Traefik) |
| Token storage (web) | `localStorage` is readable by JS (XSS risk) | Acceptable for internal LAN; switch to `flutter_secure_storage` when HTTPS is available |
| Work-order numbering | Global sequence, not per-shop | Add `shop_counters` table with advisory lock |
| Role-based UI | Schema supports owner/manager/technician but UI doesn't restrict by role | Add `canManage` guards to edit/delete actions |
| Testing | No automated tests exist | Add `jest` + `supertest` for backend; `flutter_test` for frontend |
| CI/CD | No pipeline | Add GitHub Actions: lint → test → build → deploy |
