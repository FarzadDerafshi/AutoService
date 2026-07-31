# AutoService — Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.5.1] — 2026-07-31  *(Fix — Vehicle History → Work Order Detail Link Broken)*

### Fixed

#### Frontend
- **Tapping a work order in Vehicle History opened the Work Orders screen with
  nothing shown**
  `vehicle_history_screen.dart` navigated via `context.push('/work-orders?id=${id}')`,
  which routes to `WorkOrdersScreen(initialId: ...)`. That screen only shows the
  detail panel through `MasterDetailScaffold`, which renders *only* the master
  list on windows narrower than the 900px desktop breakpoint — silently
  dropping the detail panel regardless of `initialId`. On any normal browser
  window or phone under that width, tapping a vehicle's service-history entry
  landed on the work-orders list with no order selected and no visible error.

  Fix: navigate via the direct detail route (`/work-orders/${id}` →
  `WorkOrderDetailScreen`) instead — the same route `global_search_bar.dart`
  and `work_orders_master_list.dart` already use for this exact "jump to a
  work order from elsewhere" case. Renders the full order detail
  (client/vehicle/date, line items, totals, status actions) regardless of
  window width.
  Verified in-browser at both a narrow (700px) and wide (1280px) window size,
  tapping a real service-history entry end to end.
  _File: `frontend/lib/features/vehicles/presentation/vehicle_history_screen.dart`_

---

## [0.5.0] — 2026-07-31  *(Security Fix — Cross-Tenant Data Leak)*

### Fixed

#### Backend — Critical
- **Every shop could read (and in some cases write) every other shop's data**
  Discovered while investigating an unrelated report of an empty Vehicle
  History screen. `db/init/008_row_level_security.sql` enables Postgres RLS
  on `clients`, `vehicles`, `catalog_items`, `work_orders`, `work_order_items`,
  and `users`, intended as defense-in-depth on top of application-level
  `shop_id` filtering (per the original architecture doc). In practice:
  1. The API connects as `repairshop_admin`, which also **owns** every one of
     those tables (it ran the `db/init` migrations). Postgres exempts table
     owners from RLS policies by default unless `FORCE ROW LEVEL SECURITY` is
     also set — it wasn't, so RLS was silently a no-op for every request.
  2. Nearly every list/get/update/delete query across every module (clients,
     vehicles, catalog, work orders, reports, search) had no explicit
     `WHERE shop_id = ...` filter at all, because the app-level scoping half
     of the intended two-layer defense was never actually written — the code
     relied solely on RLS, which was never active.

  Net effect: any authenticated user, in any shop, could list/read every
  other shop's clients, vehicles, catalog items, and work orders through the
  API. Confirmed with a live reproduction: a brand-new, empty test shop's
  session (`GET /api/v1/vehicles`) returned another shop's vehicles verbatim.
  Two write-path cases were also affected — `POST /work-orders` didn't verify
  the given `clientId`/`vehicleId` belonged to the caller's shop, and its
  mileage-sync `UPDATE vehicles` had no shop filter — so a work order could
  be attached to another shop's client/vehicle, and that vehicle's mileage
  could be overwritten cross-tenant.

  Fix: added an explicit `shop_id = current_setting('app.current_shop_id')::uuid`
  condition to every query in every service module that reads or mutates a
  shop-scoped table — restoring the application-level scoping layer the
  architecture always called for, independent of whether RLS is active.
  `createWorkOrder` now also verifies the referenced client and vehicle belong
  to the caller's shop before inserting.

  **Not changed in this pass:** `registerShopAndOwner`, `login`, and
  `getCurrentUser` in `auth.service.ts` — these run before a `shop_id` session
  context exists (registration creates the shop; login looks up by email
  across shops by design, since the login form doesn't ask which shop) or
  already filter by shop_id explicitly (`getCurrentUser`). Enabling
  `FORCE ROW LEVEL SECURITY` as a true backstop is deliberately deferred: it
  would additionally require reworking these three flows (their queries run
  outside `tenantScope`, so `app.current_shop_id` isn't set when they execute,
  and a forced policy would reject their inserts/selects outright). See
  DECISIONS.md for the follow-up.

  Verified: registered a fresh empty shop, confirmed it could no longer see
  another shop's vehicles/history via direct API calls (was returning data
  before, returns `404`/empty after); ran a full create-client → create-vehicle
  → create-work-order → history → reports → search regression against the
  fix to confirm same-shop operations still work; confirmed the real shop's
  pre-existing data (2 vehicles, 2 work orders) was untouched throughout.
  _Files: `backend/src/modules/clients/clients.service.ts`,
  `backend/src/modules/vehicles/vehicles.service.ts`,
  `backend/src/modules/catalog/catalog.service.ts`,
  `backend/src/modules/workOrders/workOrders.service.ts`,
  `backend/src/modules/workOrders/workOrders.pdf.ts`,
  `backend/src/modules/reports/reports.service.ts`,
  `backend/src/modules/search/search.service.ts`_

---

## [0.4.3] — 2026-07-31  *(Turkish Localization Patch — Vehicle History Order Titles)*

### Fixed

#### Frontend
- **Vehicle History screen's order list showed a hardcoded English title**
  `vehicle_history_screen.dart` built each service-history row's title with a
  raw string template (`'Order #${order['orderNo']} — ${order['status']}'`),
  bypassing localisation entirely — including the raw backend status enum
  value (`draft`/`completed`/`paid`), which stayed in English even in Turkish.

  Fix: reused the existing `orderNo` ARB key for the order number, and added
  a small `_statusLabel()` helper that maps the raw status string to the
  existing localized `l.draft`/`l.completed`/`l.paid` getters (same ones
  already used by the work-orders filter chips). No new ARB keys needed.
  Verified in-browser: vehicle with a completed order now reads
  "#1 Sipariş — Tamamlandı" in Turkish and "Order #1 — completed" in English.
  _File: `frontend/lib/features/vehicles/presentation/vehicle_history_screen.dart`_

---

## [0.4.2] — 2026-07-31  *(Turkish Localization Patch — New/Edit Vehicle Form)*

### Fixed

#### Frontend
- **New/Edit Vehicle form sheet still displayed English strings**
  `vehicle_form_sheet.dart` was not wired to the localisation system, so the
  bottom-sheet shown when creating or editing a vehicle always rendered in
  English regardless of the selected language.
  Affected strings: sheet title (*New Vehicle* / *Edit Vehicle*), field labels
  (*Owner*, *License plate*, *Make*, *Model*, *Engine*, *Year*, *Current
  mileage (km)*), inline validator messages (*Select an owner*, *Required*),
  the "failed to load clients" error text, and the submit button (*Save*).

  Fix: added `AppLocalizations` import and resolved all hardcoded strings
  through `l10n.*` getters (reusing the existing `required`/`save` keys from
  the 0.4.1 catalog patch).
  New ARB keys added to both `app_en.arb` and `app_tr.arb`: `newVehicle`,
  `editVehicle`, `owner`, `selectAnOwner`, `failedToLoadClients`,
  `licensePlate`, `make`, `model`, `engineLabel`, `yearFieldLabel`,
  `currentMileageKmLabel`. (Named distinctly from the pre-existing
  placeholder-style `engine`/`yearLabel`/`currentMileage` keys used
  elsewhere for display text, to avoid collisions.)
  Generated files (`app_localizations.dart`, `app_localizations_en.dart`,
  `app_localizations_tr.dart`) updated to match.
  Verified in-browser: opened the form in both English and Turkish, and
  triggered the empty-submit validators in Turkish (*Bir sahip seçin*,
  *Zorunlu*).
  _Files: `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations.dart`,
  `frontend/lib/generated/app_localizations_en.dart`,
  `frontend/lib/generated/app_localizations_tr.dart`_

---

## [0.4.1] — 2026-07-31  *(Turkish Localization Patch — Catalog Item Form)*

### Fixed

#### Frontend
- **Catalog item form sheet still displayed English strings**
  `catalog_item_form_sheet.dart` was not wired to the localisation system,
  so the bottom-sheet shown when creating or editing a catalog item always
  rendered in English regardless of the selected language.
  Affected strings: sheet title (*New Catalog Item* / *Edit Catalog Item*),
  type toggle (*Service* / *Part*), field labels (*Name*, *SKU (optional)*,
  *Unit*, *Default price*), inline validator messages (*Required*,
  *Enter a valid number*), and the submit button (*Save*).

  Fix: added `AppLocalizations` import and resolved all 11 hardcoded strings
  through `l10n.*` getters; removed `const` from `SegmentedButton.segments`
  to allow runtime-localised labels.
  New ARB keys added to both `app_en.arb` and `app_tr.arb`:
  `newCatalogItem`, `editCatalogItem`, `service`, `part`, `nameLabel`,
  `required`, `skuOptional`, `unit`, `defaultPrice`, `enterValidNumber`,
  `save`.
  Generated files (`app_localizations.dart`, `app_localizations_en.dart`,
  `app_localizations_tr.dart`) updated to match.
  _Files: `frontend/lib/features/catalog/presentation/catalog_item_form_sheet.dart`,
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations.dart`,
  `frontend/lib/generated/app_localizations_en.dart`,
  `frontend/lib/generated/app_localizations_tr.dart`_

---

## [0.4.0] — 2026-07-31  *(PWA + Turkish Language Support)*

### Added

#### Frontend
- **Progressive Web App (PWA)**
  The Flutter web build is now installable as a standalone app on Android,
  iOS, Windows, macOS, and Chrome OS.
  - `manifest.json` updated: `name`, `short_name`, `description`, `orientation: any`,
    `background_color` set to match the Material Dark theme.
  - `index.html` updated: correct `<title>`, `apple-mobile-web-app-capable` meta,
    `theme-color` meta, and maskable `apple-touch-icon` links.
  Flutter automatically generates `flutter_service_worker.js` on each release
  build, providing offline asset caching.
  _Files: `frontend/web/manifest.json`, `frontend/web/index.html`_

- **Turkish / English language switching (i18n)**
  The app is now fully localised in English and Turkish.
  A language selector (`[EN] [TR]` segmented button) appears on the login and
  registration screens. Inside the app, language can be changed from the user
  menu (top-right) under *Language → English / Türkçe*. The selection is
  persisted between sessions via `localStorage`.

  Implementation details:
  - `flutter_localizations` (SDK package) + `generate: true` in `pubspec.yaml`.
  - `l10n.yaml` config; ~70-key ARB files for `en` and `tr` under `lib/l10n/`.
  - `flutter gen-l10n` generates `lib/generated/app_localizations.dart` at build
    time — no checked-in generated file.
  - `LocaleNotifier` (Riverpod `StateNotifierProvider`) loads/persists the locale
    code via the same conditional `_storage_web` / `_storage_stub` pattern used
    for JWT tokens.
  - All screens updated to use `AppLocalizations.of(context)!` — zero hardcoded
    UI strings remain in the codebase.
  _Files: `frontend/pubspec.yaml`, `frontend/l10n.yaml`,
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/core/locale/locale_provider.dart`, `frontend/lib/app.dart`,
  and all feature screen files_

### Fixed
- **`intl` version conflict** — `flutter_localizations` from the SDK pins
  `intl` to `0.20.2`; bumped constraint in `pubspec.yaml` from `^0.19.0`
  to `^0.20.2`.
- **Missing `go_router` import in `register_screen.dart`** — `context.pop()`
  requires the `go_router` extension; import was absent, causing a compile
  error caught at build time.

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
