# AutoService — Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.3.0] — 2026-07-30  *(LAN Access & Detail View Fix)*

### Fixed

#### Backend
- **Work order detail returned raw UUIDs for Client and Vehicle**
  `getWorkOrderById` used a plain `SELECT * FROM work_orders` with no JOIN,
  so `clientName`, `vehiclePlate`, `vehicleMake`, and `vehicleModel` were
  absent from the detail response. The Flutter detail panel falls back to
  `order.clientId` / `order.vehicleId` when the name fields are null —
  so users saw raw UUIDs instead of human-readable values.
  Fix: `getWorkOrderById` now JOINs `clients` and `vehicles` identically to
  `listWorkOrders`, ensuring all denormalised display fields are always present
  in both list and detail responses.
  _File: `backend/src/modules/workOrders/workOrders.service.ts`_

#### Frontend
- **`MissingPluginException` for `shared_preferences` on mobile browsers**
  The previous fix for the Web Crypto crash switched to `shared_preferences`
  for JWT token persistence on web. However `shared_preferences` requires a
  Flutter plugin channel that is absent in the web runtime on some mobile
  browsers, causing `MissingPluginException(No implementation found for method
  getAll on channel plugins.flutter.io/shared_preferences)` immediately on
  login.
  Fix: replaced `shared_preferences` with direct `dart:html`
  `window.localStorage` access via a **conditional import** pattern.
  `_storage_web.dart` (web) and `_storage_stub.dart` (native) are selected at
  compile time — no plugin channel, no Web Crypto, works on any browser over
  plain HTTP. `shared_preferences` removed from `pubspec.yaml`.
  _Files: `frontend/lib/core/storage/token_storage.dart`,
  `frontend/lib/core/storage/_storage_web.dart`,
  `frontend/lib/core/storage/_storage_stub.dart`,
  `frontend/pubspec.yaml`_

### Added
- **`CHANGELOG.md`** — this file.
- **`DECISIONS.md`** — architecture decisions, gotchas, and known limitations.
- **`README.md`** updated with LAN access instructions, rebuild cheatsheet,
  and links to new documentation files.

---

## [0.2.0] — 2026-07-30  *(Bring-up & Bug-fix Sprint)*

### Fixed

#### Backend
- **`tenantScope` middleware — `SET LOCAL` with parameterised placeholder**
  Every authenticated route returned `500 Internal Server Error` with the
  PostgreSQL message `syntax error at or near "$1"`.
  Root cause: `SET LOCAL app.current_shop_id = $1` is a configuration
  directive; PostgreSQL does not accept `$N` placeholders in `SET` statements.
  Fix: inline the UUID (which always originates from our own signed JWT, never
  raw user input) using a template literal.
  _File: `backend/src/middleware/tenantScope.ts`_

- **DB password contained `#` (URL fragment character)**
  The `.env` password `RepairShop_Dev#2026` was embedded in `DATABASE_URL`
  as `postgres://user:RepairShop_Dev#2026@postgres:5432/db`. The `#` is
  the URL fragment delimiter, causing the `pg` client's URL parser to
  truncate the password and host — resulting in `Invalid URL` on every
  request.
  Fix: password changed to `RepairShopDev2026` (alphanumeric only for dev).
  Production passwords must be URL-encoded or passed as discrete `PG*` env vars.
  _File: `.env`_

- **Docker Compose `restart` does not re-read `.env`**
  `docker compose restart api` reuses the environment captured at container
  creation time. Changed all container updates to use
  `docker compose up -d --build` (recreate) to ensure `.env` changes are
  picked up.

#### Frontend
- **CORS error when accessing from another machine on the LAN**
  The Flutter web app hard-coded `http://localhost:3000/api/v1` as the API
  base URL. Browsers on other machines tried to call `localhost:3000` on
  *their own* machine, triggering a CORS preflight that the API rejected
  (its `CORS_ORIGIN` was `http://localhost:8080`).
  Fix: on web builds, `apiBaseUrl` is now derived dynamically from
  `Uri.base.origin` so requests go through the nginx reverse proxy at the
  same origin the page was loaded from — making them same-origin from the
  browser's perspective and bypassing CORS entirely.
  _File: `frontend/lib/core/api/api_client.dart`_

- **`flutter_secure_storage` crashes on non-HTTPS LAN access**
  `flutter_secure_storage`'s web backend uses `window.crypto.subtle`
  (the Web Crypto API), which browsers only expose in a *secure context*
  (HTTPS or `localhost`). Accessing the app over plain HTTP from another
  machine (`http://192.168.x.x:8080`) leaves `subtle` as `undefined`,
  causing a `Null check operator used on a null value` crash inside
  `saveToken()` immediately after a successful login API call — before the
  user sees any logged-in UI.
  Fix: added `shared_preferences: ^2.3.0`; `TokenStorage` now uses
  `SharedPreferences` (backed by plain `localStorage`) on web and retains
  `flutter_secure_storage` on native (Android / Windows) where keystore
  encryption is unconditionally available.
  _Files: `frontend/pubspec.yaml`, `frontend/lib/core/storage/token_storage.dart`_

### Added
- **`.env` file** (git-ignored) created from `.env.example` with a
  cryptographically generated `JWT_SECRET` and a URL-safe `DB_PASSWORD`.
- **`shared_preferences: ^2.3.0`** added to Flutter dependencies.

---

## [0.1.0] — 2026-07-30  *(Initial Scaffold)*

### Added
- Full PostgreSQL 16 schema: 8 migration files covering shops, users,
  clients, vehicles, catalog items, work orders, work-order line items,
  `updated_at` triggers, and row-level security policies.
- Node.js / Express / TypeScript REST API with modules for auth, clients,
  vehicles, catalog, work orders, reports, and search.
- JWT authentication with bcrypt password hashing and per-request tenant
  scoping via RLS.
- PDF work-order generation using pdfkit.
- Flutter frontend targeting Web, Android, and Windows with Riverpod state
  management and go_router navigation.
- Docker Compose stack: `postgres`, `api`, and optional `web` (nginx) services.
- Nginx reverse-proxy config that serves the Flutter web build and forwards
  `/api/` requests to the API container.
- `README.md` and `SETUP.md` with full setup instructions.
