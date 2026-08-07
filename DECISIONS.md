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

**Doubling as a link token (v0.11.0):** `shop_invites.id` is also the
public invite-link token (`/join/<id>`) — no separate token column. The
same unguessable-by-design property that makes UUIDs safe as API-visible
IDs elsewhere in this app makes them safe as bearer-style link tokens too;
this avoids maintaining a second random-value scheme for one table.

### Audit-pointer foreign keys should be `ON DELETE SET NULL`, not the default `RESTRICT` (hit in practice, v0.11.0)
`shop_invites.created_by`/`used_by` reference `users(id)` to record *who*
created/accepted an invite — pure audit metadata, not data the invite
depends on to make sense. Left at Postgres's default `ON DELETE RESTRICT`
(what a bare `REFERENCES users(id)` gets you), this silently blocked
deleting a team member who had created or accepted any invite, ever — with
a 409 "referenced by other data" error that looked exactly like the
*intended* block (a user who has created work orders, via
`work_orders.created_by`, which correctly should stay `RESTRICT`). Caught
while verifying the team-invites feature: a brand-new user with zero work
orders still failed to delete, because they were `used_by` on the invite
they'd just accepted.

Fixed by making both columns `ON DELETE SET NULL` (and dropping `NOT NULL`
on `created_by`, required for `SET NULL` to be legal) — the invite row
survives with the pointer cleared. **Rule of thumb for any future
"who did this" column:** if the referencing row's own meaning doesn't
depend on the referenced user still existing, use `SET NULL`; reserve the
default `RESTRICT` for FKs where the referenced row genuinely can't be
orphaned safely (e.g. `work_orders.created_by` — deleting that user while
their work orders exist would be silently discarding who did the work).

### Work-order numbering
`order_no` is a global `SERIAL`. Per-shop sequential numbering (e.g. #1, #2
per shop) was deferred; it would require a `shop_counters` table and an
advisory lock or `FOR UPDATE` to avoid race conditions at scale.

### Line-item `unit` is snapshotted, not live-joined from the catalog item (v0.16.13)
`work_order_items.unit` is populated once, when the line is added (from the
picked `CatalogItem.unit`), and never re-read from `catalog_items`
afterward. This follows the same reasoning already documented on
`description`/`unit_price` in `db/init/006_work_order_items.sql`: a work
order is a historical record of what was actually sold/serviced, and a
later edit to (or deletion of) the catalog item must not retroactively
change what an already-issued order says. The frontend's `_ItemRow.unit`
mirrors this — it's a plain `String` captured once at construction, not a
live lookup against the catalog provider's cache, and stays blank for a
custom (non-catalog) line item since there's nothing to snapshot from.

### Status rollback (paid/completed -> draft) — the one audited exception to the forward-only machine (v0.16.8)

`workOrders.service.ts`'s `ALLOWED_TRANSITIONS` is documented as
forward-only (`draft -> completed -> paid`, no skipping, no going back) —
rollback is a deliberate, narrow exception to that, gated by its own
`ALLOWED_ROLLBACKS` map and its own `authorize()` check, not a loosening
of `ALLOWED_TRANSITIONS` itself. Both `paid` and `completed` roll back
straight to `draft` (never to the intermediate step) — the real-world
reason this exists is "we marked this wrong, undo it," which doesn't
benefit from passing back through `completed` on the way down.

**Audit-pointer FK trap, caught before shipping:** the first draft of
`work_order_rollbacks.work_order_id` used `ON DELETE CASCADE`, matching
`work_order_items`. That's wrong for an audit table specifically: a
rollback sets the order's status to `draft`, and `deleteWorkOrder`
(`workOrders.service.ts`) allows deleting any `draft` order — so `CASCADE`
would let deleting the now-draft order silently erase the very audit row
proving the rollback happened. Fixed with `ON DELETE SET NULL` (same
precedent as `shop_invites.created_by`/`used_by`, see the "Audit-pointer
foreign keys" entry above) plus denormalizing `order_no`,
`performed_by_name`, and every `prior_*` column onto the audit row at
write time, so it stays meaningful even after the order — or the acting
user — is later deleted. Verified directly: rolled an order back, deleted
it, confirmed the audit row survived with `work_order_id = NULL` and every
other field intact.

**Authorization bar: `owner`+`manager` (`canManage`), same as edit/delete
of a draft — not owner-only.** Owner-only was the first instinct during
design, reasoning that this can retroactively rewrite recognized revenue
(see the reports note below) — a materially bigger blast radius than
editing or deleting a draft. Farzad's call: `owner`+`manager`, matching
the existing bar elsewhere in this module. If misuse becomes a real
problem in practice, tightening to owner-only is a one-argument change on
the route (`authorize("owner")`) — no schema or audit-table change needed,
since `performed_by`/`performed_by_name` already record exactly who did it
regardless of which roles are allowed to.

**Retroactively changes past revenue reports — by design, not a bug.**
`reports.service.ts`'s `getRevenueReport` filters on
`status = 'paid' AND paid_at IS NOT NULL`. The moment a rollback clears
either, the order silently drops out of whatever historical period it was
previously counted in — a month that already "closed" can shrink after
the fact. This is exactly why the feature requires a mandatory reason and
writes a permanent, un-deletable-by-normal-means audit trail: the point is
that this consequence stays traceable and explainable, not that it doesn't
happen. The frontend's confirmation dialog states this consequence
explicitly before the user confirms, rather than letting them discover it
later on the Reports screen.

**Actor's name is looked up, not carried on the JWT.** `signToken`
(`auth.service.ts`) only ever signs `{ userId, shopId, role }`. Widening
the JWT payload to include `fullName` would leave every already-issued
token (still valid for up to 8h, `JWT_EXPIRES_IN`) without it until
re-login. Since rollback is a rare, low-volume action, `rollbackWorkOrderStatus`
does one extra `SELECT full_name FROM users WHERE id = $1` instead —
simpler than reasoning about token-shape migration for a field that's
only ever read in one place.

### Turkish-format plate display — a display-layer concern only, never touching the stored/edited value (v0.16.12)

`formatPlateDisplay` (`frontend/lib/core/utils/plate_formatter.dart`,
mirrored in `workOrders.pdf.ts` for the PDF) reformats an already-stored
plate ("34ABC123") to "34 ABC 123" for display. Two decisions worth
knowing before touching plate formatting anywhere else in the app:

**Shape-matching, not official-rule validation.** The regex
(`^(\d{2})([A-Z]{1,3})(\d{2,4})$`) matches 2 digits + 1–3 letters + 2–4
digits — the general shape of a Turkish plate — rather than the exact
official letter/digit-count pairing (1 letter+4 digits, 2+3, or 3+2).
Deliberate: hard-coding the exact combination table risks *rejecting* a
genuinely valid Turkish plate if that table is ever misremembered or the
rule changes, whereas the general shape reliably catches every real
Turkish plate and safely leaves anything else (foreign plates, odd data)
completely untouched — which is the actual requirement ("if it's a
foreign plate just keep it as it is"), not exact format validation.

**Strictly display-only — verified there's no path back into an editable
value.** `vehicles.license_plate`/`normalizePlate` and everything the
frontend sends to the API stay uppercase-no-spaces exactly as before;
`formatPlateDisplay` is called only at final `Text(...)`/PDF-render call
sites. One real leak path existed and was closed: the work order form's
vehicle `SearchAutocompleteField`'s `displayStringForOption` is now
formatted (since its dropdown/selected text is a genuine "showing"
context), but that same text can flow into `onCreateNew`'s `initialPlate`
— which seeds the *editable* Plaka field of the quick-create vehicle
sheet, if a user edits an already-selected vehicle's text back into
"create new" territory. Fixed by stripping spaces at that specific
hand-off (`initialPlate: typedText.replaceAll(' ', '')`) rather than by
leaving the picker's own display unformatted — the picker's display value
benefits from formatting, and the one downstream consumer that needs the
raw value now gets it explicitly, rather than the whole feature being
scoped back to avoid the one edge case.
`vehicles.service.ts`'s `createVehicle`/`updateVehicle` also call
`normalizePlate()` unconditionally on write regardless, so even if a
space had leaked through, the stored value would still end up correct —
this fix closes the *cosmetic* gap during editing, not a data-integrity
one that didn't otherwise exist.

**Any future new display site for a plate must call `formatPlateDisplay`
too — it doesn't happen automatically.** Grep for `licensePlate`/
`vehiclePlate`/`license_plate` when adding one; the seven call sites
fixed in v0.16.12 were all found this way, not by guessing which screens
show a plate.

### Optional client link — vehicles and work orders can exist with no linked client (v0.16.11)

`vehicles.client_id` and `work_orders.client_id` both went from `NOT NULL`
to nullable. Business reality driving this: a real fraction of walk-in
jobs never get a client record at all — only the car. The plate is this
app's actual per-shop identity key for a vehicle (`vehicles` already had
`UNIQUE (shop_id, license_plate)` since `003_vehicles.sql` — this wasn't a
new constraint, just a fact the schema already reflected before this
feature made it load-bearing).

**Both tables had to change, not just `vehicles`.** The request that
triggered this only mentioned the vehicle→client link, but relaxing just
that one FK would have been incomplete: if a work order still hard-required
a client, a client-less vehicle could never actually be serviced — the
walk-in case would exist in the data model but be unreachable in practice.
Both nullability changes ship together for this reason.

**A client can be attached to a walk-in vehicle at the order level without
touching the vehicle's own record.** `createWorkOrder`'s ownership-pairing
check (`workOrders.service.ts`) only rejects a *genuine* mismatch — a
`clientId` that conflicts with a vehicle's own *already-set* `client_id`.
If the vehicle has no owner at all, any submitted `clientId` is accepted
as-is, and nothing writes back to `vehicles.client_id`. This was a
deliberate design choice, not an oversight: "the customer identified
themselves for this one job" is common and shouldn't force an edit to the
vehicle master record just to record it. The same reasoning is mirrored in
`work_order_form_screen.dart`'s field-sync logic — selecting a client
while a client-less vehicle is already picked doesn't clear the vehicle
selection (it only would if the vehicle had a *different set* owner), and
selecting a client-less vehicle doesn't clear an already-selected client.

**Four `JOIN clients` had to become `LEFT JOIN`, found by grepping every
`JOIN clients` in the backend, not by waiting for a bug report:**
`workOrders.service.ts` (list + detail), `workOrders.pdf.ts`,
`vehicles.service.ts`'s `searchVehicles`, and `search.service.ts`'s
order-number lookup. An inner join on a now-optional FK doesn't error —
it just silently drops every row where the join target is `NULL`, which
here would have meant every walk-in vehicle/work order quietly vanishing
from search results, lists, and the printed PDF the moment this shipped,
with no exception or log line pointing at why. Any future query joining
`work_orders`/`vehicles` to `clients` needs the same `LEFT JOIN`, not the
habitual `JOIN` — this is now a permanently optional relationship, not an
occasionally-null one.

**Frontend fallback display: "Walk-in Customer" / "Kayıtsız Müşteri",
not a blank or a raw UUID.** `WorkOrder.clientId`/`clientName` and
`Vehicle.clientId` are all `String?` now; every display site that used to
assume a client always exists (`clientLabel(order.clientName ??
order.clientId)`) would otherwise have either shown a raw UUID or, if
`clientId` itself is also null, hit a non-nullable-parameter type error.
Fixed with an explicit final fallback (`?? l.walkInCustomer`) at each of
the three call sites (work-orders list, detail panel, work order form's
edit-mode header) plus the PDF's own English-language equivalent (the PDF
has no l10n system at all — every label on it, e.g. "CLIENT"/"VEHICLE", is
hardcoded English regardless of the shop's locale, so "Walk-in Customer"
matches that existing convention rather than being translated).

### work_orders.service_date — a plain DATE string end-to-end, never a Date/DateTime object (v0.16.10)

`service_date` (`db/init/015_work_order_service_date.sql`) is the
user-facing, backdatable date on a work order — what prints on the slip
and what drives the work-orders list's sort order. Deliberately separate
from `created_at`, which stays a pure system audit timestamp (row insert
time) and is never edited. Two decisions here are worth knowing before
touching this column or adding another `DATE`-typed one elsewhere:

**The column stays a plain `"YYYY-MM-DD"` string in every layer — Postgres,
Express JSON, and the Flutter model — never a JS `Date` or Dart
`DateTime`.** node-postgres's default type parser for `DATE` (OID 1082)
constructs a JS `Date` from the column's local calendar components, which
is a real timezone-shift trap for a value that's a calendar date with no
time component: round-tripping it through a `Date`/`DateTime` object
anywhere in the stack means picking a timezone to interpret it in, and a
plain date has no correct one. Fixed by registering a custom type parser
in `config/db.ts` (next to the existing `NUMERIC` override) that returns
the raw string unchanged:
```ts
const DATE_OID = 1082;
types.setTypeParser(DATE_OID, (value: string) => value);
```
The Zod schema validates it as a string (`/^\d{4}-\d{2}-\d{2}$/`), the
Flutter `WorkOrder` model stores it as `String serviceDate` (not
`DateTime`), and `frontend/lib/core/utils/date_formatter.dart`'s helpers
do all display/picker-seeding work via string splitting or a
component-wise `DateTime(y, m, d)` construction — never
`DateTime.parse`, which treats a bare date string as UTC and can silently
land on the wrong calendar day once anything downstream calls
`.toLocal()` on it.

**`serviceDate` is a *required* field on `createWorkOrderSchema`, with no
server-side default.** The natural-looking alternative —
`.default(() => new Date().toISOString().slice(0, 10))` — would compute
"today" using the *server's* clock and timezone, not the shop's. This app
is Turkey-only (UTC+3); the backend container almost certainly runs in
UTC regardless of host timezone. Any order created between local midnight
and 3am would silently get dated "yesterday" by that default — a subtle,
narrow-window bug that's exactly the kind that ships unnoticed and then
looks like data corruption months later. Instead, the frontend — which
actually knows the device's local date — always sends `serviceDate`
explicitly (`work_order_form_screen.dart` seeds it via `todayIso()` on a
new form). The DB column's own `DEFAULT CURRENT_DATE` is left in place as
a fallback purely for a direct-SQL insert that bypasses the API entirely,
not as the primary path.

**List sort order changed from `created_at DESC` to `service_date DESC,
created_at DESC`.** Not optional once the list displays this date instead
of the order number (see CHANGELOG v0.16.10): without the sort change, a
backdated entry would still appear at the top of the list (most recently
inserted) while showing an old date — visually contradicting itself and
defeating the reason backdating exists.

### Schema changes on a live dev database — apply the new `db/init` file directly, don't reset the volume (v0.15.0)
`db/init/*.sql` files only run automatically on a brand-new `pgdata` volume
(Postgres's own init-script behavior) — they do **not** re-run against an
already-provisioned container. Prior column additions (e.g.
`009_shop_profile.sql`, `010_shop_invites.sql`) used a plain
`ALTER TABLE ... ADD COLUMN`, which makes the same file usable two ways:
Postgres runs it automatically for a fresh install, and it can also be
piped directly into the running dev container to update it in place:
```bash
docker exec -i repairshop_db psql -U repairshop_admin -d repairshop < db/init/0NN_new_thing.sql
```
This preserves whatever's already in the dev database — real test data
Farzad has built up (clients, vehicles, work orders, the two standing
WV Ferry test accounts, see the v0.10–v0.12 feature-additions history) —
instead of `docker compose down -v` wiping it. Reach for the full
volume-reset path (`### Persistent data` under DevOps) only when actually
starting over, not as a routine way to pick up new columns. The same new
file also becomes the source of truth for the next fresh install/prod
deployment, so nothing needs to be written twice.

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

### Backend error messages are always English (known gap, v0.14.3)
Every `AppError` subclass (`UnauthorizedError`, `ValidationError`,
`ConflictError`, ...) is thrown with a hardcoded English `message`, and
`errorHandler.ts` returns that string verbatim as `{ error: message }` —
there's no error-code field, and the backend has no notion of the
caller's locale (`tenantScope` sets `app.current_shop_id`, not a language).
The frontend then displays that raw string directly via
`toApiException(e).message` in most catch blocks across the app (login,
register, join, work orders, profile, team, ...).

**Partial fix applied (login only):** `login_screen.dart` now checks the
raw message against the one specific, known, extremely-common string
("Invalid email or password") and swaps in `l.invalidEmailOrPassword` if
it matches, falling back to the raw English text otherwise. This is a
narrow patch for the single most-hit error path, not a systemic fix —
every other screen still shows raw backend English on its less-common
error paths (duplicate email on register, FK-conflict on delete, etc.).

**Real fix, not done yet:** give `AppError` subclasses a stable `code`
field (e.g. `"invalid_credentials"`, `"validation_failed"`) alongside the
existing English `message` (kept for logs/API consumers that want it), and
have the frontend maintain a `code → l10n key` lookup instead of matching
on the literal English sentence — string-matching is fragile (any future
wording change to the backend message silently un-translates the frontend
mapping with no compile error). Worth doing if more error-message reports
come in from testing rather than patching each raw string individually.

### PDF text and Turkish characters (v0.12.0)
PDFKit's built-in `"Helvetica"`/`"Helvetica-Bold"` (and the other standard-14
fonts) are encoded as WinAnsi, which does **not** include the Turkish
letters ı, İ, ğ, Ğ, ş, Ş — text containing them renders as garbled symbols
or drops the character outright. This is invisible in local testing with
English sample data and only shows up once real Turkish shop/client/vehicle
data goes through `renderWorkOrderPdf`. **Any PDF text in this codebase
must use an embedded font, never a standard-14 font name.**

`backend/src/config/fonts.ts` exports `FONT_REGULAR`/`FONT_BOLD` — absolute
paths (via `require.resolve`) to `dejavu-fonts-ttf`'s `DejaVuSans.ttf`/
`DejaVuSans-Bold.ttf`. Register them once per `PDFDocument` instance
(`doc.registerFont("PdfSans", FONT_REGULAR)`, `workOrders.pdf.ts`) and use
that name everywhere a `"Helvetica"`/`"Helvetica-Bold"` call would
otherwise appear.

**Gotcha — Google-Fonts-style webfont packages don't work standalone for
this (tried and rejected, v0.12.0):** `@fontsource/*` packages (and Google
Fonts' own CSS2 API) split every family into disjoint per-unicode-range
files — e.g. Noto Sans ships separate `latin` and `latin-ext` files, meant
to be layered together via CSS `unicode-range` so a browser only downloads
what a given page needs. Used standalone (as PDFKit requires — one font
file per `registerFont` call, no automatic fallback across files), the
`latin-ext` file is missing plain ASCII and punctuation entirely, and
`latin` is missing the Turkish letters — *neither file alone has what a
Turkish work order needs*. This isn't obvious from the file names or from
opening the font in a design tool; it only shows up as missing glyphs at
render time. Verified this concretely with `fontkit`'s
`hasGlyphForCodePoint(codepoint)` on each candidate file before picking a
replacement — if evaluating a different embedded-font approach in the
future, check coverage this way rather than assuming a "latin-ext" name
means "full extended coverage":
```js
const fontkit = require("fontkit");
const font = fontkit.openSync("path/to/font.ttf");
font.hasGlyphForCodePoint(0x131); // ı — Turkish dotless i
```
DejaVu Sans was chosen instead specifically because it ships as one
complete, non-subsetted TTF per weight (no unicode-range splitting) with
full Latin Extended-A + general punctuation coverage in that single file.

### File uploads — shop logo (v0.10.0)
`backend/src/config/uploads.ts` defines `UPLOADS_DIR` (`path.resolve(process.cwd(),
"uploads")`) and `SHOP_LOGOS_DIR` (`UPLOADS_DIR/shop-logos`) — both single
sources of truth, imported by the shop module (multer's disk storage
destination), `workOrders.pdf.ts` (reads the file back to embed in the
printed letterhead), and `app.ts` (the static-serve mount). `process.cwd()`
resolves to `/app` in the container (matches `WORKDIR` in `Dockerfile`,
which also `mkdir -p /app/uploads` and `chown`s it to the `node` user
before dropping root) and to `backend/` in local dev — both align with the
`./backend/uploads:/app/uploads` volume Docker Compose already mounted
(originally captioned "PDF/print output & attachments," unused until now).

**Multer 2.x, not 1.x:** `npm install multer` currently resolves to a 1.x
version that's deprecated with known CVEs (patched in 2.x); pinned
`"multer": "^2.0.1"` explicitly instead of accepting whatever `^1.x` a bare
install would have picked.

**Filename = `${shopId}.<ext>`, one file per shop:** simplest possible
scheme — no history/versioning needed for a logo. `shop.service.ts`'s
`setShopLogo`/`clearShopLogo` unlink the previous file if its extension
differs from the new one (e.g. replacing a `.png` with a `.jpg`), so
switching image formats doesn't leak orphaned files.

**Served publicly, no auth:** `/api/v1/uploads` is mounted via
`express.static` *before* the authenticated route mounts in `app.ts`, with
no `authenticate` middleware — same treatment as the app's own static
branding assets (`frontend/web/icons/*`, `og-image.png`). A shop's logo
isn't sensitive, and both the browser `<img>` tag and the PDF's on-disk
`fs.existsSync`/`doc.image()` read need it reachable without attaching a
JWT.

**Multer errors surfaced properly:** `errorHandler.ts` gained a
`multer.MulterError` branch (400 with the library's own message) ahead of
the generic 500 fallback — file-too-large / wrong-mimetype rejections would
otherwise read as an opaque "Internal server error" to the client. The
mimetype rejection itself (`fileFilter` in `shop.routes.ts`) throws a
`ValidationError` directly instead, so it's handled by the existing
`AppError` branch.

### Team invites — public routes mixed into an otherwise-protected router (v0.11.0)
`invites.routes.ts` registers `GET /:id/public` and `POST /:id/join`
*before* calling `invitesRoutes.use(authenticate, tenantScope)` — Express
walks a router's stack in registration order per request, so a route
handler registered earlier runs (and, via `asyncHandler`, sends its
response) without ever reaching a `.use()` call registered afterward. This
is the same trick `auth.routes.ts` already uses to mix public
`/register`/`/login` with an authenticated `/me` in one router; `invites`
just has two public routes to `auth`'s two, in the same file rather than a
separate one, because both need the same `:id` param space as the
authenticated invite-management routes right below them.

The public routes intentionally do **not** use `req.db` (which requires
`tenantScope` to have already run and set `app.current_shop_id`) — they
query through the plain `pool` import instead, exactly like
`auth.service.ts`'s `login`/`registerShopAndOwner` do for the same reason:
there's no shop context yet for a visitor who doesn't have an account.

**Race safety on accept:** `POST /:id/join` re-checks the invite's
validity (not expired/used/revoked) *inside* a transaction, using
`SELECT ... FOR UPDATE` to lock the row before checking — without the
lock, two people opening the same link within the same moment could both
pass the "not yet used" check before either one's `UPDATE ... SET used_at`
commits, creating two accounts off one invite. `FOR UPDATE` serializes the
second request behind the first's transaction.

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

**Gotcha (hit in practice, v0.10.1): a `fetch(url, {cache:'no-store'})`
check from the browser console does *not* prove the running app loaded the
new build.** `main.dart.js` is referenced from `flutter_bootstrap.js` with
a plain, non-hashed URL (`mainJsPath: "main.dart.js"`) and nginx sends no
explicit `Cache-Control` header, so the actual `<script src="main.dart.js">`
tag load is subject to the browser's own HTTP heuristic caching —
independent of, and not bypassed by, a manual `fetch()` call elsewhere on
the same page (that fetch has its own cache decision; it doesn't invalidate
what a `<script>` tag will get on the next navigation). A stale-bundle bug
can look "fixed" by every diagnostic check except reloading the actual app.
The only reliable way to rule this out is a genuine hard reload
(Ctrl+Shift+R, which sends cache-defeating request headers) immediately
before the real test, not a side-channel fetch check.

**Locale persistence** uses the same `_storage_web` / `_storage_stub`
conditional import pattern as JWT token storage — `localStorage` on web,
`flutter_secure_storage` on native. The locale language code (`"en"` / `"tr"`)
is stored under the key `locale_code`.

**Corporate/Garage tone labels — two different treatments, both intentional
(v0.9.2):** there are two separate widgets that let a user pick the
Corporate-vs-Garage voice tone, and they're localized differently on
purpose:
- `core/widgets/tone_toggle.dart` (used on the login screen) is icon-only —
  no text is rendered, only tooltips — so it's treated like the "EN"/"TR"
  language chips and left untranslated.
- The account popup menu in `core/widgets/app_shell.dart` renders the actual
  words "Corporate"/"Garage" (→ "Kurumsal"/"Garaj" in Turkish) as visible
  text, via ARB keys `toneCorporate`/`toneStreet`, because a real word
  sitting in an otherwise fully-Turkish menu reads as a bug (this is exactly
  how it was caught — a screenshot of the Turkish UI). Confirmed with Farzad
  before diverging from the older icon-toggle's documented intent.

If you're auditing for hard-coded English strings again, don't assume every
instance of a tone label is covered by the tone_toggle.dart exemption —
check whether the specific widget actually renders text or just an icon.

**Language switcher hidden, Turkish is the default (v0.14.0, temporary):**
`core/locale/locale_provider.dart` exports `kLanguageToggleVisible = false`,
which every EN/TR toggle widget in the app (login, register, join,
app-shell account menu) is wrapped in. `LocaleNotifier`'s initial state was
also changed from `Locale('en')` to `Locale('tr')`. Farzad requested this
after first real user testing — every current user is Turkish, and the
toggle was just surface area for confusion — but was explicit it's
temporary ("for the time being, until stated otherwise"), not a decision to
drop English support. Both ARB files (`app_en.arb`/`app_tr.arb`) must keep
being updated for every future feature/fix regardless of this flag —
English just isn't reachable from the UI right now. A user who already had
`locale_code: 'en'` in browser storage from before this change keeps
seeing English (the stored value still wins over the new default); only
the *toggle to change it* is hidden. Re-enabling is a one-line flip of the
constant back to `true` (the default-locale line can be left as-is or
reverted, independently).

**Gotcha (hit in practice, v0.14.2): a saved `locale_code` from before this
change silently wins over the new default.** `LocaleNotifier._load()`
unconditionally reads `localStorage`'s `locale_code` and overrides the
constructor default if a value is present — correct for a returning user
under normal operation, but it means anyone whose browser already had
`locale_code: 'en'` saved (from before v0.14.0, or from earlier toggle
testing) kept seeing English after the default changed to Turkish, with no
way back since the toggle itself is hidden. `_load()` now short-circuits
and returns immediately, without touching storage, whenever
`kLanguageToggleVisible` is `false` — so the flag doesn't just change the
*default*, it makes Turkish the *only* outcome while it's off, regardless
of anything already saved. This self-corrects the moment the toggle is
re-enabled (`_load()` goes back to reading storage normally).

**Adding a new language:**
1. Create `frontend/lib/l10n/app_<code>.arb` with all keys from `app_en.arb`.
2. Add `Locale('<code>')` to `supportedLocales` in `frontend/lib/app.dart`.
3. Add `'<code>'` to `LocaleNotifier._supported` in `locale_provider.dart`.
4. Run `flutter gen-l10n` and commit the generated file.

**Every ARB key must exist in all four catalogues — `app_en.arb`,
`app_tr.arb`, `app_en_CP.arb`, `app_tr_CP.arb` (v0.14.5):** the app ships
four locale variants, not two — English/Turkish crossed with
Garage/Corporate tone (the `_CP` files are the Corporate tone; see the
"Corporate/Garage tone labels" note above). `_CP` files subclass the base
language class in generated code
(`AppLocalizationsEnCp extends AppLocalizationsEn`, same for `Tr`), so a key
missing from a `_CP` file doesn't crash or render blank — it silently falls
back to the Garage-tone wording for that key. That fallback is exactly how
this drifted out of sync: `app_en_CP.arb`/`app_tr_CP.arb` were kept current
through v0.9.x (26–27 keys, matching the string count at the time) but never
touched again as v0.10.0–v0.14.4 added ~165 more keys (profile, team
invites, redesigned work-order form, nav), so every one of those newer
screens quietened back to Garage wording under Corporate tone — not a build
break, but real functionality (the CP toggle) silently going stale.
`flutter build web --release`'s "N untranslated message(s)" warning for
`en_CP`/`tr_CP` is the signal to watch — it should read **0** at all times;
a nonzero count means new keys shipped without their Corporate counterpart.

Fixed in v0.14.5 by backfilling both `_CP` files to full 191/191 key parity:
for keys where the Garage-tone wording is already plain/professional (the
large majority — most form labels, nav items, admin/team/profile copy never
had any slang to begin with), the Corporate entry is a verbatim copy of the
Garage one. Only genuinely flavored strings (garage slang, exclamation
marks, metaphors — e.g. `failedToLoadVehicles`'s "dropped the vehicle list
in the oil pan") get a distinct, plainly-worded Corporate rewrite, following
the pattern already established by the ~26 pre-existing `_CP` entries (e.g.
`logIn`: "Punch In" → "Log in").

**Standing rule going forward: every ARB edit touches all four files in the
same change**, not just `app_en.arb`/`app_tr.arb`. When adding or rewording
a key:
- Plain/neutral copy (labels, field names, admin/system messages) → the
  same string goes into both `_CP` files verbatim; no separate "Corporate"
  wording needed, there's nothing to detone.
- Flavored copy (garage slang, exclamation marks, playful metaphors) → write
  a distinct, neutral Corporate equivalent for both `_CP` files, matching
  the register of existing `_CP` entries.
This keeps `flutter build web --release`'s untranslated-message count at 0
on every commit, so re-enabling English (see the language-switcher note
above) or the Corporate tone never surfaces a backlog of stale strings.

**`intl` version pin:** `flutter_localizations` from the SDK pins `intl` to a
specific version. Always check the pin when upgrading Flutter:
```bash
flutter pub deps | grep intl
```
The `intl` constraint in `pubspec.yaml` must match (`^0.20.2` as of Flutter
3.41.x).

**Voice/tone — two selectable sets, independent of language (v0.9.0):**
the app ships with two complete copy sets per language: the default
"street"/"garage" voice (e.g. `logIn` = "Punch In", `delete` = "Scrap it",
work-order statuses "On the Lift"/"Fixed & Ready"/"Cashed Out") and a
"corporate" voice (the original neutral SaaS wording: "Log in", "Delete",
"Draft"/"Completed"/"Paid"). Users toggle between them independently of
EN/TR via the "Voice" control (`core/widgets/tone_toggle.dart`) — visible on
the login screen, the register screen's AppBar, and the authenticated app
bar's user menu.

**How it's implemented — read this before touching any tone-related code:**
"Corporate" is *not* a custom string-resolution layer. It's a real Flutter
`Locale` **country-code variant**: `en_CP` / `tr_CP` ("CP" for
"Corporate") — the exact same mechanism real apps have used for silly/fun
locale variants for years (Facebook's old "Pirate English" was `en_PI`).
`core/locale/tone_provider.dart` holds an `AppTone` enum (`street`/
`corporate`, independent `StateNotifierProvider`, persisted under
`tone_mode` — a different storage key than `LocaleNotifier`'s `locale_code`,
so language and tone are fully decoupled). `app.dart` combines them each
build: `tone == corporate ? Locale(lang.languageCode, 'CP') : lang`, and
passes that as `MaterialApp.router`'s `locale:`.

**Why this approach, and what it buys you:** every existing
`AppLocalizations.of(context)!.xyz` call site across the ~15 screens that
already use it keeps working completely unchanged — gen-l10n auto-generates
`AppLocalizationsEnCp extends AppLocalizationsEn` (and the `tr` equivalent),
so `en_CP` inherits every key from `en` except the ones you explicitly
override. **This is why `app_en_CP.arb`/`app_tr_CP.arb` only contain the
~31 keys per language that actually read differently between tones** — not
a full duplicate of the ~140-key template. `flutter gen-l10n` treats a
locale ARB missing a key as a warning ("N untranslated message(s)"), not an
error, and simply doesn't generate an override for it — confirmed this
before writing any real content, by testing a 2-key partial ARB first.
`GlobalMaterialLocalizations`/`GlobalWidgetsLocalizations`/
`GlobalCupertinoLocalizations` (built-in widget strings like date-picker
buttons) match on `languageCode` alone, ignoring the country code, so they
work unaffected. `Intl.defaultLocale` is never set anywhere in this app
(see `currency_formatter.dart`), so `NumberFormat.currency` isn't
locale-driven either — the fake country code can't break currency
formatting.

**Adding a new tone-varying string:** add the key + street-tone value to
`app_en.arb`/`app_tr.arb` as normal (these are the base/default classes).
Only add an entry to `app_en_CP.arb`/`app_tr_CP.arb` **if the corporate
wording actually differs** — if it doesn't (most field labels and entity
titles don't — e.g. "Owner"/"Sahip", "Make"/"Marka" read the same in both
tones), leave it out of the `_CP` files entirely and it inherits correctly.
Match the existing tone for any new street-voice string — check nearby
wording before adding a plain/neutral label to the default files.

**Known gap:** `TopWrenchLeaderboard` (see below) is still unlocalized —
low priority since it's also unwired to any real data source.

### Order-level VAT/tax and discount hidden across the app (v0.16.3, temporary)

Farzad's request (2026-08-06), same "single named `const bool`, gate the
UI, leave the data/calculation intact" pattern already used for
`kLanguageToggleVisible`/`kRegistrationOpen` above — see the language
switcher entry for the full precedent this follows. No end date was given
("we can view them again later"), and explicitly **hide, don't delete**.

`discountAmount`/`taxRate`/`taxAmount`, `computeTotals`
(`workOrders.service.ts`), and the `grand_total` written to the DB are all
untouched — a work order with real historical discount/tax (created before
this, or via a direct API call) still computes and stores its grand total
correctly. Only the three places that render the individual breakdown
lines are gated:

- **Frontend** — `kOrderTaxAndDiscountVisible` in
  `core/config/feature_flags.dart` wraps the work order form's discount/
  tax-rate `TextFormField`s and its totals card's tax line
  (`work_order_form_screen.dart`), and the detail panel's discount/tax
  `_TotalRow`s (`work_order_detail_panel.dart`).
- **Backend** — the PDF (`workOrders.pdf.ts`) renders its own "Discount"/
  "Tax (rate%)" lines server-side, so the frontend flag can't reach it. A
  parallel `ORDER_TAX_AND_DISCOUNT_VISIBLE` constant lives in a new
  `backend/src/config/featureFlags.ts`, gating the same two `totalsRow`
  calls. **There's no shared config between the Flutter app and the Node
  API** — these two flags must be flipped back to `true` together by hand;
  nothing enforces they stay in sync.

Subtotal and Grand Total stay visible everywhere (Grand Total already
bakes in whatever discount/tax is stored, hidden or not — for a new work
order created while this is off, that's always 0 either way, since the
input fields that would set them to something else are gone).

### Flutter Web plugin registration — stale build cache (hit in practice, v0.10.1)

A plugin that has a web implementation (`file_picker`, `flutter_secure_storage`,
`url_launcher`, ...) only actually works on Flutter Web if it's listed in
the **generated** `web_plugin_registrant.dart`
(`.dart_tool/flutter_build/<content-hash>/web_plugin_registrant.dart`),
which is what calls e.g. `FilePickerWeb.registerWith(registrar)` at app
startup and makes `FilePicker.platform` actually resolve to the web
implementation instead of silently doing nothing. This file is *derived*
from `.flutter-plugins-dependencies` (itself written by `flutter pub get`)
— it is possible for `.flutter-plugins-dependencies` to correctly list a
newly-added plugin under its `"web"` platform entry while the cached
`web_plugin_registrant.dart` under `.dart_tool/flutter_build/` doesn't get
regenerated to match, if Flutter's build-cache hash computation doesn't
detect the change. Symptoms when this happens: the plugin's method calls
either silently no-op or throw a low-level, generically-formatted
JS-style exception ("Error" with a minified stack, no Dart-level message)
that isn't caught by a normal `try/catch` around the call site — because
the failure happens below the plugin-interface layer the try/catch is
wrapping, not inside a rejected Dart `Future` the `await` would surface.
`flutter analyze`/`flutter build web` both succeed normally; nothing in the
build output flags it.

**How this was diagnosed (v0.10.1, `file_picker`'s "Upload logo" button
doing nothing):** confirmed the exception was tied to that one button (not
spontaneous, not reproduced by other buttons), then directly compared
`.flutter-plugins-dependencies` (correct) against the actual generated
`.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart` (missing the
plugin's `registerWith` call) — this is the definitive check. A `grep` for
the plugin's own distinguishing runtime strings
(`file_picker`'s `__file_picker_web-file-input` DOM id, in this case)
against the compiled `main.dart.js` corroborates it: if those strings are
completely absent, the web implementation was never wired in and likely
tree-shaken away.

**Fix:** `flutter clean` (deletes `.dart_tool/`, forcing every cached
build artifact including the registrant to regenerate) → `flutter pub get`
→ rebuild. Re-check the regenerated registrant file directly before
re-testing in the browser — and see the caching gotcha above, since a
stale-served `main.dart.js` can make even a *correct* rebuild look like it
didn't fix anything.

**When to suspect this:** any time a newly-added plugin with a web
implementation compiles fine, has no lint/analyze errors, but its calls do
nothing or throw a generic, non-Dart-looking error specifically on Web
(other platforms unaffected) — especially right after first adding that
dependency to `pubspec.yaml`.

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

**Gotcha — iOS "Add to Home Screen" can show a stale icon even when the
server is correct (hit in practice, v0.9.3):** Safari caches the home-screen
icon per-URL independently of normal HTTP caching (no amount of correct
`Cache-Control`/ETag headers on the server side prevents this). If an iPhone
visited this app's LAN URL before the branded `apple-touch-icon` files
existed (pre-v0.7.0, when the icons were still Flutter's default), it can
keep showing that old icon on every subsequent "Add to Home Screen" forever,
even after the server starts serving the right file. Before assuming a
report like this is a build/deploy bug, verify server-side first:
```bash
curl -s http://localhost:8080/ | grep apple-touch-icon   # confirm the tags
curl -sI http://localhost:8080/icons/Icon-maskable-192.png  # confirm 200 + no long max-age
```
If those check out, the fix is on the device: iOS Settings → Safari →
Advanced → Website Data → find the host/IP → Delete, then reload the page
fresh before retrying "Add to Home Screen".

### Brand icon/logo (v0.7.0 — real logo, replaces the v0.6.0 placeholder)

`assets/branding/logo-master.png` is the source of truth for the app icon —
the actual provided mascot artwork (robot spark plug, thumbs up + wrench,
neon-green on dark navy), supplied as a transparent 1024×1024 PNG (no vector
source this time, unlike the v0.6.0 SVG placeholder it replaced).
`assets/branding/logo-square-1024.png` is a derived, centered/padded square
crop (tight alpha bbox + 12% margin) that every other size is resized from.
**If the master art ever changes, regenerate `logo-square-1024.png` and every
downstream consumer from it together** — same rule as the ARB/generated-file
gotcha above, just for images instead of translations.

No SVG/rasterizer tooling was needed this time — Pillow (Python) was already
installed on this machine. Regeneration approach (rerun if the master changes):
```python
from PIL import Image
master = Image.open("assets/branding/logo-master.png").convert("RGBA")
# 1. crop to the tight opaque-content bbox (alpha > 128) + ~12% padding, pad to square
# 2. logo_square = that crop, used as the base for every resize below
# 3. per target: resize logo_square to `fill_frac * target_size`, composite
#    centered onto a `target_size`x`target_size` canvas — transparent for the
#    in-app asset, opaque navy (#040E21, sampled from the provided flat/
#    background logo variant) for every icon that needs a solid backdrop
render_icon(192, fill_frac=0.82)   # plain icons / favicon / mipmaps / ICO
render_icon(192, fill_frac=0.62)   # maskable icons — stays inside the safe
                                     # zone under a circular mask
render_icon(512, fill_frac=0.96, opaque=False)  # in-app Flutter asset
```
Windows ICO is written directly by Pillow — `Image.save(path, sizes=[(16,16),
(32,32),(48,48),(64,64),(128,128),(256,256)])` on a single high-res source
image produces the full multi-resolution `.ico`; no external tool needed.

Target paths and sizes: `frontend/web/favicon.png` (48px), `frontend/web/icons/Icon-{,maskable-}{192,512}.png`,
`frontend/web/og-image.png` (1200×630 landscape banner, `fill_frac≈0.72`, for
social share previews — see below),
`frontend/android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`
(48/72/96/144/192px), `frontend/windows/runner/resources/app_icon.ico`, and
`frontend/assets/branding/logo.png` (512px, transparent, `fill_frac=0.96`) —
the copy actually bundled into the Flutter app and shown in-app (see below).
Same rebuild-and-restart step as any other web asset change applies
afterward.

**`theme_color`/`background_color`** should always track the app's actual
Material chrome color, not the icon artwork's own backdrop — that was the
whole point of the v0.6.0 fix (Flutter's leftover blue vs. the app's real
green) and why they were *not* changed to navy in v0.7.0 even though the new
logo's backdrop is navy (the app was still SeaGreen-themed then). **They
since changed again in v0.8.0's dark "garage" redesign** — see below — to
`#0D1318` (the new `AppBarTheme.backgroundColor`) / `#0A0F13`
(`AppColors.bg`). If the Material theme's colors change again, update these
two to match the new actual chrome, not the other way around.

**Social share preview (new in v0.7.0):** `index.html` had no Open Graph or
Twitter Card meta tags before this — shared links (WhatsApp, Telegram,
Facebook, Slack, ...) rendered as bare text. Added `og:title`/`og:description`/
`og:image` and `twitter:card`/`twitter:image`, pointing at the new
`frontend/web/og-image.png`. No `og:url` is set — the app runs on a LAN IP
that varies per deployment, so there's no single canonical URL to declare;
scrapers fall back to the page's actual fetch URL.

**Logo inside the app:** `frontend/assets/branding/logo.png` is a real
Flutter asset (declared via `assets/branding/` in `pubspec.yaml`, not just a
generation input) — kept transparent so it works unmodified on both the
light and dark Material themes. Used in `login_screen.dart` (replacing the
`Icons.build_circle` placeholder above the sign-in form) and in
`app_shell.dart`'s app bar title (next to the app name, on every
authenticated screen). Any future in-app logo usage should reference this
same asset (`Image.asset('assets/branding/logo.png')`) rather than adding
another copy.

### State management
Riverpod `AsyncNotifier` is used for auth state. The initial `build()` call
checks for a stored token and calls `/auth/me` to validate it. Errors from
that call (expired token, network error) silently clear the token and return
`null` (unauthenticated state).

**Gotcha — a stateful form built from data that's still loading gets stuck
blank forever (fixed v0.10.0):** every existing form sheet in this app
(`client_form_sheet.dart`, `catalog_item_form_sheet.dart`, ...) is opened
via a button *after* its source data (an `existing: Client?` etc.) is
already sitting in memory, so seeding a `TextEditingController` once in
`initState` is safe. The new Profile screen's "My Account" card broke that
assumption: it's a `ConsumerStatefulWidget` built unconditionally as soon
as `/profile` mounts, reading `currentUserProvider` (backed by
`authControllerProvider`, an `AsyncNotifier`) — and if that screen is
reached before the initial `/auth/me` check resolves (e.g. a direct
navigation to `/profile` on a cold load, before `AuthController.build()`'s
Future completes), `initState` captures an empty/null user, and the
controller **never gets revisited** once the real data arrives a moment
later, because Flutter reuses the same `State` object across parent
rebuilds by default. `TextFormField`'s `initialValue:` prop has the exact
same one-shot behaviour when no external controller is given.

Fix: give the stateful child a `key: ValueKey(user?.id)` from the parent
`ConsumerWidget` (which *does* rebuild reactively on `ref.watch`). The key
changes from `ValueKey(null)` to `ValueKey('<uuid>')` once auth data
resolves, which makes Flutter discard the stale `State` and run `initState`
again with the now-available data. Any future screen that seeds
controllers from a `Provider`/`Riverpod`-backed value *without* going
through an `AsyncValueWidget`-style `data:` builder (which structurally
can't render before the data exists) needs this same treatment.

### PopScope "unsaved changes" guard — dirty tracking and a pop-blocking gotcha (v0.16.7)

`work_order_form_screen.dart` is the first screen in the app to intercept
back navigation. Two decisions worth knowing before touching it or copying
the pattern elsewhere:

**Dirty tracking is "touched," not diffed.** A single `_dirty` bool is
flipped by a listener attached to every field's `TextEditingController`
(added *after* `initState`'s existing seeding, so a freshly opened form —
including the one default blank line item every new order starts with,
see the v0.16.4 fix above — never starts dirty) plus the client/vehicle
`onSelected` callbacks and the add/remove-line-item paths. This means
typing a character and deleting it back to the original value still
counts as dirty — deliberate; diffing against a snapshot of every
`_ItemRow` would be real complexity for a one-screen problem, and false
positives here cost the user one extra "are you sure" dialog, not data
loss. Don't "improve" this into snapshot-diffing without a concrete reason.

**`PopScope`'s `canPop: false` blocks *every* pop attempt on the route, not
just user-initiated back gestures — including your own imperative
`context.pop()` calls.** This isn't obvious from a quick skim of the
widget and caused a near-bug during implementation: `_submit()`'s existing
success path already called `context.pop()` to close the form after
saving, and the new exit-confirmation dialog's "discard" branch does the
same. With `canPop` still `false` at the moment either of those runs (the
form is still "dirty" until the pop actually completes), the pop is
intercepted exactly like a back-button press would be, re-opening the
same unsaved-changes dialog instead of leaving — a save or a chosen
discard would have looked like it silently did nothing. Fix: both code
paths set `_dirty = false` *immediately before* calling `context.pop()`,
never after. Any future screen adding a `PopScope` guard needs the same
ordering for every one of its own imperative pop sites, not just the
system-back path.

**API note:** as of Flutter 3.41.9 (this project's pinned version), the
callback is `onPopInvokedWithResult: (bool didPop, T? result)` —
`PopScope` is now generic (`PopScope<T>`). `onPopInvokedWithDidPop`, the
name commonly referenced in older Flutter docs/tutorials (introduced
3.22), was superseded by this before this project's pin; `flutter analyze`
will flag it as an undefined named parameter if used. Check the installed
SDK's `pop_scope.dart` rather than trusting an older reference if this
API surface changes again.

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

**Self-registration temporarily disabled (v0.14.1):** `/register` is
blocked in the `redirect` guard whenever `kRegistrationOpen` (new file,
`core/config/feature_flags.dart`) is `false` — checked *before* the
existing logged-in/logged-out logic, same position as the `/join/:id`
bypass just above it, so it applies unconditionally regardless of auth
state. Added alongside hiding the login screen's "Create account" link
(same flag) so a visitor can't reach the register form either way during
Farzad's public usability test. Only the frontend paths are closed — the
backend `POST /api/v1/auth/register` route is untouched and still accepts
direct API calls; see CHANGELOG v0.14.1 for why that wasn't included in
this pass. Re-enabling later is the same one-constant flip as
`kLanguageToggleVisible` above.

**Team-invite links bypass the auth redirect entirely (v0.11.0):** the
`redirect` callback checks `loc.startsWith('/join/')` *before* any of the
existing logged-in/logged-out logic and returns `null` (no redirect)
unconditionally for it — unlike `/login`/`/register`, which are only
"public" in the logged-out direction (a logged-in user visiting them
bounces back to `/work-orders`). `/join/:id` must never bounce either way:
a logged-out visitor needs to reach the form, and a visitor who happens to
already be logged in as someone else (e.g. opening the link on a device
where they're signed into another account) also needs to reach it, because
accepting the invite deliberately calls `AuthController.setSession()` to
switch the active session to the newly-created account.

**Building a link a human opens in a browser, from inside the app
(v0.11.0):** `api_client.dart`'s existing `apiOrigin` isn't right for
this — on native builds it resolves to the *API server's* origin (the
dart-define `API_BASE_URL`), not wherever the web frontend happens to be
hosted. Added a separate `appOrigin` getter (`kIsWeb ? Uri.base.origin :
apiOrigin`) specifically for this case (used to build the `/join/<id>`
invite link). Native's fallback to `apiOrigin` is a known-imperfect guess
— there's no reliable way for a native client to know the web frontend's
address without new configuration — acceptable since invite-link
generation is a web-first flow in practice. If a native "generate invite
link" flow becomes real usage rather than incidental, this will need an
actual configured frontend base URL rather than a guess.

### "GarajOS" gamified dark theme (v0.8.0)

The Material theme (`core/theme/app_theme.dart`) and several screens were
replaced with a dark "garage" redesign Farzad supplied as a set of
ready-to-drop-in Dart files (originally `Desktop\logs\GarajOS gamified
redesign.zip`). `AppTheme.dark()` is now the actual theme (`app.dart` sets
`themeMode: ThemeMode.dark`); `AppTheme.light()` still exists but is dead
code unless that's changed back to `ThemeMode.system` — it was **not**
restyled to match, so don't rely on it looking finished.

**Fonts — use `AppFonts`, never a raw `fontFamily: 'X'` string.** The
supplied files reference `'Montserrat'`/`'Poppins'`/`'RobotoMono'` as literal
strings; those aren't fonts Flutter has anywhere unless something actually
registers them, so every literal reference would silently fall back to the
platform default. `google_fonts` was added and `AppFonts.header()` /
`.body()` / `.mono()` (`core/theme/app_theme.dart`) wrap the corresponding
`GoogleFonts.montserrat/poppins/robotoMono` calls — every text style that
needs one of these three typefaces should go through `AppFonts`, not a
string literal, or it'll silently render in the wrong font with no error.

**Gamified widgets** (`core/widgets/`): `StreakBadge`, `ProfileCompletenessBar`,
`PitStopStepper` are wired into real screens (AppBar, Client/Vehicle forms,
work order detail respectively — see CHANGELOG v0.8.0). `TopWrenchLeaderboard`
is **not** wired anywhere — `work_orders` has no assigned-mechanic/technician
column, so there's no real per-mechanic data to group by. Don't fake data
into it to make it "look done"; wire it up once that column exists (would
need a migration + `createWorkOrder`/`updateStatus` changes + a new reports
query grouping paid work orders by assignee).

**Streak is real data, not a mock** (fixed the supplied `const streakDays =
12;` placeholder): `streakDaysProvider`
(`features/reports/application/reports_provider.dart`) counts consecutive
days, ending today, with at least one work order marked `paid` — derived
from the same day-grouped `/reports/revenue` endpoint the Reports screen
uses, independent of that screen's own date-range filter. It's a client-side
computation over the last 60 days of daily points, not a dedicated backend
endpoint; if a longer lookback or a backend-computed streak is ever needed,
add a real endpoint instead of widening the client-side window indefinitely.

**Localized in v0.9.0:** the gamification copy ("Garage Completeness",
"Fully tuned! 🔧", "THE PIT STOP", "DAY STREAK") and `client_form_sheet.dart`
(which had *no* localization at all when this section was first written) are
now fully wired to `AppLocalizations`, in both languages and both voice
tones — see the i18n section above.

### Bottom sheets must wrap their content in `SingleChildScrollView` — standing rule (v0.16.9)

Hit in practice (pilot user report): `vehicle_form_sheet.dart`,
`client_form_sheet.dart`, and `catalog_item_form_sheet.dart` all rendered
their `Form` as a plain `Column` with no scrollable ancestor. This is a
trap specific to `showModalBottomSheet(isScrollControlled: true, ...)`:
`isScrollControlled` only lets the *sheet* grow up to the screen's height —
it does nothing to make oversized *content* inside it scrollable. On any
viewport too short for the field count (a smaller monitor, a tablet, a
phone, or the same screen with the keyboard open), the Column overflows
past the visible area and whatever's at the bottom — always the Save
button, since that's always the last child — becomes physically
unreachable. No error, no visual warning in a release build; it just
silently clips.

The vehicle sheet was the one actually hit (10 fields + a
`ProfileCompletenessBar`, the tallest of the three), but all three sheets
had the identical structural bug — this is a property of the wrapper
pattern all master-data quick-create sheets share, not something specific
to vehicles. Fixed by wrapping each `Form` in a `SingleChildScrollView`:

```dart
return Padding(
  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Form(...),
  ),
);
```

Keep the keyboard-avoidance (`viewInsets.bottom`) padding on the *outer*
`Padding`, not inside the scroll view — that's what makes the whole
scrollable area shift up correctly when the on-screen keyboard opens,
rather than getting stuck inside the scroll view's own fixed padding.

**Standing rule: any new `showModalBottomSheet` with form content —
current or future — must wrap that content in a `SingleChildScrollView`
from the start**, not added reactively once a field count grows enough to
overflow on someone's actual device. This class of bug is invisible on a
developer's own full-height monitor and only shows up on whatever
smaller screen a real user happens to be on — exactly how this one
shipped unnoticed across three sheets and multiple field-count increases
(the vehicle sheet grew from a handful of fields to ten over several
versions, see the Şasi No./Motor No./Renk addition in v0.15.0) before a
pilot user actually hit it. Audited every other dialog in the app at the
same time (team invite dialog, payment-method picker, delete/rollback
confirmations) — those are short, fixed-content dialogs, not growing
forms, and aren't at the same risk; no changes needed there, but the
audit is what confirms this was a targeted fix, not a guess.

### Master-data search-autocomplete pattern (v0.16.0)

Farzad set a standing architectural/UI-UX standard for every master-data
field (client, vehicle, catalog item, and any future one like this) in a
transaction form: a debounced search-as-you-type `Autocomplete`, cross-field
auto-fill on selection, and an inline quick-create fallback — not a static
dropdown fed by a fully-loaded list. First applied to the Work Order form's
header (client + vehicle) and line items (catalog picker); apply the same
pattern by default to any new or refactored master-data field, without
being re-asked.

**The reusable widget** (`core/widgets/search_autocomplete_field.dart`)
wraps Flutter's `Autocomplete<T>`, which supports an async
`FutureOr<Iterable<T>> Function(TextEditingValue)` options builder but has
**no built-in debouncing** — every keystroke calls it immediately. The
widget adds its own `Timer`-based debounce (300ms default) inside that
builder: cancel any pending timer, start a new one, and return a
`Completer`'s future that only resolves once the timer actually fires.
`Autocomplete`'s own internal "is this still the current query" guard
(matching against `RawAutocomplete`'s current text) handles discarding
stale in-flight results if a newer keystroke supersedes an older one —
the widget doesn't need to re-implement that race protection itself.

**Quick-create is modeled as a sentinel option, not a separate UI element.**
Internally the widget's options list is `_Option<T>` (either a real result
or an `isCreateNew` marker), not `T` directly — `Autocomplete<_Option<T>>`
is what's actually instantiated. This lets the "+ Add new..." row live
inside the same dropdown, selected through the same `onSelected` codepath
as a real result, rather than a second onTap handler bolted on
separately. **Deliberate choice: the create-new row is always appended
once the minimum character count is reached, even when real matches
exist** — not only on zero results. Reasoning: a shop may have two clients
with similar names, and hiding the "add new" affordance whenever *any*
match exists would force a workaround (clearing the field, retyping something
slightly different) just to reach a legitimately new record. This mirrors
Notion/Linear-style "Create new..." rows, not a traditional empty-state-only
pattern — worth knowing before "simplifying" it to only show on zero
matches.

**Cross-field auto-fill needs the *other* field's live `TextEditingController`,
which `Autocomplete` doesn't expose by default.** The widget's
`fieldViewBuilder` callback receives that controller on every build; the
widget captures it into an instance field (`_fieldController`) and exposes
`setText`/`clear` methods, reachable from a parent via
`GlobalKey<SearchAutocompleteFieldState<T>>`. This is how the work-order
form's vehicle field can push a value into the client field's box (and vice
versa for clearing) without either widget knowing about the other directly.

**Vehicle selection is authoritative over client selection, not the other
way round.** A license plate uniquely determines its owner, so picking a
vehicle always overwrites whichever client is currently shown (fetching the
full `Client` via `GET /clients/:id` only if it isn't already the one
selected, to avoid an extra round-trip on the common case). Picking a
*client* only clears an already-selected vehicle if it belongs to someone
else — it doesn't try to guess a replacement. `createWorkOrder` also now
verifies server-side that the submitted vehicle actually belongs to the
submitted client (previously only checked each independently belonged to
the shop) — a backstop for this auto-sync, not a fix for an observed bug.

**Backend: dedicated `/search` endpoints, not the existing paginated `list`
endpoints with a small `pageSize`.** `listClients`/`listVehicles` both run
an extra `COUNT(*)` query for pagination that a debounced, throwaway-per-
keystroke search doesn't need — `searchClients`/`searchVehicles`/
`searchCatalogItems` (in each module's `.service.ts`) are separate,
smaller queries: capped (10–15 rows), no count, ILIKE across the relevant
columns, `q.length >= 2` enforced via Zod too (defense-in-depth, in case
something calls the endpoint directly rather than through the debounced
widget). Routes: `GET /search` **must be registered before `GET /:id`** in
each `*.routes.ts` — Express would otherwise match `/search` as an `:id`
value. `searchVehicles` joins `clients` for `client_name` so the frontend
can show/auto-fill the owner without a second request; `searchCatalogItems`
filters `is_active = true` since deactivated items (soft-deleted because
they're referenced by an existing work order — see `deleteCatalogItem`)
shouldn't be pickable into a *new* one.

**Fully rolled out as of v0.16.1**: every master-data picker in the app now
uses this pattern — `vehicle_form_sheet.dart`'s "owner" field was the last
static dropdown, converted alongside the Work Order form. It has two
callers with different starting knowledge, handled via two paths:
- **Already have the `Client` object** (the work-order form's vehicle
  quick-create, which already holds `_selectedClient`) — pass it as the new
  `presetClient: Client?` parameter on `showVehicleFormSheet`; the sheet
  uses it directly as `initialText`, no fetch needed.
- **Only have an id** (editing an existing vehicle — only `clientId` is on
  the `Vehicle` model; or the Vehicles screen's `presetClientId: String?`
  route param) — the sheet fetches the name itself via one `GET
  /clients/:id` in `initState` (`Future.microtask`, not blocking first
  frame) and pushes it in via `setText()` once resolved, same imperative
  mechanism as the cross-field auto-fill above. A failed fetch leaves the
  field blank but keeps `_clientId` set, so submitting with the unchanged
  owner still works — it doesn't block the form on a transient network
  error.

This is also why `allClientsProvider` (previously used to feed both this
dropdown and the work-order form's old client dropdown) and the
`failedToLoadClients`/`failedToLoadVehicles` ARB keys (used by their
`.when(error: ...)` branches) were removed in v0.16.1 — check before
resurrecting either as a "quick fix" for some other screen; the search
endpoint is the intended replacement now.

**Not every field fits the "real entity with an id" shape — make/model
(v0.16.2) are the exception, and show what to do when a field is closer to
free text than a master-data record.** `vehicles.make`/`model` are plain
`VARCHAR` columns, not foreign keys into any table — there's no id to
select, and thus nothing a "quick-create" modal would meaningfully add
beyond the text already typed. Rather than inventing a `vehicle_makes`/
`vehicle_models` reference table (a bigger, harder-to-justify addition —
no canonical brand/model dataset is bundled, and a shop's real vehicles
are a perfectly good, self-maintaining source of suggestions), the
existing `vehicles` table itself is the source: `GET
/vehicles/makes/search?q=` and `GET /vehicles/models/search?q=&make=`
return `SELECT DISTINCT` values (grouped + counted, most-frequent first)
from the shop's own rows — no new table, no migration beyond two new
`pg_trgm` indexes. Consequences of this shape worth knowing:
- **A brand-new shop sees zero suggestions until its first vehicle is
  entered.** This is expected, not a bug — the list is self-bootstrapping
  from real data, not seeded from a static reference list.
- **`onCreateNew` needs no modal.** It's `(typedText) async => typedText`
  — "creating" a make/model is just using the text you already typed, so
  the widget's existing create-new codepath (open a sheet, persist,
  return the result) collapses to an identity function.
- **The field's raw typed text is always what gets submitted, selection or
  not** — `_make`/`_model` are plain `String` state updated via a new
  `onChanged` passthrough on `SearchAutocompleteField<T>` (fires on every
  keystroke, unlike every other field's `onSelected`-only wiring), not an
  id captured only when a suggestion is tapped. A user who types a
  brand-new make and never taps anything still gets it saved correctly.
- **Selecting a Make clears an already-typed Model** (same reasoning as
  vehicle-clears-on-client-change in the work-order form: a Model typed
  for the old Make is likely wrong for the new one) — **but only on
  selection, not on every keystroke** of Make, or Model would be wiped
  mid-typing every time Make's text changes. `onChanged` and `onSelected`
  intentionally do different things here.

**Trigram indexes added for substring search** (`db/init/012_search_indexes.sql`):
`vehicles.license_plate` and `catalog_items.name`/`sku` had no `pg_trgm`
GIN index before this (only `clients.full_name` did, from
`002_clients.sql`), so `ILIKE '%term%'` on those columns was a sequential
scan. `pg_trgm` was already enabled (`000_extensions.sql`). Like every
`db/init/*.sql` file, this only runs automatically on a brand-new Postgres
volume — apply it by hand against an already-provisioned database (dev or
prod) per the pattern in the DevOps section below.

---

## DevOps

### Docker Compose services — two fully separate compose files, no default (v0.15.1)
There is **no `docker-compose.yml`** in this repo — only `docker-compose.dev.yml`
and `docker-compose.prod.yml`, both requiring an explicit `-f`. This was a
deliberate rename (from a plain `docker-compose.yml` that used to serve as
the dev config and the implicit default). **Why:** on 2026-08-06 Farzad's
manual-deploy batch script ran a bare `docker compose up -d --build` on the
production server — with no default file, Compose fell back to whatever
`docker-compose.yml` happened to resolve to, which was the *dev* config
(both files share the same `container_name`s). That would have replaced
the live prod containers with dev-networked ones: `web` moving off
`127.0.0.1:8083` (what the Cloudflare Tunnel targets — site goes down) and
`api` moving from unpublished to `0.0.0.0:3000` (exposed outside Docker).
Caught in review before it was actually run. Removing the implicit default
entirely means the same mistake now fails loudly (`no configuration file
provided`) instead of silently doing the dangerous thing — every command
in this repo's docs and scripts uses an explicit `-f docker-compose.dev.yml`
or `-f docker-compose.prod.yml` from here on; never re-add a bare
`docker-compose.yml`.

| Service (`docker-compose.dev.yml`) | Image | Port |
|---|---|---|
| `postgres` | `postgres:16-alpine` | `127.0.0.1:5432` (localhost only) |
| `api` | `autoservice-api` (built from `backend/`) | `0.0.0.0:3000` |
| `web` | `nginx:1.27-alpine` | `0.0.0.0:8080` |

The `web` service is optional and requires a prior `flutter build web` in
`frontend/`. The built output at `frontend/build/web/` is mounted read-only
into nginx.

### Rebuilding after code changes
- **Backend change:** `docker compose -f docker-compose.dev.yml up -d --build api`
- **Frontend change:** `flutter build web --release` → `docker restart repairshop_web`
- **`.env` change:** `docker compose -f docker-compose.dev.yml up -d --force-recreate <service>` (a
  simple `restart` does **not** re-read `.env` values baked into the container
  at creation time)

### Persistent data
PostgreSQL data lives in the `pgdata` named Docker volume. To fully reset the
database (e.g. after a password change):
```bash
docker compose -f docker-compose.dev.yml down -v   # removes containers AND the pgdata volume
docker compose -f docker-compose.dev.yml up -d --build postgres api
```

### Production deployment (`docker-compose.prod.yml`, v0.13.0)

Production (a Windows home server behind an existing Cloudflare Tunnel,
domain `www.garajos.com.tr`) uses a **separate, fully self-contained**
`docker-compose.prod.yml` rather than a merge-overlay on top of
`docker-compose.dev.yml`. An overlay was tried first, using Compose's
`!reset`/`!override` YAML merge tags to drop the `api` service's `ports:`
key and swap `web`'s bind-mounted build output for an image build — but
list-merge behavior across Compose versions (whether `ports`/`volumes` are
replaced vs. concatenated by an override file, and which Compose version
actually supports `!reset`) was uncertain enough to be a real footgun in a
guide meant to be followed by hand. A standalone file with zero merge
semantics is more verbose but unambiguous on any Compose version.

Prod differs from dev in three deliberate ways:
- **`api` publishes no host port at all** (dev publishes `0.0.0.0:3000`).
  Only `web`'s nginx reaches it, over the internal `repairshop_net`
  network at `http://api:3000` — nothing outside Docker needs to hit the
  API directly in prod.
- **`web` binds to `127.0.0.1:8083`**, not `0.0.0.0:8080`. Loopback-only:
  reachable by the Cloudflare Tunnel process running on that same host,
  unreachable from any other device on the home LAN. Port `8083` (not
  `8080`) was a deliberate choice to avoid any confusion with the dev
  box's LAN port — they're different machines, but keeping the numbers
  distinct avoids muscle-memory mistakes when working across both.
- **`web` builds from a new `frontend/Dockerfile`** (two-stage:
  `ghcr.io/cirruslabs/flutter:stable` → `nginx:1.27-alpine` runtime,
  mirroring the pattern `backend/Dockerfile` already used) instead of
  requiring a manually-run `flutter build web --release` on the host.
  The production host has no Flutter SDK installed. **Gotcha:** the
  Dockerfile does *not* `COPY` `nginx.conf` into the image — Docker's
  `COPY` can only read files inside its own build context (`./frontend`),
  and `nginx.conf` lives in the repo's `nginx/` directory, outside that
  context. `nginx.conf` is instead supplied at container-start via the
  same bind mount dev already uses
  (`./nginx/nginx.conf:/etc/nginx/conf.d/default.conf:ro`), which also
  means nginx config changes don't require rebuilding the frontend image.

**Confirmed by an actual deployment run (2026-08-03):** `docker compose -f
docker-compose.prod.yml up -d --build` built all three containers
successfully on the target home server with no Flutter installed on it —
validating the `frontend/Dockerfile` approach above as the real, working
path, not just a theory.

Two things from the original guide draft didn't hold up in practice and
were corrected:
- **`docker run --rm node:20-alpine node -e "..."` (suggested for
  generating `JWT_SECRET`/`DB_PASSWORD`) errored out on this server** —
  likely a Docker Hub pull/network restriction, not investigated further.
  Replaced with a PowerShell-native one-liner
  (`[System.Security.Cryptography.RNGCryptoServiceProvider]` →
  `[Convert]::ToBase64String`), which needs nothing beyond PowerShell
  itself. `DB_PASSWORD` ended up hand-picked rather than generated, which
  is fine and arguably simpler — just keep it alphanumeric-only per the
  `#`-in-URL gotcha above.
- **Git and Flutter were not preinstalled on the server.** Git: `winget
  install --id Git.Git -e --source winget` worked. Flutter: not required
  for the Docker-build path, but a native-install PowerShell script (fixed
  version download URL, unzip to `D:\Flutter`, add to machine `PATH`) was
  tested and works, kept in the guide as an optional fallback/
  troubleshooting path (Option B) in case the Docker build ever struggles
  on lower-powered hardware.

The actual project root ended up at `D:\apps\GarajOS\garajos` (an extra
`GarajOS` level above the cloned repo folder), not the flat `D:\apps\garajos`
an earlier draft assumed — every path in the guide was corrected to match.

Full step-by-step deployment guide (server prerequisites, secret
generation, pointing the existing Cloudflare Tunnel's ingress rule at
`127.0.0.1:8083`, backup/restore commands, troubleshooting) lives outside
this repo at
`C:\Users\Farzad\Desktop\logs\garajos-production-deployment-guide.md` —
not checked in since it contains a specific deployment topology, not
general project documentation. As of 2026-08-03 it reflects the
corrections above and matches a real, working deployment.

### Applying a new `db/init/*.sql` migration to prod
`db/init/*.sql` files only run automatically the *first* time Postgres
creates its data directory on a brand-new, empty volume — restarting or
rebuilding containers on an already-provisioned database (prod's, always)
does **not** re-run them. Any new migration (e.g. `011_vehicle_
identifiers.sql`, adding `chassis_no`/`engine_no`/`color` to `vehicles`)
must be applied by hand, once, against the prod container:
```bat
docker exec -i repairshop_db psql -U repairshop_admin -d repairshop < db\init\0NN_new_thing.sql
```
(swap `repairshop_admin`/`repairshop` if prod's `.env` overrides those).
Re-running an already-applied `ADD COLUMN` migration will error — it's not
idempotent, so this is a one-time step per migration, not something to
fold into the routine deploy script.

### `ProdRelease.bat` — manual deploy script, and a Windows batch gotcha (v0.15.2, 2026-08-06)
Farzad's own deploy script (kept outside the repo at
`Desktop\logs\ProdRelease.bat`, not checked in — same reasoning as the
guide above) runs, in order: `git pull origin main` → `flutter build web
--release` (host-side; see caveat below) → `docker compose -f
docker-compose.prod.yml up -d --build` → `docker compose -f
docker-compose.prod.yml ps` to confirm. It self-elevates via UAC
(`net session` check + `Start-Process -Verb RunAs`) and writes a
timestamped log file next to itself.

**Gotcha that cost real debugging time:** `flutter` on Windows is
`flutter.bat`, not a native `.exe`. Invoking a `.bat`/`.cmd` from inside
another `.bat` **without the `call` keyword** can hand control to it and
never return — if the inner script's own chain ends with a plain `exit`
anywhere (common in multi-layer tool wrappers like Flutter's), it
terminates the *entire parent process*, not just that step. Symptom: the
build would finish successfully, print "Built for web", and the whole
terminal window would close instantly with zero error output — visually
indistinguishable from a crash or hang, and cost several rounds of
misdiagnosis (self-elevation breaking PATH, Docker Desktop cold-start
timing, browser caching) before the missing `call` surfaced as the actual
cause. **Rule for any future Windows batch tooling in this project: always
`call` another `.bat`/`.cmd` invoked from inside a `.bat`.** `git` and
`docker` are native `.exe`s and are unaffected — this is specific to tools
like Flutter that ship a `.bat` entry point on Windows.

The host-side `flutter build web --release` step is being kept
deliberately even though it shouldn't be load-bearing — prod's `web`
service already builds the frontend from scratch *inside* Docker
(`frontend/Dockerfile`). Farzad reported a deploy without it didn't show
the latest frontend changes; leading suspect is the browser-caching gotcha
above (`main.dart.js` has no cache-busting hash), not an actually-stale
Docker image, but this wasn't re-investigated — kept as a deliberate,
explicit trade-off (~3 extra minutes per deploy) rather than spending more
time on it. Don't re-open this unprompted.

**First real production deploy of v0.14.0–v0.15.1 happened 2026-08-06**,
after the `call` fix: both images rebuilt (`garajos-api`,
`garajos-web:prod`), all three containers came up, and the
`011_vehicle_identifiers.sql` migration was applied by hand per the
section above. **Open item, not yet confirmed resolved:** `docker compose
-f docker-compose.prod.yml ps` showed `repairshop_web` bound to
`0.0.0.0:8083` instead of the intended loopback-only `127.0.0.1:8083`.
The committed compose file is correct, so this points at a leftover local
modification to `docker-compose.prod.yml` on the server — Farzad had
briefly renamed it to `docker-compose.yml` earlier that day while working
around the `-f` flag issue below, then reverted; that revert may not have
fully restored the original content. Check with `git status`/`git diff
docker-compose.prod.yml` on the server; if modified, `git checkout --
docker-compose.prod.yml` and redeploy.

**Second production deploy, v0.16.0–v0.16.5, confirmed working (2026-08-06):**
Farzad deployed the master-data search-autocomplete rollout (client/vehicle/
catalog/make/model Autocomplete + quick-create), the temporary VAT/discount
hide, the blank-line-item fix, and the guided-data-entry hints — reported
back "it is perfect." Both new migrations since the first deploy,
`012_search_indexes.sql` and `013_vehicle_make_model_indexes.sql` (`pg_trgm`
indexes only, no data changes), were applied by hand per the pattern above.
**The "add new" button consistency fix (v0.16.6, commit `778e1ac`) landed
*after* this deploy and is not yet live** — still just on `main`/dev as of
this writing; don't assume it's in prod until the next deploy confirms it.
The `repairshop_web` port-binding open item from the first deploy (see
above) was not investigated or mentioned again this round — still an open
question, not confirmed resolved either way.

**Earlier the same day, a near-miss was caught before it ran:**
`ProdRelease.bat` originally ran a bare `docker compose up -d --build`
(no `-f` flag). Since dev and prod compose files shared identical
`container_name`s, that would have resolved to whichever file was named
`docker-compose.yml` and replaced the live prod containers with
dev-networked ones (`web` off `127.0.0.1:8083`, breaking the Cloudflare
Tunnel; `api` exposed on `0.0.0.0:3000` instead of unpublished). This is
the reason `docker-compose.yml` was renamed to `docker-compose.dev.yml`
repo-wide (v0.15.1, see the Docker Compose services section above) —
removing the implicit default entirely so the same mistake now fails
loudly instead of silently doing the dangerous thing.

---

## Known Limitations / Future Work

| Area | Issue | Suggested Fix |
|---|---|---|
| RLS not enforced | Table-owner DB role bypasses RLS; app-level `shop_id` filtering (added in v0.5.0) is the only real tenant isolation right now | `FORCE ROW LEVEL SECURITY` + non-owner app role, plus rework `register`/`login` (see Database section above) |
| Catalog item ownership on work orders | `work_order_items.catalog_item_id` isn't verified to belong to the caller's shop when a work order is created | Add the same ownership check used for `clientId`/`vehicleId` in `createWorkOrder` |
| HTTPS | Dev/LAN still runs over plain HTTP; Web Crypto unavailable on LAN | Resolved for production as of v0.13.0 — TLS terminates at Cloudflare's edge in front of the home-server deployment. Dev/LAN access is unaffected and stays plain HTTP. |
| Token storage (web) | `localStorage` is readable by JS (XSS risk) | Acceptable for internal LAN; switch to `flutter_secure_storage` when HTTPS is available |
| Work-order numbering | Global sequence, not per-shop | Add `shop_counters` table with advisory lock |
| Role-based UI | Schema supports owner/manager/technician but UI doesn't restrict by role | Add `canManage` guards to edit/delete actions |
| Testing | No automated tests exist | Add `jest` + `supertest` for backend; `flutter_test` for frontend |
| CI/CD | No pipeline | Add GitHub Actions: lint → test → build → deploy |
| i18n | Only English and Turkish supported | Add new ARB file + locale entry (see i18n section above) |
