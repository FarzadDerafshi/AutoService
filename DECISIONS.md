# AutoService — Architecture Decisions & Notes

This file records the key technical decisions made during development and
bring-up so future contributors (or Claude sessions) can understand *why*
things are the way they are.

---

## Database

### Multi-tenancy — application-level `shop_id` scoping is the real enforcement (2026-07-31)
Every table that holds shop-specific data carries a `shop_id` UUID column.
The *intended* design (see `db/init/008_row_level_security.sql`) was two
layers: application-level `WHERE shop_id = ...` on every query, plus
PostgreSQL RLS policies as a defense-in-depth backstop matching the
session-local variable `app.current_shop_id`.

**RLS is currently a no-op and must not be relied on.** The API connects as
`repairshop_admin`, which also owns every table (it ran the `db/init`
migrations) — Postgres exempts table owners from RLS policies by default
unless `FORCE ROW LEVEL SECURITY` is also set, which it isn't. Combined with
several service-layer queries that had been written assuming RLS would
filter for them, this produced a real cross-tenant data leak (any shop could
read another shop's clients/vehicles/catalog/work orders); fixed in v0.5.0 by
adding an explicit `shop_id = current_setting('app.current_shop_id')::uuid`
condition to every query in every service module. **This explicit filtering
is now the only thing enforcing tenant isolation** — treat RLS as inert
until the follow-up below is done, and add the `shop_id` condition to any
new query on a shop-scoped table.

**Follow-up (not yet done):** to make RLS a *real* backstop again — so a
future missing `shop_id` filter fails closed instead of leaking — would
require: (1) `ALTER TABLE ... FORCE ROW LEVEL SECURITY` on all six
shop-scoped tables (or switching the API to a non-owner DB role, which is
subject to RLS regardless of FORCE), **and** (2) reworking three auth-flow
queries that currently run outside `tenantScope` and would break under a
forced policy: `registerShopAndOwner`'s `INSERT INTO users` (no shop context
exists yet — would need `SET LOCAL app.current_shop_id` to the newly-created
shop's id before that insert) and `login`'s cross-shop email lookup (by
design; would need to run with an explicit RLS bypass since it must search
before any shop is known). `getCurrentUser` already filters by shop_id
explicitly and should be unaffected either way.

The tenant-scoping variable is set in the `tenantScope` Express middleware:
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

### Internationalisation (i18n)

The app supports **English** and **Turkish** via Flutter's official
`flutter_localizations` SDK package and the `gen-l10n` code-generation pipeline.

Key files:
| File | Purpose |
|---|---|
| `frontend/l10n.yaml` | Code-gen config (ARB dir, template file, output dir) |
| `frontend/lib/l10n/app_en.arb` | English string catalogue (~70 keys) |
| `frontend/lib/l10n/app_tr.arb` | Turkish translations |
| `frontend/lib/generated/app_localizations*.dart` | Generated at build time by `flutter gen-l10n` |
| `frontend/lib/core/locale/locale_provider.dart` | `StateNotifierProvider<LocaleNotifier, Locale>` |

**Important:** The generated files under `lib/generated/` **are** committed to
the repository. This avoids forcing every contributor to run `flutter gen-l10n`
before they can build. If you add, rename, or **reword** ARB keys, re-run:
```bash
cd frontend && flutter gen-l10n
```
and commit the updated generated files.

**Gotcha (hit in practice, v0.5.2):** never hand-edit a file under
`lib/generated/` directly — always edit the source ARB
(`app_en.arb`/`app_tr.arb`) and regenerate. A wording change was once made by
editing `app_localizations_tr.dart` directly; it worked in the running app
(Dart reads the compiled generated file, not the ARB), but the ARB source
still had the old wording. The *next* `flutter gen-l10n` run — for a
completely unrelated key change — would have silently reverted it, since
generation always overwrites the target file from the ARB. After any manual
edit to a generated file, run `flutter gen-l10n` immediately and diff the
result against what you intended; if it doesn't match, the ARB is out of
sync and needs the same edit backported into it.

**Seeing a translation/UI change take effect in the running Docker stack:**
```bash
cd frontend
flutter gen-l10n              # only needed if you touched an ARB file
flutter build web --release
docker restart repairshop_web
```
A plain browser refresh is not enough to prove the new build landed — the
browser may serve a cached bundle. Force a hard reload (Ctrl+Shift+R) or,
when testing via automation, unregister the service worker / fetch with
`cache: 'no-store'` and check the response for the expected string before
trusting what renders on screen.

**Locale persistence** uses the same `_storage_web` / `_storage_stub`
conditional import pattern as JWT token storage — `localStorage` on web,
`flutter_secure_storage` on native. The locale language code (`"en"` / `"tr"`)
is stored under the key `locale_code`.

**Adding a new language:**
1. Create `frontend/lib/l10n/app_<code>.arb` with all keys from `app_en.arb`.
2. Add `Locale('<code>')` to `supportedLocales` in `frontend/lib/app.dart`.
3. Add `'<code>'` to `LocaleNotifier._supported` in `locale_provider.dart`.
4. Run `flutter gen-l10n` and commit the generated file.

**`intl` version pin:** `flutter_localizations` from the SDK pins `intl` to a
specific version. Always check the pin when upgrading Flutter:
```bash
flutter pub deps | grep intl
```
The `intl` constraint in `pubspec.yaml` must match (`^0.20.2` as of Flutter
3.41.x).

### Progressive Web App (PWA)

Flutter generates a service worker (`flutter_service_worker.js`) automatically
on each `flutter build web --release`. No additional plugin or configuration is
needed for offline asset caching.

Manual PWA configuration (done once):
- **`frontend/web/manifest.json`** — `name`, `short_name`, `description`,
  `orientation: any`, `background_color` matching the Material Dark seed colour.
- **`frontend/web/index.html`** — `<title>`, `apple-mobile-web-app-capable`,
  `theme-color` meta, and `apple-touch-icon` links for iOS home-screen icons.

The Flutter web build must be rebuilt (`flutter build web --release`) and the
nginx container restarted (`docker restart repairshop_web`) for PWA changes to
take effect.

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

**Gotcha — deep-linking into a master-detail screen (fixed v0.5.1):**
`MasterDetailScaffold` only renders `detailPanel` on windows ≥900px
(`desktopBreakpoint`); below that it renders **only** `masterPanel`,
regardless of whether a detail item is selected (see `master_detail_scaffold.dart`).
This means the query-param route `/work-orders?id=<id>` (→
`WorkOrdersScreen(initialId: ...)`, which just sets `selectedWorkOrderIdProvider`)
only actually shows anything on wide windows — on any narrower window or
phone it silently lands on the bare list with nothing selected and no error.
`vehicle_history_screen.dart` hit this exact bug tapping into a service-history
entry. **Any new "jump to a work order from elsewhere" entry point must use
the direct path route `/work-orders/:id` (→ `WorkOrderDetailScreen`)**, not
the `?id=` query-param form — this is what `global_search_bar.dart` and
`work_orders_master_list.dart`'s own mobile branch already do correctly.

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
| RLS not enforced | Table-owner DB role bypasses RLS; app-level `shop_id` filtering (added in v0.5.0) is the only real tenant isolation right now | `FORCE ROW LEVEL SECURITY` + non-owner app role, plus rework `register`/`login` (see Database section above) |
| Catalog item ownership on work orders | `work_order_items.catalog_item_id` isn't verified to belong to the caller's shop when a work order is created | Add the same ownership check used for `clientId`/`vehicleId` in `createWorkOrder` |
| HTTPS | App runs over plain HTTP; Web Crypto unavailable on LAN | Add TLS (self-signed cert or Let's Encrypt via Caddy/Traefik) |
| Token storage (web) | `localStorage` is readable by JS (XSS risk) | Acceptable for internal LAN; switch to `flutter_secure_storage` when HTTPS is available |
| Work-order numbering | Global sequence, not per-shop | Add `shop_counters` table with advisory lock |
| Role-based UI | Schema supports owner/manager/technician but UI doesn't restrict by role | Add `canManage` guards to edit/delete actions |
| Testing | No automated tests exist | Add `jest` + `supertest` for backend; `flutter_test` for frontend |
| CI/CD | No pipeline | Add GitHub Actions: lint → test → build → deploy |
| i18n | Only English and Turkish supported | Add new ARB file + locale entry (see i18n section above) |
| PWA icons | No real icon artwork; manifest references placeholder icons | Replace `icons/` assets with branded artwork |
