# AutoService — Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [0.16.12] — 2026-08-07  *(Turkish-Format Plate Display — Read-Only Only)*

### Added
- **Every read-only display of a license plate now shows it with the
  standard Turkish spacing** (`34ABC123` → `34 ABC 123`) — the vehicles
  list, the global search bar's vehicle results, the vehicle history
  screen's heading, the work-orders list, the work order detail panel, the
  work order form's edit-mode header, the vehicle Autocomplete's picker
  text in the work order form, and the printed PDF.
  - New `formatPlateDisplay` helper
    (`frontend/lib/core/utils/plate_formatter.dart`, mirrored in
    `workOrders.pdf.ts` for the backend-rendered PDF) matches the general
    digits-letters-digits shape of a Turkish plate (2 digits, 1–3 letters,
    2–4 digits) and inserts spaces at the boundaries. Deliberately doesn't
    validate the exact official letter/digit-count combination — a plate
    that doesn't fit the general shape (a foreign plate, unusual data)
    prints/displays completely unchanged rather than being force-fitted.
  - **Display only, confirmed nowhere near an editable value:** the
    "Plaka" input field's seeded/submitted value, all search-query text,
    and everything stored in the database stay exactly as they were
    (uppercase, no spaces) — formatting is applied only at the final
    `Text(...)`/PDF-render call site, never to state that flows back into
    a form field or an API request. Verified directly: editing a vehicle
    whose plate displays as "34 ABC 123" shows the raw "34ABC123" in the
    actual Plaka field.
  - One real edge case closed proactively: the work order form's vehicle
    picker can seed a *different* editable field — the quick-create
    vehicle sheet's own Plaka input — with whatever text is currently
    typed/selected in the picker (`initialPlate`, via `onCreateNew`).
    Since the picker's own display text is now formatted, that hand-off
    now strips spaces before seeding the editable field, so formatting
    can never leak into an edit context even through that indirect path.
  _Files: `frontend/lib/core/utils/plate_formatter.dart` (new),
  `backend/src/modules/workOrders/workOrders.pdf.ts`,
  `frontend/lib/core/widgets/global_search_bar.dart`,
  `frontend/lib/features/vehicles/presentation/{vehicles_screen,vehicle_history_screen}.dart`,
  `frontend/lib/features/work_orders/presentation/{work_orders_master_list,work_order_detail_panel,work_order_form_screen}.dart`_

---

## [0.16.11] — 2026-08-07  *(Optional Client Link — Walk-In Vehicles and Work Orders)*

### Added
- **A vehicle no longer requires a linked client, and a work order no
  longer requires a linked client either** — a real gap for this
  business: many walk-in customers never give contact details, only the
  car. The license plate (already the shop's real per-vehicle identity
  key — `vehicles` already had `UNIQUE (shop_id, license_plate)`) is now
  genuinely the only mandatory identifier; the client link is optional
  everywhere it touches.
  - `vehicles.client_id` and `work_orders.client_id` both changed from
    `NOT NULL` to nullable (`db/init/016_optional_client_link.sql`) —
    purely additive, no data loss, every existing row already had one.
  - Vehicle form's "Sahip" (owner) field has no validator anymore — can
    be left blank on create or edit. Work order form's client field lost
    its validator too; only the vehicle field (and its unique plate) is
    still required to create a work order.
  - **A client can still be attached to a walk-in vehicle at the work
    order level, independent of the vehicle's own record** — selecting a
    client while a client-less vehicle is already picked doesn't clear
    the vehicle, and doesn't retroactively rewrite the vehicle's stored
    owner. This is deliberate: "the customer identified themselves this
    time" shouldn't require editing the vehicle master record.
  - Every place that displayed a client name now falls back to "Walk-in
    Customer" / "Kayıtsız Müşteri" instead of a raw client UUID (or
    crashing) when there isn't one: the work-orders list, the detail
    panel, the printed PDF.
  - Four `JOIN clients` became `LEFT JOIN` (work order list, work order
    detail, the printed PDF, vehicle search, and the global search bar's
    order-number lookup) — an inner join would have silently hidden every
    walk-in record from search results and lists the moment this shipped.
  _Files: `db/init/016_optional_client_link.sql`,
  `backend/src/modules/vehicles/vehicles.{schema,service}.ts`,
  `backend/src/modules/workOrders/workOrders.{schema,service,pdf}.ts`,
  `backend/src/modules/search/search.service.ts`,
  `frontend/lib/features/vehicles/data/vehicle_model.dart`,
  `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/features/work_orders/data/work_order_model.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_detail_panel.dart`,
  `frontend/lib/features/work_orders/presentation/work_orders_master_list.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_
- **The existing vehicle/client-ownership consistency check in
  `createWorkOrder` still applies, narrowed correctly**: submitting a
  `clientId` that genuinely conflicts with a vehicle's own *set* owner is
  still rejected (400) exactly as before — the check simply no longer
  fires when either side has no owner to conflict with. Verified both
  paths directly against the API: a real mismatch still 400s, and
  attaching a client to a previously client-less vehicle succeeds without
  touching the vehicle's own `client_id`.

---

## [0.16.10] — 2026-08-07  *(Editable Service Date — Backdated Slips, List Shows Date Instead of Order #)*

### Added
- **Work orders now carry an editable "Servis Tarihi" (service date),
  settable on creation and while editing a draft — including backdating
  to enter a repair that happened before today.** Requested by the pilot
  user, who needed to log older jobs accurately rather than have every
  slip dated "today."
  - New `work_orders.service_date` column (`DATE`, `db/init/015_*.sql`) —
    deliberately separate from `created_at`, which stays a pure,
    never-edited system audit timestamp (when the row was inserted).
    `service_date` is the business-meaningful date: what prints on the
    slip, what the customer sees, what the shop actually backdates.
  - Date field placed right above "Servis kilometresi (km)" in the work
    order form (both create and edit), a standard Material date picker
    capped at today (`lastDate: DateTime.now()`) — no future-dated
    service records.
  - **The printed PDF and the detail panel's "Tarih" line now show
    `service_date`, not `created_at`** — both previously displayed the
    system insert timestamp as a stand-in for "the date," which is
    exactly the gap this feature closes. A backdated slip now actually
    prints the backdated date.
  - **The work-orders list now sorts by `service_date DESC` instead of
    `created_at DESC`.** Necessary, not optional: without this, a
    backdated entry would still appear at the top of the list (newest
    inserted) while displaying an old date next to it — defeating the
    entire point of backdating. Verified: creating a today-dated order
    after an already-backdated one still shows the backdated one lower
    in the list, correctly.
  _Files: `db/init/015_work_order_service_date.sql`,
  `backend/src/config/db.ts`,
  `backend/src/modules/workOrders/workOrders.{schema,service,pdf}.ts`,
  `frontend/lib/core/utils/date_formatter.dart` (new),
  `frontend/lib/features/work_orders/data/work_order_model.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_

### Changed
- **The work-orders list no longer shows the `#N` order number — it shows
  the client name as the title and the service date alongside the plate
  in the subtitle instead** (per the pilot user's request). The order
  number itself is untouched everywhere else (detail panel title, edit
  title, the printed PDF, the rollback audit trail) — this is a display
  change on one screen, not a removal of the underlying `order_no`
  column or its other uses.
  _File: `frontend/lib/features/work_orders/presentation/work_orders_master_list.dart`_

### Fixed / avoided
- **A server-timezone default would have silently misdated orders
  created between local midnight and 3am.** This app is Turkey-only
  (UTC+3); the backend container likely runs in UTC regardless of host
  timezone. `serviceDate` is therefore a *required* field on create — no
  server-side "default to today" — so the frontend, which actually knows
  the device's local date, always supplies it explicitly. See
  DECISIONS.md for the full reasoning and the matching DATE type-parser
  decision that keeps this column a plain string end-to-end rather than
  round-tripping through JS/Dart `Date`/`DateTime` objects (a second,
  related timezone-shift trap this avoids by construction).

---

## [0.16.9] — 2026-08-07  *(Fix — Quick-Create Sheets' Save Button Unreachable on Short Screens)*

### Fixed
- **The Vehicle/Client/Catalog quick-create sheets (opened inline from any
  master-data search field — most commonly the Work Order form's "+ Add
  new vehicle" flow) could push their Save button off the bottom of the
  screen with no way to reach it**, reported by the pilot user: creating a
  new car while building a work order left Save below the fold, and the
  sheet had no scrolling. Root cause: all three sheets
  (`vehicle_form_sheet.dart`, `client_form_sheet.dart`,
  `catalog_item_form_sheet.dart`) rendered their fields in a plain
  `Column` with no scrollable ancestor — `showModalBottomSheet`'s
  `isScrollControlled: true` only lets the sheet *grow* up to the screen
  height, it doesn't make oversized *content* scrollable. On any
  viewport short enough that the field count didn't fit (smaller
  monitors, tablets, phones — and worse with the on-screen keyboard
  open), the Column simply overflowed past the visible area with the
  Save button unreachable. The vehicle sheet was the worst case (10
  fields + a completeness bar) and the one actually hit, but all three
  had the identical structural bug.

  Fixed by wrapping each sheet's `Form` in a `SingleChildScrollView`
  (kept the existing keyboard-avoidance `viewInsets.bottom` padding on
  the outer `Padding`, moved the fixed 20px content padding onto the
  scroll view itself) — content taller than the available space now
  scrolls instead of clipping. Verified by reproducing the exact
  reported flow (Work Order form → quick-create client → quick-create
  vehicle) against a viewport short enough that the fully-filled vehicle
  sheet's Save button sat below the fold, confirming it scrolls into
  reach and the save completes correctly.

  Audited every other dialog/bottom sheet in the app for the same
  structural risk (team invite dialog, payment-method picker, delete/
  rollback confirmations, the unsaved-changes dialog) — all are short,
  fixed-content dialogs, not at risk the way a growing form is. No
  changes needed there, but worth knowing this class of bug was checked
  project-wide, not just patched where it was reported.
  _Files: `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/features/clients/presentation/client_form_sheet.dart`,
  `frontend/lib/features/catalog/presentation/catalog_item_form_sheet.dart`_

---

## [0.16.8] — 2026-08-07  *(Owner/Manager Rollback — Revert Paid/Completed Orders Back to Draft)*

### Added
- **Owners and managers can now roll a `paid` or `completed` work order back
  to `draft`**, straight to draft rather than through the intermediate
  step — the one deliberate, audited exception to the otherwise forward-only
  `draft -> completed -> paid` status machine
  (`workOrders.service.ts`'s `ALLOWED_TRANSITIONS`). A typed reason (3+
  characters) is required and every rollback is permanently logged.
  - New `PATCH /api/v1/work-orders/:id/rollback` endpoint,
    `authorize("owner", "manager")`-gated — the same bar as editing/
    deleting a draft, not the stricter owner-only bar first floated during
    design (see DECISIONS.md). Clears `paymentMethod`/`completedAt`/
    `paidAt` and returns the order to `draft`, re-opening its line items
    for editing; `subtotal`/`discountAmount`/`taxRate`/`taxAmount`/
    `grandTotal` are left untouched.
  - New `work_order_rollbacks` audit table
    (`db/init/014_work_order_rollback_audit.sql`) — one row per rollback,
    recording who, when, why, and a snapshot of everything being
    discarded. Deliberately survives deletion of the now-draft parent
    order (`ON DELETE SET NULL` + denormalized `order_no`/
    `performed_by_name`/`prior_*` columns) — verified by rolling an order
    back, deleting it, and confirming the audit row was still intact
    afterward.
  - **Detail panel** (`work_order_detail_panel.dart`) gained a "Taslağa
    Geri Al" text button below the Pit Stop stepper, shown only for
    `canManage` users on `paid`/`completed` orders — deliberately kept
    outside `PitStopStepper` itself so it doesn't read as a normal forward
    step. Confirmation dialog requires a typed reason before its confirm
    button enables (reactive via `ValueListenableBuilder` on the reason
    field's controller — an earlier draft of this dialog let the button
    submit with an empty reason and silently no-op, caught before
    shipping) and explicitly warns that the order will drop out of past
    revenue reports until re-marked paid.
  _Files: `db/init/014_work_order_rollback_audit.sql`,
  `backend/src/modules/workOrders/workOrders.{schema,service,controller,routes}.ts`,
  `frontend/lib/features/work_orders/data/work_orders_repository.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_detail_panel.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_

### Known, deliberate consequence — not a bug
- **Rolling back a `paid` order retroactively changes past revenue
  reports.** `reports.service.ts`'s revenue query filters on
  `status = 'paid' AND paid_at IS NOT NULL` — the moment either is
  cleared, the order silently disappears from whatever historical period
  it was previously counted in. This is why the confirmation dialog states
  it explicitly and why every rollback is audited with a mandatory reason;
  see DECISIONS.md for the full reasoning.

---

## [0.16.7] — 2026-08-07  *(Draft Protection — Warn Before Losing Unsaved Work-Order Edits)*

### Added
- **Leaving the New/Edit Work Order form with unsaved changes now prompts
  first**, instead of silently discarding whatever was typed — Farzad's
  request, to prevent accidental data loss from a stray back-gesture/back-
  button press. Covers the AppBar back arrow, Android hardware/gesture
  back, and Windows back, all of which route through the same
  `Navigator.maybePop()` path a `PopScope` intercepts.
  - New `_dirty` flag on `_WorkOrderFormScreenState`, flipped by a listener
    attached to every field controller (mileage, discount, tax rate,
    notes, and each line item's description/quantity/price) plus the
    client/vehicle-selection and add/remove-line-item callbacks — attached
    *after* the form's initial data is seeded, so a freshly opened form
    (including the one default blank line item every new order starts
    with, see v0.16.4) never starts dirty.
  - `PopScope(canPop: !_dirty, ...)` wraps the screen's `Scaffold`. A
    pristine form pops immediately with no interception; a dirty one opens
    a three-choice `AlertDialog` (same style as the existing delete
    confirmation in `work_order_detail_panel.dart`): **Lock In as Draft**
    (reuses the existing `_submit()` — every work order reachable from
    this form is already in `draft` status, editing is only reachable
    while `status == 'draft'`, so "saving as a draft" needed no new
    backend behavior at all), **Scrap the Changes** (pops with no backend
    call — an unsaved edit was never persisted, so there's nothing to
    revert), or **Cancel** (closes the dialog, stays on the form).
  - New ARB keys — `unsavedChangesTitle`, `unsavedChangesBody`,
    `saveAsDraft`, `discardChanges` — added to all four locale files.
  _Files: `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_

### Fixed
- **A naive reuse of the pop-blocking flag would have broken every normal
  save, not just the new exit-dialog flow:** `PopScope`'s `canPop: false`
  intercepts *any* pop attempt on the route — including the imperative
  `context.pop()` calls `_submit()` and the dialog's discard branch already
  make — not just user-initiated back gestures. Caught before it shipped:
  without clearing `_dirty = false` immediately before each of those
  `pop()` calls, a successful save (or a chosen discard) would have
  re-triggered the same unsaved-changes dialog instead of actually
  leaving, since the form was still technically "dirty" at the moment the
  pop ran.

---

## [0.16.6] — 2026-08-06  *("New" Button Consistency: AppBar, Not FAB)*

### Changed
- **The "add new" button on Servis Kaydı, Araçlar, Müşteriler, and Katalog
  is now a filled green `IconButton` in the AppBar, next to the title** —
  replacing two inconsistent patterns: Servis Kaydı's plain (unfilled, easy
  to miss) `IconButton`, and the other three screens' bottom-right
  `FloatingActionButton`. Farzad's desktop-UI feedback: the plain icon
  button on Servis Kaydı didn't stand out, and the FAB on the other three
  sat in the bottom-right corner, away from where attention naturally
  lands when a screen first loads — a mobile-first Material pattern that
  reads as out-of-the-way on a PC-sized viewport. One consistent,
  immediately-visible entry point across all four now, with a tooltip
  (e.g. "Yeni Araç") for hover clarity. Catalog's button keeps its
  existing `canManage`-only guard.
  _Files: `frontend/lib/features/work_orders/presentation/work_orders_master_list.dart`,
  `frontend/lib/features/vehicles/presentation/vehicles_screen.dart`,
  `frontend/lib/features/clients/presentation/clients_screen.dart`,
  `frontend/lib/features/catalog/presentation/catalog_screen.dart`_

---

## [0.16.5] — 2026-08-06  *(Guided Data Entry: Example Hints for Plate/Phone/Email)*

### Added
- **License plate, phone, and email fields now show a format example as
  hint text** (Flutter's `hintText`, revealed once the field's label
  floats on focus — an empty, unfocused field only shows the label, per
  standard Material behavior) — guides correct formatting without
  forcing it via an input mask, which would risk rejecting valid
  variations (Turkish plates alone have several valid letter/digit
  patterns). Added to: vehicle form's plate field; client form's phone +
  email fields; shop profile's contact phone + email fields. Login/
  register/join screens' email fields were deliberately left alone —
  those are "type your own known email," not a format someone needs
  taught. Phone/email fields also gained `keyboardType:
  TextInputType.phone`/`.emailAddress` for a better mobile keyboard while
  at it.
  _Files: `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/features/clients/presentation/client_form_sheet.dart`,
  `frontend/lib/features/shop/presentation/profile_screen.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_

---

## [0.16.4] — 2026-08-06  *(Fix: Leftover Blank Line Item on New Work Orders)*

### Fixed
- **New work order form always starts with one blank line item row, and
  picking from catalog (or clicking "Custom") added a *second* row instead
  of using it** — the blank first row's required Description then failed
  validation on save, forcing the user to notice and manually delete it
  every time before they could submit. `_addItem()` now checks whether the
  only row present is still that untouched blank default (empty
  description, no catalog link) and replaces it in place instead of
  appending; once any row has real content, further additions append
  normally. Applies to both the catalog-search field and the "Custom"
  button, since both hit the same helper.
  _File: `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`_

---

## [0.16.3] — 2026-08-06  *(Hide VAT/Tax and Discount, Temporarily)*

### Changed
- **Order-level VAT/tax and discount hidden throughout the app** — Farzad's
  request, a pricing simplification with no fixed end date ("we can view
  them again later"). Hidden, not removed: `discountAmount`/`taxRate`/
  `taxAmount` columns, `computeTotals`, and the grand-total math are all
  untouched — an existing work order with real historical tax/discount
  still computes and stores its grand total correctly, it just doesn't
  print the individual breakdown lines anymore. Gated behind a `const bool`
  flag per the established temporary-hide pattern (see DECISIONS.md's
  Internationalisation section for the precedent with the language toggle):
  - Frontend: `kOrderTaxAndDiscountVisible` in `feature_flags.dart` — hides
    the work order form's discount/tax rate input fields and its totals
    card's tax line, and the detail panel's discount/tax breakdown rows.
  - Backend: `ORDER_TAX_AND_DISCOUNT_VISIBLE` in a new
    `backend/src/config/featureFlags.ts` (no shared config between the two
    apps, so kept in sync by hand) — hides the same two lines on the
    printed PDF.
  _Files: `frontend/lib/core/config/feature_flags.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_detail_panel.dart`,
  `backend/src/config/featureFlags.ts`,
  `backend/src/modules/workOrders/workOrders.pdf.ts`_

---

## [0.16.2] — 2026-08-06  *(Vehicle Make/Model: Search-As-You-Type Suggestions)*

### Added
- **`vehicle_form_sheet.dart`'s "Marka"/"Model" fields** — now
  `SearchAutocompleteField<String>`, suggesting distinct make/model values
  already used elsewhere in the shop's own vehicles, most-frequent first;
  Model's suggestions are scoped to whichever Make is currently typed.
  Unlike client/vehicle/catalog, make/model aren't a separate entity with
  an id — there's nothing to "quick-create" beyond the typed text itself,
  so `onCreateNew` just returns the typed text directly (no modal), and the
  field's raw typed text is always the submitted value whether or not a
  suggestion was tapped. Picking a Make clears an already-typed Model
  (stale otherwise); typing doesn't, to avoid wiping Model mid-keystroke.
- **`SearchAutocompleteField<T>`** gained an optional `onChanged: void
  Function(String)?` passthrough for this — fields whose live typed text
  (not just a selected option) is itself meaningful.
- **New endpoints**: `GET /vehicles/makes/search?q=`, `GET
  /vehicles/models/search?q=&make=` — distinct values from the shop's own
  `vehicles` rows, no separate table. New `pg_trgm` indexes on
  `vehicles.make`/`model` (`db/init/013_vehicle_make_model_indexes.sql`) —
  neither column had any index before.
  _Files: `frontend/lib/core/widgets/search_autocomplete_field.dart`,
  `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/features/vehicles/data/vehicles_repository.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`,
  `backend/src/modules/vehicles/vehicles.{schema,service,controller,routes}.ts`,
  `db/init/013_vehicle_make_model_indexes.sql`_

---

## [0.16.1] — 2026-08-06  *(Vehicle Form's Owner Field: Same Autocomplete Pattern)*

### Added
- **`vehicle_form_sheet.dart`'s "owner" field** — the last remaining
  static-dropdown master-data picker (used both standalone on the Vehicles
  screen and as this pattern's own vehicle quick-create sheet) — converted
  to `SearchAutocompleteField<Client>`, same as the Work Order form's
  client/vehicle fields in v0.16.0. Editing an existing vehicle now fetches
  the owner's name asynchronously after the sheet opens (`GET
  /clients/:id`, once) rather than depending on a fully-loaded client list;
  a new optional `presetClient: Client?` parameter on `showVehicleFormSheet`
  lets a caller that already has the `Client` object (the work-order form's
  vehicle quick-create) skip that fetch entirely.
- **Cleanup**: `allClientsProvider` (now unused anywhere) removed from
  `clients_provider.dart`; the `failedToLoadClients`/`failedToLoadVehicles`
  ARB keys (unused since this and the v0.16.0 dropdown removals) removed
  from all four locale files.
  _Files: `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/features/clients/application/clients_provider.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_

---

## [0.16.0] — 2026-08-06  *(Work Order Form: Search-As-You-Type Autocomplete + Quick-Create)*

### Added
Established the standard pattern for every master-data field (client,
vehicle, catalog item, ...) across transaction forms: a debounced (300ms,
≥2 chars) search-as-you-type `Autocomplete`, cross-field auto-fill on
selection, and an inline "+ Add new..." quick-create fallback that opens
the existing entity form sheet, saves, and auto-selects the result without
losing other form state. Applied it to the Work Order form's header
(client + vehicle) and line items (catalog picker), replacing static
dropdowns / a full-list bottom sheet. See DECISIONS.md's "Master-data
search-autocomplete pattern" section for the full rationale and how to
wire a new field.

#### Frontend
- **New reusable `SearchAutocompleteField<T>` widget**
  (`core/widgets/search_autocomplete_field.dart`) — wraps `Autocomplete<T>`
  with its own debounce Timer (the widget itself has no built-in
  debouncing), an always-present trailing "+ Add new..." option once the
  minimum character count is reached, and imperative `setText`/`clear`
  methods (via a `GlobalKey`) for cross-field auto-fill and post-add
  resets.
- **Work order header** — `client`/`vehicle` `DropdownButtonFormField`s
  (fed by a fully-loaded list, cascaded client → vehicle) replaced with two
  `SearchAutocompleteField`s. Selecting a client shows a contact-info line
  (phone/email); selecting a vehicle auto-fills/overrides the owner field
  (a plate uniquely determines its owner, so vehicle selection is
  authoritative) via a single extra `GET /clients/:id` only when the
  owner isn't already the one shown.
  `vehiclesByClientProvider` (now unused anywhere) was removed.
- **Work order line items** — the "From catalog" button + unfiltered
  `showModalBottomSheet` picker replaced with a `SearchAutocompleteField`
  that appends a line item and clears itself on selection, so it's ready
  for the next item immediately (fixes a side issue too: the old picker
  didn't filter out deactivated catalog items).
- Quick-create wiring: `showClientFormSheet`, `showVehicleFormSheet`, and
  `showCatalogItemFormSheet` each gained an optional prefill parameter
  (`initialFullName`/`initialPlate`/`initialName`) so the typed search text
  carries into the sheet instead of the user retyping it.
  _Files: `frontend/lib/core/widgets/search_autocomplete_field.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/features/{clients,vehicles,catalog}/presentation/*_form_sheet.dart`,
  `frontend/lib/features/{clients,vehicles,catalog}/data/*_repository.dart`,
  `frontend/lib/features/vehicles/data/vehicle_model.dart`,
  `frontend/lib/features/vehicles/application/vehicles_provider.dart`,
  `frontend/lib/l10n/app_{en,tr,en_CP,tr_CP}.arb`_

#### Backend
- **New capped, uncounted `/search` endpoints** — `GET /clients/search?q=`,
  `GET /vehicles/search?q=&clientId=`, `GET /catalog/search?q=&type=` —
  purpose-built for search-as-you-type (skip the `list` endpoints'
  `COUNT(*)` query, which autocomplete doesn't need). Vehicle search joins
  the owner's name so the frontend can display/auto-fill it without a
  second round-trip; catalog search excludes deactivated items. All three
  enforce `q.length >= 2` server-side too, as defense-in-depth against the
  frontend debounce being bypassed.
- **New trigram indexes** (`db/init/012_search_indexes.sql`) — `pg_trgm`
  GIN indexes on `vehicles.license_plate` and `catalog_items.name`/`sku`,
  which previously had none (unlike `clients.full_name`), so `ILIKE
  '%term%'` on those columns was a sequential scan.
- **`createWorkOrder` now verifies the vehicle actually belongs to the
  submitted client**, not just that each individually belongs to the
  shop — closes a gap where a mismatched pair could previously be
  submitted (e.g. a direct API call, or any future edit flow that only
  changes one of the two). Added as a backstop for the new UI's
  client↔vehicle auto-sync, not because a bug was observed in practice.
  _Files: `backend/src/modules/{clients,vehicles,catalog}/*.{schema,service,controller,routes}.ts`,
  `backend/src/modules/workOrders/workOrders.service.ts`,
  `db/init/012_search_indexes.sql`_

---

## [0.15.2] — 2026-08-06  *(First Real Production Rollout of v0.14.0–v0.15.1 — Deployment Script Fix)*

### Fixed
#### DevOps
- **`ProdRelease.bat` (Farzad's manual deploy script, kept at
  `Desktop\logs\ProdRelease.bat`, outside this repo) had a bug that
  silently killed the entire deploy on the `flutter build web --release`
  step** — no error, no log output, the whole terminal window just closed
  right after Flutter finished and printed success. Root cause: `flutter`
  ships as `flutter.bat` on Windows, not a native `.exe`; invoking a `.bat`
  from inside another `.bat` without the `call` keyword can hand control
  to it and never return — if the inner script's chain ends with a plain
  `exit` anywhere (common in multi-layer tool wrappers like Flutter's), it
  terminates the *entire parent process*, not just that step. Fixed by
  prefixing with `call`. See DECISIONS.md's DevOps section for the general
  rule (applies to any future Windows batch tooling in this project —
  `git`/`docker` are native `.exe`s and unaffected, this is specific to
  `.bat`-wrapped tools like Flutter).
- Confirmed working end-to-end after the fix: `docker-compose.prod.yml`
  rebuilt both images (`garajos-api`, `garajos-web:prod`) and all three
  containers (`repairshop_db`/`repairshop_api`/`repairshop_web`) came up
  healthy, bringing prod from `39a57c1` up to `16579f9` — the Turkish-only
  usability-test mode (v0.14.0–v0.14.4), the Corporate-tone l10n backfill
  and vehicle Şasi No./Motor No./Renk fields (v0.14.5, v0.15.0), and the
  `docker-compose.dev.yml` rename (v0.15.1) are live for the first time.
  The `db/init/011_vehicle_identifiers.sql` migration (chassis/engine/
  color columns) was applied by hand against the prod database, per the
  documented pattern — `db/init/*.sql` files only auto-run on a brand-new
  empty Postgres volume, never against an already-provisioned one.
- **Open item, not yet confirmed resolved:** `docker compose -f
  docker-compose.prod.yml ps` showed `repairshop_web` bound to
  `0.0.0.0:8083` instead of the intended loopback-only `127.0.0.1:8083`.
  The committed `docker-compose.prod.yml` is correct, so this points at a
  leftover local modification on the server from an earlier
  troubleshooting step (see DECISIONS.md), not a repo bug — needs
  `git status`/`git diff docker-compose.prod.yml` on the server to
  confirm and, if so, `git checkout -- docker-compose.prod.yml` + redeploy.
  _Files: none in-repo (external `ProdRelease.bat`); DECISIONS.md updated
  with the general `call` rule and current deployment status_

---

## [0.15.1] — 2026-08-06  *(Rename docker-compose.yml → docker-compose.dev.yml — Remove the Implicit Default)*

### Changed
#### DevOps
- **`docker-compose.yml` renamed to `docker-compose.dev.yml`.** There is now
  no default compose file at all — every command requires an explicit `-f
  docker-compose.dev.yml` or `-f docker-compose.prod.yml`. Prompted by a
  near-miss found while reviewing Farzad's manual production deploy script:
  a bare `docker compose up -d --build` (no `-f`) resolves to whichever
  file is named `docker-compose.yml`, and since dev and prod share the
  same `container_name`s, running that against a production checkout would
  have silently replaced the live prod containers with dev-networked ones
  (`web` off `127.0.0.1:8083` — breaking the Cloudflare Tunnel — `api`
  exposed on `0.0.0.0:3000` instead of unpublished). Removing the implicit
  default turns that mistake into a loud, immediate
  `no configuration file provided` error instead of a silent wrong-config
  deploy. `README.md`, `SETUP.md`, and `DECISIONS.md` updated to use the
  explicit `-f` flag throughout; verified `docker compose -f
  docker-compose.dev.yml ps`/`up -d` against the already-running dev stack
  picks up the existing containers cleanly with no unwanted recreation.
  _Files: `docker-compose.dev.yml` (renamed from `docker-compose.yml`),
  `README.md`, `SETUP.md`, `DECISIONS.md`_

---

## [0.15.0] — 2026-08-06  *(Vehicle Chassis No. / Engine No. / Color Fields)*

### Added
#### Backend
- **`vehicles` table gained three optional columns:** `chassis_no VARCHAR(50)`
  (Şasi No.), `engine_no VARCHAR(50)` (Motor No.), `color VARCHAR(30)`
  (Renk), per Farzad's request. New migration file
  `db/init/011_vehicle_identifiers.sql`, applied directly to the running
  dev container via `docker exec -i repairshop_db psql ... < 011_*.sql`
  rather than a volume reset, so existing dev data (clients, work orders,
  the two standing WV Ferry test accounts) was preserved. `createVehicle`/
  `updateVehicle` in `vehicles.service.ts` and `createVehicleSchema`/
  `updateVehicleSchema` in `vehicles.schema.ts` extended to accept
  `chassisNo`/`engineNo`/`color`, following the existing optional-field
  pattern (`engineType`, `make`, `model`).
  _Files: `db/init/011_vehicle_identifiers.sql`,
  `backend/src/modules/vehicles/vehicles.schema.ts`,
  `backend/src/modules/vehicles/vehicles.service.ts`_

#### Frontend
- **New/Edit Vehicle form** gained three fields — Şasi No., Motor No., Renk
  — placed after the existing mileage field, wired into the same
  `ProfileCompletenessBar` tracker as the rest of the vehicle profile
  fields. Vehicle History screen's detail card now also shows all three
  when present. ARB keys `chassisNoLabel`/`engineNoLabel`/`colorLabel`
  added to all four locale files (`app_en.arb`, `app_tr.arb`,
  `app_en_CP.arb`, `app_tr_CP.arb`) in the same change, per the standing
  convention from v0.14.5 — plain field labels, so Corporate tone is a
  verbatim copy of Garage tone for all three.
  _Files: `frontend/lib/features/vehicles/data/vehicle_model.dart`,
  `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
  `frontend/lib/features/vehicles/presentation/vehicle_history_screen.dart`,
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/l10n/app_en_CP.arb`, `frontend/lib/l10n/app_tr_CP.arb`_

**Verified end-to-end:** backend tested via direct API calls (create,
update, get, history — all four round-trip the new fields) against a
throwaway shop, cleaned up afterward; frontend tested by logging into a
second throwaway shop in the running dev app and creating a real vehicle
through the actual New Vehicle form UI, confirming all three fields save
and display correctly on the Vehicle History screen. Both throwaway shops
deleted after verification — no leftover test data beyond the two
intentional WV Ferry accounts.

---

## [0.14.5] — 2026-08-06  *(Backfill Corporate-Tone Translations — Close the en_CP/tr_CP Gap)*

### Fixed
#### Frontend
- **`flutter build web --release` was reporting 165 (`en_CP`) and 164
  (`tr_CP`) untranslated messages.** The Corporate-tone locale files
  (`app_en_CP.arb`/`app_tr_CP.arb`) had only been kept current through
  v0.9.x (26–27 keys); v0.10.0–v0.14.4 added ~165 new keys (profile, team
  invites, redesigned work-order form, nav) without their Corporate
  counterparts. Not a crash or blank text — missing `_CP` keys silently
  fall back to Garage-tone wording (`AppLocalizationsEnCp extends
  AppLocalizationsEn`) — but meant switching to Corporate voice showed a
  growing mix of Garage slang on every screen shipped since v0.10.0.
  Backfilled both files to full 191/191 parity: plain/neutral keys (the
  large majority) copied verbatim from the Garage-tone file since there was
  no slang to remove; the one genuinely flavored missing key
  (`failedToLoadVehicles`, "dropped the vehicle list in the oil pan") got a
  proper neutral Corporate rewrite ("Failed to load vehicles: {error}" /
  "Araçlar yüklenemedi: {error}"), matching the pattern of the pre-existing
  `_CP` entries. `flutter build web --release` now reports 0 untranslated
  messages for both locales.
  _Files: `frontend/lib/l10n/app_en_CP.arb`,
  `frontend/lib/l10n/app_tr_CP.arb`,
  `frontend/lib/generated/app_localizations_en.dart`,
  `frontend/lib/generated/app_localizations_tr.dart`_

### Added
- **New standing convention: every ARB key change touches all four locale
  files** (`app_en.arb`, `app_tr.arb`, `app_en_CP.arb`, `app_tr_CP.arb`) in
  the same commit, so this gap can't silently reopen. See DECISIONS.md's
  Internationalisation section for the full rule.

---

## [0.14.4] — 2026-08-05  *(Nav Order — Vehicles Moved Before Clients)*

### Changed
- **Main navigation order changed** from Servis Kaydı / Müşteriler / Araçlar
  / Katalog / Raporlar to Servis Kaydı / Araçlar / Müşteriler / Katalog /
  Raporlar, per Farzad's request. One shared `destinations` list in
  `app_shell.dart` drives both the wide-screen `NavigationRail` and the
  narrow/mobile `NavigationBar`, so reordering it covers web and mobile in
  one change.
  _File: `frontend/lib/core/widgets/app_shell.dart`_

---

## [0.14.3] — 2026-08-05  *(Localization Fixes from First-Round Screenshots — New Work Order, Payment Method, Save Button, Login Error)*

### Fixed
- **`work_order_form_screen.dart` (the "New/Edit Work Order" form) had *zero*
  `AppLocalizations` wiring** — every label, button, and validator message
  was a raw English string literal, so the single most-used form in the app
  rendered entirely in English regardless of locale. Caught from Farzad's
  screenshot during the usability test. Wired the whole screen up: reused
  existing keys where one already fit (`lineItems`, `discount`, `notes`,
  `subtotal`, `grandTotal`, `save`, `required`, `newWorkOrder`,
  `failedToLoadClients`, `clientLabel`/`vehicleLabel`) and added the ones
  that didn't exist yet — `client`, `vehicle`, `selectAClient`,
  `selectAVehicle`, `selectClientAndVehicle`, `addAtLeastOneLineItem`,
  `failedToLoadVehicles`, `mileageAtServiceLabel`, `fromCatalog`,
  `customLineItem`, `descriptionLabel`, `qtyLabel`, `priceLabel`,
  `taxRateLabel`, `taxLabel`, `editWorkOrderTitle` — to both `app_en.arb`
  and `app_tr.arb`.
- **The "Mark as X" button on the work-order detail screen showed the raw
  English status enum** (screenshot: "paid İşaretle", half-Turkish
  half-English) — `markAs(next)` was called with the unlocalized `next`
  status string (`'draft'`/`'completed'`/`'paid'`) directly, bypassing the
  `l.draft`/`l.completed`/`l.paid` getters `PitStopStepper` itself already
  uses correctly for the *current* status. Added a `_statusLabel()` helper
  in `work_order_detail_panel.dart` (same pattern
  `vehicle_history_screen.dart` already uses) and now call
  `l.markAs(_statusLabel(l, next))`.
- **The payment-method picker dialog and the paid-order chip both showed
  raw backend enum values** (`cash`/`card`/`bank_transfer`/`other`,
  screenshot) instead of the already-existing `l.cash`/`l.card`/
  `l.bankTransfer`/`l.other` keys — `_paymentMethods.map((m) => ... Text(m))`
  rendered the raw string directly. Added a `_paymentMethodLabel()` helper
  and used it in both places.
- **New catalog item form's "Unit" field started pre-filled with the raw
  English word "unit"** (screenshot: "Birim" label, "unit" value) —
  `catalog_item_form_sheet.dart` defaulted a *new* item's controller to the
  literal string `'unit'`. Changed to an empty default (no field should be
  presumptuously pre-filled with one specific unit word — "adet"/"saat"/
  "litre" are all equally likely per item). The same English fallback
  existed one layer deeper too: `catalog.service.ts`'s `createCatalogItem`
  substitutes `input.unit || "unit"` when the field is left blank, so even
  with the frontend fix, a blank submission would have silently stored the
  English word server-side. Changed the backend fallback to `"adet"`
  (Turkish for "piece/each", the most generic default) to match.
- **The catalog/client/vehicle "Save" button's Turkish garage-voice
  translation read as confusing/wrong** (screenshot: "Sıkıştır (Kaydet)" —
  "Sıkıştır" alone means "compress/tighten," not "save," and doesn't parse
  as a save action to a Turkish reader even with "(Kaydet)" appended).
  Simplified `app_tr.arb`'s `save` key to plain "Kaydet" — this button is
  hit constantly during onboarding/testing, so clarity wins over the pun
  here; matches what the Corporate-tone override already used
  (`app_tr_CP.arb`'s `save` was already "Kaydet"). Affects every form that
  reuses this one shared key (catalog, client, vehicle, and now work order).
- **Login failure showed the raw backend string "Invalid email or
  password"** in English, unconditionally — the backend has no notion of
  the caller's locale, so every error message it returns is English by
  construction (see DECISIONS.md's new note on this). Added
  `invalidEmailOrPassword` to both ARBs and a targeted client-side mapping
  in `login_screen.dart`: the one specific, known, extremely common string
  is now translated; any other backend message still falls back to the raw
  English text rather than showing nothing. **Not a general fix** — every
  other screen that surfaces `toApiException(e).message` directly
  (register, join, work orders, profile, team, ...) still shows raw
  backend English on less-common error paths. Flagged as follow-up work if
  it comes up again; a real fix needs backend error codes the frontend can
  map, not per-string client-side matching.
  _Files: `frontend/lib/features/work_orders/presentation/work_order_form_screen.dart`,
  `frontend/lib/features/work_orders/presentation/work_order_detail_panel.dart`,
  `frontend/lib/features/catalog/presentation/catalog_item_form_sheet.dart`,
  `frontend/lib/features/auth/presentation/login_screen.dart`,
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations*.dart`,
  `backend/src/modules/catalog/catalog.service.ts`_

---

## [0.14.2] — 2026-08-05  *(Fix — Turkish Default Didn't Apply If a Browser Already Had "en" Saved)*

### Fixed
- **v0.14.0's new Turkish default silently didn't apply for Farzad's own
  test browser** — after logging in, the app still showed English with no
  way to switch (toggle hidden by v0.14.0). Root cause: `LocaleNotifier`'s
  `_load()` always reads a saved `locale_code` from `localStorage` and
  overrides the constructor's default state if one exists — that's correct
  behavior for a normal returning user, but his browser already had
  `locale_code: 'en'` saved from before this change (or from earlier
  toggle testing), so the stored value won out over the new `Locale('tr')`
  default every time, on every reload, with no UI path left to fix it
  since the toggle is hidden. The bug wasn't in the default itself — it
  only affected browsers that already had a saved preference from before
  v0.14.0; a genuinely fresh browser with no `locale_code` key would have
  seen Turkish correctly.

  Fix: `_load()` now returns immediately without touching storage at all
  when `kLanguageToggleVisible` is `false` — every user gets Turkish,
  unconditionally, regardless of what (if anything) is already saved.
  Re-enabling the toggle later restores normal respect-the-saved-value
  behavior automatically, no extra change needed.
  _File: `frontend/lib/core/locale/locale_provider.dart`_

---

## [0.14.1] — 2026-08-05  *(Self-Registration Temporarily Disabled for Public Usability Test)*

### Changed
- **New shops can no longer self-register**, front-end only, per Farzad's
  request while a public usability test is running on the live site — he
  doesn't want anyone creating a real shop account mid-test. New
  `kRegistrationOpen` constant (currently `false`,
  `frontend/lib/core/config/feature_flags.dart`) gates two things: the
  "Create account" link on the login screen (now hidden, same
  `if (kFlag) ...` pattern the v0.14.0 language toggle uses), and the
  `goRouterProvider` `redirect` guard in `app.dart`, which now bounces any
  direct navigation to `/register` back to `/login` regardless of auth
  state — closing the gap a hidden link alone would leave (someone typing
  the URL directly).

  **Not changed:** the backend `POST /api/v1/auth/register` endpoint itself
  still accepts requests — this pass only closes the two UI paths a normal
  visitor would use. Someone deliberately calling the API directly (e.g.
  via curl/Postman) could still register. Flagged to Farzad as a
  follow-up; not blocked automatically since disabling a public API route
  is a backend/prod change with its own deploy step, out of scope for a
  "hide it in the UI" request.
  _Files: `frontend/lib/core/config/feature_flags.dart` (new),
  `frontend/lib/features/auth/presentation/login_screen.dart`,
  `frontend/lib/app.dart`_

---

## [0.14.0] — 2026-08-05  *(Turkish-Only for Now — Language Toggle Hidden, Default Locale Switched)*

### Changed
- **The app now defaults to Turkish and hides the EN/TR language switcher
  everywhere**, per Farzad's request after first real user testing — every
  current user works in Turkish, so the toggle was just surface area for
  confusion. `LocaleNotifier`'s initial state changed from `Locale('en')` to
  `Locale('tr')` (`core/locale/locale_provider.dart`), and a new
  `kLanguageToggleVisible` constant (currently `false`) in the same file
  gates every place the switcher rendered: the login screen's segmented
  button, the register screen's AppBar action, the public join screen's
  AppBar action, and the "Language" section (header + English/Türkçe rows)
  in the authenticated app-shell's account menu. A user with no
  `locale_code` already in browser storage now lands in Turkish
  immediately; anyone who'd previously switched to English keeps seeing
  English until they clear storage, since the stored preference still
  takes precedence over the new default — the toggle to change it back is
  just not visible right now.

  **Deliberately not removed:** the underlying `LocaleNotifier`/
  `localeProvider` machinery, both ARB files, and all four toggle widgets
  are untouched — only wrapped in `if (kLanguageToggleVisible)`. Farzad was
  explicit this is temporary ("for the time being, until stated
  otherwise") and that both `app_en.arb`/`app_tr.arb` must keep being
  updated for every future feature/fix regardless. Flipping the constant
  back to `true` (and reverting the default-locale line, if desired) is a
  two-line change whenever he says so — no re-implementation needed.
  _Files: `frontend/lib/core/locale/locale_provider.dart`,
  `frontend/lib/features/auth/presentation/login_screen.dart`,
  `frontend/lib/features/auth/presentation/register_screen.dart`,
  `frontend/lib/features/team/presentation/join_screen.dart`,
  `frontend/lib/core/widgets/app_shell.dart`_

---

## [0.13.1] — 2026-08-03  *(Production Deployment Confirmed Live — Guide Corrections from Real Server Run)*

### Fixed
- **Deployment guide corrected against an actual server run.** The
  Docker-based frontend build (`frontend/Dockerfile`, v0.13.0) was
  confirmed working — all three containers built and started successfully
  on the target Windows home server with no Flutter installed on it. Two
  parts of the original guide draft didn't hold up and were corrected:
  the `docker run --rm node:20-alpine node -e "..."` one-liner suggested
  for generating `JWT_SECRET`/`DB_PASSWORD` errored on this server
  (likely a Docker Hub pull/network restriction) — replaced with a
  PowerShell-native `RNGCryptoServiceProvider` command that needs nothing
  beyond PowerShell itself; and the assumed project root
  (`D:\apps\garajos`) didn't match the actual path used
  (`D:\apps\GarajOS\garajos`) — every path reference in the guide was
  corrected. Also added tested `winget install --id Git.Git` (Git wasn't
  preinstalled) and a working native-Flutter-install PowerShell script,
  kept as an optional fallback path.
  See `DECISIONS.md`'s "Production deployment" section for the full
  writeup. No application code changed — this is a documentation-only
  correction to the external deployment guide (and this repo's
  `DECISIONS.md`), based on real-world deployment feedback.
  _Files: `DECISIONS.md`,
  `C:\Users\Farzad\Desktop\logs\garajos-production-deployment-guide.md`
  (outside repo)_

---

## [0.13.0] — 2026-08-03  *(Production Deployment — Dockerized Frontend Build + Prod Compose Stack)*

### Added
- **`frontend/Dockerfile`** — new two-stage build (`ghcr.io/cirruslabs/flutter:stable`
  → `nginx:1.27-alpine` runtime), mirroring the pattern `backend/Dockerfile`
  already used. Lets the `web` service build the Flutter web app entirely
  inside Docker, so a production host never needs the Flutter SDK
  installed locally.
- **`docker-compose.prod.yml`** — a self-contained production stack for
  the home-server + Cloudflare Tunnel deployment (`www.garajos.com.tr`),
  distinct from the dev `docker-compose.yml`:
  - `api` publishes no port to the host at all (dev publishes
    `0.0.0.0:3000`) — only reachable from `web` over the internal
    `repairshop_net` Docker network.
  - `web` binds to `127.0.0.1:8083` (loopback only), not `0.0.0.0:8080` —
    reachable by the Cloudflare Tunnel process on the same host, not by
    any other device on the LAN.
  - `web` builds from `frontend/Dockerfile` instead of relying on a
    pre-built `frontend/build/web/` bind mount.

  See `DECISIONS.md`'s "Production deployment" section for why this is a
  standalone file rather than a merge-overlay on `docker-compose.yml`, and
  a Dockerfile gotcha (`nginx.conf` can't be `COPY`'d from outside the
  build context, so it's still supplied via bind mount). Full step-by-step
  server setup guide lives outside this repo at
  `Desktop\logs\garajos-production-deployment-guide.md`.
  _Files: `frontend/Dockerfile`, `docker-compose.prod.yml`, `DECISIONS.md`_

---

## [0.12.0] — 2026-08-02  *(Redesigned Work-Order PDF + Fix — Turkish Characters Garbled in Print)*

### Added
- **Work-order PDF completely redesigned** into a "classy, modern,
  professional slip" (design supplied by Farzad via
  `Desktop\logs\work-orders.pdf.redesigned.ts`): letterhead with logo +
  shop identity on the left and a large order number + color-coded status
  pill (draft/completed/paid) on the right under a brand-green accent
  rule; client/vehicle shown as two side-by-side info cards instead of
  plain stacked text; line-items table with a dark header band and
  alternating row shading; grand total in a highlighted brand-tint box;
  notes in a left-accented callout card; consistent footer. Replaces the
  plain-text layout the PDF has had since v0.3.0.

### Fixed
- **Turkish characters (ı, İ, ğ, Ş, ö, ç, ü, ...) rendered as garbled
  symbols in every printed work order** — caught from
  `Desktop\logs\work-order-2.pdf`, e.g. the shop address
  "Yenişehir mahallesi, Osmanlı Bulvarı..." printed as
  "YeniöV†—"Ö†ÆÆW6'Â÷6ÖæÁ1 Bulvar...". Root cause: PDFKit's built-in
  `"Helvetica"`/`"Helvetica-Bold"` are the PDF standard-14 fonts, encoded
  as WinAnsi — a character set that's missing the Turkish-specific letters
  entirely, so PDFKit either dropped them or substituted the wrong glyph.
  This affected *every* PDF this app has ever generated for a Turkish shop
  name, address, tax office, or any Turkish word in a client/vehicle/notes
  field — not something introduced by the redesign.

  Fix: embed a real font instead of relying on the standard-14 set.
  Tried Google-Fonts-distributed webfont packages first
  (`@fontsource/noto-sans`) but rejected them after verifying with
  `fontkit`'s `hasGlyphForCodePoint`: those packages split each family into
  disjoint per-unicode-range files (`latin` vs `latin-ext`) meant to be
  layered together via CSS `unicode-range` in a browser — used standalone
  (as PDFKit needs), the `latin-ext` file is missing plain ASCII and
  punctuation, and `latin` is missing the Turkish letters, so *neither
  alone* is usable. Settled on `dejavu-fonts-ttf` (DejaVu Sans) instead —
  ships as one complete, non-subsetted TTF per weight with full Latin
  Extended-A + general punctuation coverage in a single file, permissively
  licensed (Bitstream Vera-derived, embedding/redistribution allowed).
  Verified against the exact same work order that showed the original bug
  (`work-order-2.pdf`'s address, "Genel Bakım", "Vergi Dairesi") — renders
  correctly now.
  _Files: `backend/src/config/fonts.ts` (new), `backend/package.json`_

_Files: `backend/src/modules/workOrders/workOrders.pdf.ts`,
`backend/src/config/fonts.ts` (new), `backend/package.json`_

---

## [0.11.1] — 2026-08-02  *(Fix — "Pending Invites" Showed Already-Used Invites)*

### Fixed
- **The Team screen's "Pending Invites" section listed invites that had
  already been accepted**, showing as "Technician — Used" under a heading
  that says "Pending." Farzad caught this immediately after inviting Araz
  — two entries showed up there, both actually already used (Araz's real
  invite, plus a leftover from an earlier verification pass). Checked the
  backend data first to rule out an actual invite/user bug: both invites'
  `used_at`/`used_by` were correct — Araz's account really was created via
  his invite. The bug was purely in the frontend: `GET /api/v1/invites`
  intentionally returns every invite regardless of status (so a future
  history view could use it), but `team_screen.dart` rendered that
  unfiltered list directly under the "Pending Invites" heading instead of
  filtering to `invite.isPending` first. Now filters to pending-only, with
  a "No pending invites" empty state.
  _Files: `frontend/lib/features/team/presentation/team_screen.dart`,
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`_

---

## [0.11.0] — 2026-08-02  *(Team Invites — WhatsApp Link, Self-Registration, Deactivate/Delete)*

### Added
- **Owners/managers can now bring on teammates themselves**, without any
  hand-rolled SQL. Previously the only way to create a `manager`/
  `technician` account was for a Claude session (or Farzad directly) to
  insert a `users` row by hand with a manually-generated bcrypt hash —
  Farzad flagged this as something a real shop owner needs to be able to
  do on their own.
  - New `shop_invites` table (`db/init/010_shop_invites.sql`) and backend
    `invites` module (`backend/src/modules/invites/`): `POST/GET/DELETE
    /api/v1/invites` (owner/manager, create/list/revoke) plus two
    deliberately public routes — `GET /api/v1/invites/:id/public` and
    `POST /api/v1/invites/:id/join` — with no `authenticate`/`tenantScope`
    middleware, since the person accepting an invite has no account or
    shop context yet. The invite's own UUID doubles as the link token (no
    separate token column — same unguessable-by-design convention every
    other PK in this app already relies on). `join` re-validates the
    invite (not expired/used/revoked) inside a `SELECT ... FOR UPDATE`
    transaction to close the race if two people open the same link at
    once, then creates the user and returns a JWT so they land logged in
    immediately — exact same `{ token, user }` shape `login`/`register`
    already return.
  - New **Team** screen (`frontend/lib/features/team/`, reachable from the
    account menu, owner/manager only): member roster with
    deactivate/reactivate/remove per row, and an "Invite Team Member"
    dialog (role + 24h/3d/7d expiry) that generates a link and offers
    **Share via WhatsApp** (`https://wa.me/?text=...`, the same
    `launchUrl(..., webOnlyWindowName: '_blank')` pattern the PDF print
    button already uses) — deliberately no email/SMS infrastructure, per
    Farzad's own design: share the link however you already would.
  - New public **Join** screen (`frontend/lib/features/team/presentation/join_screen.dart`,
    route `/join/:id`, outside the authenticated shell) shows "You're
    joining `<Shop>` as `<Role>`" and a first/last name + email + password
    form. Works regardless of the visitor's current auth state — opening
    an invite link while already logged in as someone else still completes
    and switches the session to the new account (new
    `AuthController.setSession()` in `auth_provider.dart`, reusing the
    existing token-persistence path `login`/`register` already use).
  - Deactivate (`is_active = false`, the column already existed —
    `login` already checked it) and delete (`DELETE`, falling back to the
    existing FK-violation → 409 mapping in `errorHandler.ts` if that user
    has created work orders — same soft/hard split
    `catalog.service.ts`'s `deleteCatalogItem` already uses) live in a new
    `users` module (`backend/src/modules/users/`). Both refuse to target
    an `owner` account or the caller's own account (no flow exists to
    create a second owner, so this prevents a shop from locking itself
    out; self-service stays on the Profile page).

### Fixed
- **Deleting a team member 409'd even with zero work-order history**,
  caught while verifying the feature: `shop_invites.created_by`/`used_by`
  reference `users(id)` with Postgres's default `ON DELETE RESTRICT`, so
  the *invite audit trail itself* (who created/accepted an invite) blocked
  deleting that user, independent of the "has created work orders" case
  the 409 mapping was actually meant for. Changed both FKs to `ON DELETE
  SET NULL` (and dropped the `NOT NULL` on `created_by` accordingly) —
  the invite record survives with that pointer cleared, since it's an
  audit reference, not data the invite depends on.
  _File: `db/init/010_shop_invites.sql`_

_Files: `db/init/010_shop_invites.sql`, `backend/src/modules/invites/*` (new),
`backend/src/modules/users/*` (new), `backend/src/modules/auth/auth.service.ts`
(exported `signToken`/`BCRYPT_ROUNDS` for reuse), `backend/src/app.ts`,
`frontend/lib/features/team/*` (new), `frontend/lib/app.dart`,
`frontend/lib/core/widgets/app_shell.dart`,
`frontend/lib/core/api/api_client.dart` (new `appOrigin` helper),
`frontend/lib/features/auth/application/auth_provider.dart`,
`frontend/lib/l10n/app_{en,tr}.arb`, `frontend/lib/generated/app_localizations*.dart`_

---

## [0.10.1] — 2026-08-02  *(Fix — "Upload Logo" Did Nothing on Web)*

### Fixed
- **Pressing "Upload logo" on the new Profile screen silently did nothing**
  — no file dialog, no error visible to the user. Farzad caught this
  immediately after v0.10.0 shipped. Root cause: `file_picker`'s Flutter
  Web implementation is wired up via a generated file,
  `.dart_tool/flutter_build/<hash>/web_plugin_registrant.dart`, which
  registers `FilePickerWeb` as `FilePicker.platform` at app startup.
  `.flutter-plugins-dependencies` correctly listed `file_picker` as a web
  plugin (added in v0.10.0), but the registrant file itself was served from
  a **stale cached build** and never regenerated to include it — so
  `FilePicker.platform` silently stayed unwired on web, and every click on
  "Upload logo" threw an uncaught low-level exception (visible in the
  browser console, but with no app-level try/catch around the call to
  surface it) before the native OS file dialog could even open.
  Confirmed by checking the generated registrant file directly: it listed
  `FlutterSecureStorageWeb`/`UrlLauncherPlugin` but not `FilePickerWeb`,
  and the compiled `main.dart.js` had zero references to file_picker's web
  DOM markers, even though the source/dependency files were all correct.

  Fix: `flutter clean` (clears `.dart_tool/flutter_build`) + fresh
  `flutter pub get` + rebuild, which forced the registrant to regenerate
  correctly. Also added a `try/catch` around the `FilePicker.platform.pickFiles()`
  call itself (`profile_screen.dart`), so if picking ever fails again for
  any reason (user cancels via some browsers' cancel-as-error path, browser
  security restriction, etc.) it surfaces as a snackbar instead of an
  uncaught exception.

  Verified: rebuilt, hard-reloaded (Ctrl+Shift+R, to rule out the browser
  serving a cached pre-fix `main.dart.js` — `main.dart.js` has no
  cache-busting hash in its URL and nginx sends no explicit
  `Cache-Control`, so it's subject to normal HTTP heuristic caching), and
  Farzad confirmed the upload now works end-to-end on his machine.
  _Files: `frontend/lib/features/shop/presentation/profile_screen.dart`_

---

## [0.10.0] — 2026-08-02  *(User & Shop Profile Page — Editable Letterhead + Logo Upload)*

### Added
- **Shop profile management** — `shops` gained `tax_office`, `address`,
  `phone`, `email`, `logo_path`, and `updated_at` columns
  (`db/init/009_shop_profile.sql`), plus a new backend module
  (`backend/src/modules/shop/`) exposing `GET/PATCH /api/v1/shop` and
  `POST/DELETE /api/v1/shop/logo`. Shop edits and logo changes are
  restricted to `owner`/`manager` roles (`authorize("owner", "manager")`,
  same pattern as `catalog`'s write routes); `technician` can view but not
  edit. Logo uploads go through `multer` (new dependency, v2.x to avoid the
  known CVEs in the 1.x line) with disk storage under
  `backend/uploads/shop-logos/` — the volume Docker Compose already mounted
  for this purpose — validated to PNG/JPEG/WebP, 2MB max, one file per shop
  (`${shopId}.<ext>`, overwritten on replace). Served back publicly via a
  new `express.static` mount at `/api/v1/uploads` (no auth — same treatment
  as any other static branding asset; nothing sensitive lives there).
- **Account self-service** — `PATCH /api/v1/auth/me` (rename) and
  `POST /api/v1/auth/me/password` (change password, requires the current
  password) added to the existing `auth` module.
- **New "Profile" screen** (`frontend/lib/features/shop/`), reachable from
  a new item in the account popup menu (`app_shell.dart`) and routed at
  `/profile` inside the existing `ShellRoute`. Two cards: **My Account**
  (name, read-only email, change-password dialog) and **Shop Details**
  (name/tax ID/tax office/address/phone/email + logo preview with
  upload/remove, all read-only for `technician`). Logo picking uses the new
  `file_picker` dependency (not `image_picker` — no Windows desktop
  support, and this app targets Web + Android + Windows).
- **Work-order PDF letterhead** — `workOrders.pdf.ts` now draws the shop's
  logo (if uploaded) plus name/address/phone/tax-office/tax-ID at the top
  of every printed work order, replacing the previous bare shop-name
  heading. Matches the minimum bar set by the handwritten reference slip
  Farzad supplied (`Desktop\logs\VW Tech Servis kaydi.JPG`): logo + brand
  name + full address/phone + tax info.

### Fixed
- **`POST /auth/login` never returned the user's email** (only
  `id`/`fullName`/`role`/`shopId`) — unlike `register`/`getCurrentUser`,
  which both already included it. Caught immediately by the new Profile
  screen's read-only email field showing blank right after a fresh login.
  Now included, matching the other two endpoints.
  _File: `backend/src/modules/auth/auth.service.ts`_
- **Profile screen's "My Account" fields stayed blank forever if the page
  was reached before the stored-token auth check finished resolving** (e.g.
  navigating straight to `/profile` on a cold load) — the name/email
  controllers were populated once from `currentUserProvider` in `initState`
  and never revisited once the real user data arrived a moment later.
  Fixed by keying `_MyAccountCard` on the user id
  (`ValueKey(user?.id)`), so Flutter discards and re-initializes the
  card's state once auth data actually resolves.
  _File: `frontend/lib/features/shop/presentation/profile_screen.dart`_
_Files: `db/init/009_shop_profile.sql`, `backend/src/config/uploads.ts` (new),
`backend/src/modules/shop/*` (new), `backend/src/modules/auth/auth.{schema,service,controller,routes}.ts`,
`backend/src/modules/workOrders/workOrders.pdf.ts`, `backend/src/app.ts`,
`backend/src/middleware/errorHandler.ts`, `backend/package.json`,
`frontend/lib/features/shop/*` (new), `frontend/lib/features/auth/{data/auth_repository,application/auth_provider}.dart`,
`frontend/lib/core/widgets/app_shell.dart`, `frontend/lib/app.dart`,
`frontend/lib/core/api/api_client.dart`, `frontend/lib/l10n/app_{en,tr}.arb`,
`frontend/lib/generated/app_localizations*.dart`, `frontend/pubspec.yaml`_

---

## [0.9.3] — 2026-08-02  *(Login Logo Size + Home-Screen Icon Investigation)*

### Changed
- **Login screen logo enlarged** — doubled from `height: 96` to `height: 192`
  per request, no layout overflow at the existing `maxWidth: 400` form
  constraint.
  _File: `frontend/lib/features/auth/presentation/login_screen.dart`_

### Investigated — no code change needed
- **iPhone "Add to Home Screen" showed the default Flutter logo instead of
  the GarajOS icon** (reported via a screenshot of the iOS share-sheet).
  Verified server-side and found everything already correct: `index.html`'s
  `apple-touch-icon` link tags point at `icons/Icon-maskable-192.png` /
  `-512.png`, both files are the branded mascot artwork (not Flutter
  defaults), and `curl` against the live container confirms it serves those
  exact bytes with no long-lived cache headers that could explain a stale
  serve. This is a known iOS Safari quirk, not a build defect: Safari caches
  home-screen icons per-URL independently of normal HTTP caching, so a
  device that visited this LAN URL before the branded icons were added
  (pre-v0.7.0) can keep showing its own stale icon indefinitely regardless
  of what the server now sends. See DECISIONS.md for the fix on the device
  side.

---

## [0.9.2] — 2026-08-02  *(Remaining Hard-Coded English UI Strings)*

### Fixed
- **Several UI strings were hard-coded in English and never wired to
  `AppLocalizations`, so they stayed in English even with Türkçe selected**
  (caught from a screenshot of the Turkish-locale work-orders screen):
  the global search bar's hint text (`'Search plate, name, phone, order #'`),
  the master-detail empty-state message (`'Select an item to view its
  details'`, previously a non-const-friendly hard-coded default parameter),
  the "Voice" section header in the account popup menu, and the
  "Corporate"/"Garage" tone-toggle option labels in that same menu. Added
  four new ARB keys (`globalSearchHint`, `selectItemToViewDetails`,
  `voiceToneLabel`, `toneCorporate`, `toneStreet`) to both `app_en.arb` and
  `app_tr.arb` and regenerated via `flutter gen-l10n`.
  `MasterDetailScaffold.emptyDetailMessage` changed from a `String` with a
  hard-coded English default (defaults must be compile-time constants, so it
  couldn't call `AppLocalizations.of(context)`) to a nullable `String?` that
  falls back to the localized string inside `build()`.
  _Files: `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations*.dart`,
  `frontend/lib/core/widgets/global_search_bar.dart`,
  `frontend/lib/core/widgets/master_detail_scaffold.dart`,
  `frontend/lib/core/widgets/app_shell.dart`_
- **Note on `tone_toggle.dart`:** that widget's icon-only Corporate/Street
  toggle (used on the login screen) is *still* intentionally untranslated —
  same treatment as the "EN"/"TR" language chips, since it shows no text,
  only icons+tooltips. Only the app-shell popup menu's *text-labeled* copy
  of this toggle was in scope here. Confirmed with Farzad before touching
  it, since it contradicted that documented decision. Doc comment in
  `tone_toggle.dart` updated to call out the distinction explicitly so a
  future pass doesn't conflate the two.
  _File: `frontend/lib/core/widgets/tone_toggle.dart`_

---

## [0.9.1] — 2026-08-02  *(Brand Rename to GarajOS + Turkish Lira Currency)*

### Fixed
- **App still read "AutoService" everywhere despite the GarajOS rebrand**
  The visual redesign (v0.7.0–v0.9.0) never touched the actual brand string.
  `appTitle` (shown on the login screen and the app-shell header via
  `AppLocalizations`), the browser tab `<title>`, PWA manifest name/short_name,
  and social-share meta tags (`apple-mobile-web-app-title`, `og:title`,
  `twitter:title`) all still said "AutoService" / "AutoServis". Fixed by
  changing the `appTitle` key in both `app_en.arb` and `app_tr.arb` to
  "GarajOS" and regenerating via `flutter gen-l10n` (never hand-edit
  `lib/generated/` — see i18n gotcha in DECISIONS.md), plus updating the
  `MaterialApp.router` `title:` and the web-shell HTML/manifest directly.
  The internal `AutoServiceApp` Dart class name (`app.dart`, `main.dart`) was
  left as-is — it's not user-visible UI.
  _Files: `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations*.dart`, `frontend/lib/app.dart`,
  `frontend/web/index.html`, `frontend/web/manifest.json`_

- **Financial figures were formatted in USD (`$`) instead of Turkish Lira**
  `formatCurrency()`, the single formatting helper used by every screen that
  displays money (work order line items, totals, catalog prices, reports),
  hard-coded `NumberFormat.currency(symbol: '\$', decimalDigits: 2)`. Since
  the app's localization is Turkish-only for currency (no multi-currency
  support), fixed at the source by switching to
  `NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2)`,
  which also switches grouping/decimal separators to Turkish convention
  (`₺1.234,50` instead of `$1,234.50`). No other file hard-codes a `$`
  symbol — confirmed by grepping the whole `frontend/lib` tree.
  _File: `frontend/lib/core/utils/currency_formatter.dart`_

---

## [0.9.0] — 2026-08-01  *(Corporate/Garage Voice Toggle + Full Gamification Localization)*

### Added
- **A second, independent toggle for the app's *tone*** ("Corporate" vs.
  "Garage"/street), orthogonal to the EN/TR language toggle — e.g. Turkish +
  Corporate, English + Garage, and every other combination all work. Implemented
  by piggy-backing on Flutter's real locale-variant mechanism (the same trick
  Facebook used for its old "Pirate English" locale): "Corporate" is a locale
  *country-code* variant (`en_CP` / `tr_CP`), so every existing
  `AppLocalizations.of(context)!.xyz` call in the app keeps working completely
  unchanged — no refactor needed across the ~15 screens that already call it.
  - New: `frontend/lib/core/locale/tone_provider.dart` (`AppTone` enum +
    `ToneNotifier`, mirrors the existing `LocaleNotifier` pattern, persisted
    separately under `tone_mode` in the same storage `LocaleNotifier` uses).
  - New: `frontend/lib/l10n/app_en_CP.arb` / `app_tr_CP.arb` — **partial**
    ARB overrides containing only the ~31 keys per language that actually
    differ between tones. Everything else inherits from the base
    `AppLocalizationsEn`/`Tr` class at codegen time
    (`AppLocalizationsEnCp extends AppLocalizationsEn`) — confirmed this is
    how `flutter gen-l10n` is designed to work (a locale ARB missing a key
    just emits an "N untranslated message(s)" warning, not an error, and the
    generated subclass simply doesn't override that getter) before writing
    all the content, so there was zero duplication of the ~100 keys that
    read identically in both tones.
  - New: `frontend/lib/core/widgets/tone_toggle.dart` — compact icon-only
    `SegmentedButton<AppTone>` (💼/🔧), added next to the language selector
    on the login screen, the register screen's AppBar, and as a new "Voice"
    section in the authenticated app bar's user menu (parallel to the
    existing "Language" section).
  - `app.dart` computes the effective `Locale` each build:
    `tone == corporate ? Locale(lang, 'CP') : Locale(lang)`.
  - Default is `AppTone.street` — matches what was already shipped in
    v0.8.1, so existing users see no change unless they open the new toggle.
  - Verified in-browser: switched between all four combinations
    (EN-Garage/EN-Corporate/TR-Garage/TR-Corporate) live via the app bar
    menu and confirmed status chips, the streak badge, and the client-form
    completeness bar all update correctly and immediately, and that the
    choice survives a full page reload independent of the language choice.

### Changed

#### Frontend
- **Every remaining gamification string is now a real ARB key**, in both
  tones and both languages (was previously flagged as a known gap):
  `ProfileCompletenessBar`'s title ("Garage Completeness" ⇄ "Profile
  Completeness") and "Fully tuned! 🔧" / "Add {fields} to level up." nudge,
  `PitStopStepper`'s "THE PIT STOP" ⇄ "STATUS" header, `StreakBadge`'s "DAY
  STREAK" ⇄ "CONSECUTIVE DAYS" label. New shared key `garageCompleteness`
  also fixes a pre-existing inconsistency where the Client form and Vehicle
  form showed two different hardcoded titles ("Garage Completeness" vs.
  "Profile Completeness") for the identical widget.
- **`client_form_sheet.dart` is now fully localized** — it previously had
  *no* `AppLocalizations` usage at all (every field label and the "New
  Client"/"Edit Client" title were hardcoded English, a pre-existing gap
  noted in DECISIONS.md when the gamified redesign was applied). New keys:
  `newClient`, `editClient`, `fullNameLabel`, `phoneLabel`, `addressLabel`
  (identical text in both tones — matches the existing pattern where entity
  titles/field labels stayed neutral even in the original playful pass);
  reused the existing `email`/`notes`/`required`/`save` keys rather than
  duplicating them.
- **Fixed a real localization bug in `PitStopStepper`**: the three stop
  labels (Draft/Completed/Paid) were built by capitalizing the raw English
  status enum value (`label[0].toUpperCase() + ...`), completely bypassing
  localization — a Turkish user would see "Draft" hardcoded inside the
  stepper even though the identical status already renders correctly
  ("Taslak") in the work-order list's filter chips one screen over. Now
  uses the same `l.draft`/`l.completed`/`l.paid` getters everywhere else in
  the app uses.
- **Removed a leftover dev-note that was shipping as real UI text**:
  `PitStopStepper` rendered `'✨ micro-animation slot: confetti / Lottie
  burst plays here on status change'` as an actual `Text` widget below the
  status button — this was clearly implementation commentary for a future
  Lottie integration, not user-facing copy, and was about to ship
  translated into 4 language/tone combinations. Deleted the widget; the
  underlying "leave room for a future success animation" intent is
  unaffected since nothing else depended on that text being there.
  _Files: `frontend/lib/core/locale/tone_provider.dart` (new),
  `frontend/lib/core/widgets/tone_toggle.dart` (new),
  `frontend/lib/l10n/app_en_CP.arb`, `frontend/lib/l10n/app_tr_CP.arb` (new),
  `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations*.dart`, `frontend/lib/app.dart`,
  `frontend/lib/core/widgets/{app_shell,profile_completeness_bar,
  pit_stop_stepper,streak_badge}.dart`,
  `frontend/lib/features/auth/presentation/{login_screen,register_screen}.dart`,
  `frontend/lib/features/clients/presentation/client_form_sheet.dart`,
  `frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`_

---

## [0.8.1] — 2026-08-01  *(Playful Copy Pass — "Garage Voice" Localization)*

### Changed

#### Frontend
- **Rewrote ~22 of the app's existing English and Turkish strings in a
  playful "garage" voice**, from JSON exports Farzad supplied
  (`Desktop\logs\app_argo_{en,tr}.json`) — goal is to read as a garage's own
  tool, not generic SaaS copy. Examples: `logIn` "Log in" → "Punch In" /
  "Giriş Yap" → "Mesaiye Başla"; `delete` "Delete" → "Scrap it" / "Sil" →
  "Hurdaya Ayır"; the three work-order status labels `draft`/`completed`/`paid`
  "Draft/Completed/Paid" → "On the Lift"/"Fixed & Ready"/"Cashed Out" (Turkish:
  "Taslak/Tamamlandı/Ödendi" → "Lifte Alındı"/"Tamir Tamam"/"Kasa Doldu");
  several empty-state messages became one-liners ("No work orders yet" →
  "Clean hands today? Time to pop a hood and start a job!").
  Merged key-by-key into `app_en.arb`/`app_tr.arb` (not a wholesale file
  replace) — verified first that both supplied JSON files have exactly the
  same key set as the existing ARBs (no additions, no drops) and that every
  `{placeholder}` token in each changed value still matches its ARB
  `@key`/`placeholders` metadata, so nothing here required touching the
  metadata blocks or breaking `flutter gen-l10n`. Regenerated
  `lib/generated/app_localizations*.dart` from the merged ARBs.
  Verified in-browser in both languages: work-order status filter chips read
  "On the Lift / Fixed & Ready / Cashed Out" in English and "Lifte Alındı /
  Tamir Tamam / Kasa Doldu" in Turkish.

  **Not included:** the gamification-specific strings added in v0.8.0
  (`ProfileCompletenessBar`'s "Garage Completeness"/"Fully tuned! 🔧",
  `PitStopStepper`'s "THE PIT STOP", `StreakBadge`'s "DAY STREAK") — the
  supplied JSON files only covered the pre-existing ARB keys, not those new
  hardcoded strings. Still a known gap, see DECISIONS.md.
  _Files: `frontend/lib/l10n/app_en.arb`, `frontend/lib/l10n/app_tr.arb`,
  `frontend/lib/generated/app_localizations.dart`,
  `frontend/lib/generated/app_localizations_en.dart`,
  `frontend/lib/generated/app_localizations_tr.dart`_

---

## [0.8.0] — 2026-08-01  *("GarajOS" Gamified Redesign — Dark Theme, Streak/Completeness/Pit-Stop Widgets*)

### Added
- **Full dark "garage" visual redesign**, applied from a set of pre-built
  screen/theme files Farzad supplied (`Desktop\logs\GarajOS gamified
  redesign.zip`). `core/theme/app_theme.dart` was rewritten around a new
  `AppColors` palette (deep navy/slate background, neon-green primary,
  electric-blue/vivid-orange accents) instead of the old SeaGreen
  `ColorScheme.fromSeed` Material default, with matching `cardTheme`,
  `chipTheme`, `navigationRailTheme`/`navigationBarTheme`, and
  `inputDecorationTheme`. `app.dart` now sets `themeMode: ThemeMode.dark`
  (the redesign is dark-mode-first by design; `AppTheme.light()` is kept only
  as an inert fallback in case that's ever changed back to
  `ThemeMode.system`).
- **New gamified widgets** (`frontend/lib/core/widgets/`):
  - `StreakBadge` — flame pill in the AppBar showing a "day streak."
  - `ProfileCompletenessBar` — "Garage Completeness" progress bar on the
    Client and Vehicle forms, live-updating as required-ish fields fill in.
  - `PitStopStepper` — replaces the flat status `Chip` on the work order
    detail screen with a Draft → Completed → Paid progression stepper.
  - `TopWrenchLeaderboard` — weekly mechanic leaderboard by jobs closed.
    **Not wired into any screen**: `work_orders` has no assigned-mechanic
    column (see DECISIONS.md), so there's no real data to feed it yet: it
    sits in the widget library, unused, for whenever that column exists.

  **Completed two things the supplied files left as TODOs, rather than
  shipping them broken/fake:**
  1. **Fonts.** The supplied files reference `fontFamily: 'Montserrat'` /
     `'Poppins'` / `'RobotoMono'` as raw string literals — those aren't real
     registered fonts, so every one would have silently fallen back to the
     platform default (the files' own comments flagged this as needing
     `google_fonts` or bundled assets, not yet wired up). Added the
     `google_fonts` package and an `AppFonts` helper
     (`core/theme/app_theme.dart`) that every such call site now goes
     through, so headers/body/numeric text actually render in the intended
     typefaces.
  2. **The streak was hardcoded.** `app_shell.dart` shipped with
     `const streakDays = 12;` and a `// TODO: wire to a real
     streakDaysProvider`. Added that provider
     (`features/reports/application/reports_provider.dart`): it derives the
     streak from the existing day-grouped revenue report — consecutive days,
     ending today, with at least one work order actually marked paid — so
     the badge shows real per-shop data (0 for a brand-new shop) instead of
     a fabricated number.
  - `app_shell.dart`'s title emoji (`🔌`) and `work_orders_master_list.dart`'s
    empty-state emoji were both swapped for the real logo asset
    (`assets/branding/logo.png`, added in v0.7.0) instead of shipping the
    placeholder emoji the supplied files used — the "swap the emoji for the
    real illustration asset once it lands" comment in the master list file
    was already satisfied by the time this was applied.
- **Not localized:** the gamified copy (`"Garage Completeness"`, `"Fully
  tuned! 🔧"`, `"THE PIT STOP"`, `"DAY STREAK"`, client/vehicle form field
  labels) is English-only, same as the pre-existing (already-unlocalized)
  parts of `client_form_sheet.dart` it was added to. Not addressed in this
  pass — full i18n coverage for the new gamification strings is future work.

Verified: `flutter analyze` clean (zero issues beyond one pre-existing
unrelated `dart:html` deprecation info), `flutter build web --release`
succeeds, and manually exercised in-browser end-to-end — registered a fresh
test shop, confirmed the dark theme renders on login/register, created a
client (watched `ProfileCompletenessBar` update live 0% → 20% → 40%),
created a vehicle (confirmed the license-plate field renders in the real
monospace font, confirmed `ProfileCompletenessBar` reuse), and confirmed the
AppBar's `StreakBadge` correctly shows a real **0** for the brand-new shop
(no paid work orders yet) rather than a fake number.
_Files: `frontend/lib/core/theme/app_theme.dart`,
`frontend/lib/core/widgets/{app_shell,streak_badge,profile_completeness_bar,
pit_stop_stepper,top_wrench_leaderboard}.dart` (4 new),
`frontend/lib/features/reports/application/reports_provider.dart`,
`frontend/lib/features/clients/presentation/client_form_sheet.dart`,
`frontend/lib/features/vehicles/presentation/vehicle_form_sheet.dart`,
`frontend/lib/features/work_orders/presentation/{work_order_detail_panel,
work_orders_master_list}.dart`, `frontend/lib/app.dart`,
`frontend/pubspec.yaml`_

---

## [0.7.0] — 2026-08-01  *(Real Brand Logo — Replaces Placeholder Mascot Icon, Adds Social Share Preview)*

### Added
- **Swapped the v0.6.0 placeholder wrench-mascot icon for the actual provided
  brand logo** — a robot-spark-plug mascot (thumbs up + wrench, neon-green on
  dark navy) supplied as `GarajOS Logo NB.PNG` (transparent) and
  `GarajOS App Logo.PNG` (flat background) in `Desktop\logs`. The transparent
  variant is the new source of truth: `assets/branding/logo-master.png`
  (raster; no vector source was provided this time, unlike the v0.6.0 SVG).
  `assets/branding/logo-square-1024.png` is a derived, centered/padded square
  crop (tight content bbox + 12% margin) that every other size is resized
  from — regenerate it (and everything downstream) if the master art changes.
  Old `assets/branding/logo.svg` and `logo-1024.png` deleted (superseded).
  - **Regenerated every consumer** from the new master: `frontend/web/favicon.png`,
    `frontend/web/icons/{Icon-192,Icon-512,Icon-maskable-192,Icon-maskable-512}.png`,
    `frontend/android/app/src/main/res/mipmap-*/ic_launcher.png`,
    `frontend/windows/runner/resources/app_icon.ico`. Plain/mipmap/ICO icons
    render the mascot at 82% of the canvas on an opaque navy backdrop
    (`#040E21`, sampled from the provided flat logo); maskable icons use 62%
    to stay inside the safe zone under a circular mask.
  - **Windows ICO generated natively with Pillow** this time
    (`Image.save(..., sizes=[(16,16)...(256,256)])`) instead of the
    `sharp` + `png-to-ico` Node scratch-script from v0.6.0 — Pillow was
    already available on this machine and produces the full multi-resolution
    ICO from one call.
- **Social share preview (WhatsApp / Telegram / Facebook / Slack link
  unfurling)** — new `frontend/web/og-image.png` (1200×630, mascot centered
  on the navy backdrop) plus `og:title`/`og:description`/`og:image` and
  `twitter:card`/`twitter:image` meta tags added to `frontend/web/index.html`.
  This app previously had no Open Graph tags at all, so shared links rendered
  as bare text with no preview card.
- **Logo now appears inside the app, not just as an icon:**
  - `login_screen.dart` — replaced the generic `Icons.build_circle` Material
    icon above the sign-in form with the real mascot logo.
  - `app_shell.dart` — the authenticated app bar's title now shows the logo
    next to the app name, on every screen.
  - New Flutter asset `frontend/assets/branding/logo.png` (512×512,
    transparent) registered via `assets/branding/` in `pubspec.yaml` — kept
    transparent (unlike the opaque icon renders) so it reads correctly on
    both the light and dark Material themes without a mismatched background
    box.

  **Not changed:** `manifest.json`'s `theme_color`/`background_color` and
  `index.html`'s `<meta name="theme-color">` stay at the existing SeaGreen
  `#2E8B57` — that value mirrors `app_theme.dart`'s actual Material seed
  color (the real in-app chrome color), not the new logo artwork's own dark
  backdrop, so changing it would reintroduce the exact mismatch v0.6.0 fixed
  in the other direction. Only the icon glyphs and the dedicated OG banner
  use the new navy backdrop.

  Verified: rebuilt the web bundle, restarted the `web` container, hard-
  reloaded past the service worker, and confirmed in-browser that the login
  page shows the new mascot and that `favicon.png`/`og-image.png`/the new
  icon PNGs all serve with the regenerated bytes.
  _Files: `assets/branding/logo-master.png`, `assets/branding/logo-square-1024.png`
  (new); `assets/branding/logo.svg`, `logo-1024.png` (deleted);
  `frontend/web/favicon.png`, `frontend/web/icons/*.png`,
  `frontend/web/og-image.png` (new), `frontend/web/index.html`,
  `frontend/android/app/src/main/res/mipmap-*/ic_launcher.png`,
  `frontend/windows/runner/resources/app_icon.ico`,
  `frontend/assets/branding/logo.png` (new), `frontend/pubspec.yaml`,
  `frontend/lib/features/auth/presentation/login_screen.dart`,
  `frontend/lib/core/widgets/app_shell.dart`_

---

## [0.6.0] — 2026-07-31  *(Branded App Icon — Replaces Flutter Placeholder Artwork)*

### Added
- **Real app icon/logo, replacing the default Flutter scaffold artwork**
  A wrench mark (closed ring end + open-jaw end, on a solid rounded-square
  background in the app's existing SeaGreen brand colour `#2E8B57` — the same
  seed colour `app_theme.dart` already uses) designed as a single master SVG
  and rasterized to every size each platform needs. Resolves the "PWA icons"
  row in `DECISIONS.md`'s Known Limitations.
  - **Source of truth:** `assets/branding/logo.svg` (1024×1024 master) and a
    pre-rendered `assets/branding/logo-1024.png`, kept outside `frontend/` so
    they aren't tied to one platform target and can be re-rendered for any
    future consumer.
  - **Web/PWA:** `frontend/web/favicon.png` (48×48), and all four manifest
    icons — `Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`,
    `Icon-maskable-512.png`. The design keeps the wrench within the inner 80%
    "safe zone" (scaled to 0.85 before an already-conservative layout) against
    a full-bleed solid background, so the same artwork is valid for both
    plain and maskable manifest entries.
  - **Android:** `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` (48/72/96/144/192px).
  - **Windows:** `windows/runner/resources/app_icon.ico`, a proper
    multi-resolution ICO (16/32/48/64/128/256) generated via `png-to-ico`
    rather than a single upscaled PNG renamed to `.ico`.
  - **Theme colour mismatch fixed alongside it:** `web/index.html`'s
    `<meta name="theme-color">` and `web/manifest.json`'s `theme_color` were
    still Flutter's scaffold default blue (`#0175C2`), which never matched
    the app's actual green theme — both now use `#2E8B57`. This is what
    tints the browser/PWA chrome (mobile address bar, task switcher) so it
    now matches the icon and the in-app colour scheme instead of clashing.

  No source SVG/PNG rasterizer was available on this machine (no ImageMagick/
  Inkscape/rsvg-convert); generated everything with `sharp` + `png-to-ico` via
  a throwaway Node script in the scratch directory — not added as a project
  dependency, since regenerating the icon set is an infrequent, manual task.
  Verified: rebuilt the web bundle, restarted the `web` container, confirmed
  the new favicon bytes and `theme-color` are served, and visually inspected
  the generated PNGs (icons/Icon-512.png, favicon.png, an Android mipmap) to
  confirm the wrench renders correctly and holds up down to favicon size.
  _Files: `assets/branding/logo.svg`, `assets/branding/logo-1024.png`,
  `frontend/web/favicon.png`, `frontend/web/icons/*.png`,
  `frontend/web/index.html`, `frontend/web/manifest.json`,
  `frontend/android/app/src/main/res/mipmap-*/ic_launcher.png`,
  `frontend/windows/runner/resources/app_icon.ico`_

---

## [0.5.2] — 2026-07-31  *(Turkish Wording Change — "İş Emri" → "Servis Kaydı", ARB/generated re-sync)*

### Changed

#### Frontend
- **"Work Order" terminology re-translated in Turkish**
  Changed from "İş Emri" ("work order/job order") to "Servis Kaydı" ("service
  record") across the work-orders section: nav label, empty-state messages,
  the new/delete dialog titles, and the per-order title format.
  _Keys: `workOrders`, `noWorkOrdersYet`, `newWorkOrder`, `noWorkOrders`,
  `deleteWorkOrderTitle`, `deleteWorkOrderBody`, `orderNo`,
  `noPaidWorkOrdersInRange`._

### Fixed
- **Wording change had been applied to the generated file only, not the ARB
  source** — this change was originally committed by editing
  `app_localizations_tr.dart` directly rather than `app_tr.arb`. Since
  `app_tr.arb` is the source of truth and `flutter gen-l10n` regenerates the
  Dart file from it, the next regeneration (e.g. for an unrelated ARB key
  change) would have silently reverted this wording back to "İş Emri".
  Backfilled the same wording into `app_tr.arb` and re-ran `flutter gen-l10n`
  to confirm it now reproduces the generated file byte-for-byte (zero diff).
  Rebuilt the Flutter web bundle and restarted the `web` container; verified
  "Servis Kaydı" renders live in the browser.
  _Files: `frontend/lib/l10n/app_tr.arb`_

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
