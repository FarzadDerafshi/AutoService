// Simple compile-time on/off switches for temporarily hiding a feature
// without ripping out the underlying implementation. Flip back to `true`
// (or delete the flag once a feature is permanent) rather than deleting
// the code it guards. Mirrors frontend/lib/core/config/feature_flags.dart
// — there's no shared config between the two apps, so keep both in sync
// by hand when either changes.

// Whether order-level VAT/tax and discount lines are printed on the work
// order PDF. Hidden per Farzad's request (2026-08-06) — a pricing
// simplification, not a data change: discount_amount/tax_rate/tax_amount
// and the grand_total calculation are untouched, so this can be flipped
// back to `true` later with no migration needed.
export const ORDER_TAX_AND_DISCOUNT_VISIBLE = false;
