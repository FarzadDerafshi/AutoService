// Simple compile-time on/off switches for temporarily hiding a feature
// without ripping out the underlying implementation. Flip back to `true`
// (or delete the flag once a feature is permanent) rather than deleting
// the code it guards.

/// Whether new shops can self-register. Turned off during the public
/// usability test (Farzad's request) so nobody can create a real shop
/// account while testing is in progress — until he says otherwise. Blocks
/// both the "Create account" link on the login screen and direct
/// navigation to `/register` (see `app.dart`'s router `redirect`).
const kRegistrationOpen = false;

/// Whether order-level VAT/tax and discount are shown anywhere in the app
/// — the work order form's input fields, the totals breakdown on the
/// detail panel, and the printed PDF (see `backend/src/config/
/// featureFlags.ts`'s `ORDER_TAX_AND_DISCOUNT_VISIBLE`, kept in sync
/// manually). Hidden per Farzad's request (2026-08-06) — a pricing
/// simplification, not a data change: `discountAmount`/`taxRate`/
/// `taxAmount` and the grand-total calculation are untouched, so this can
/// be flipped back to `true` later with no migration needed.
const kOrderTaxAndDiscountVisible = false;
