# GarajOS — Coin Economy: Future Implementation Plan

**Status: Planned, not implemented.** No code, schema, or dependency in this
repo reflects anything below. This document exists so the architecture
doesn't need to be re-derived or re-argued when the team is ready to build
it — see "How to trigger implementation" at the bottom.

**Why it's parked:** GarajOS is currently in a self-registration-closed
pilot (`kRegistrationOpen = false`, see `DECISIONS.md`'s routing section).
Priority right now is quick-fix requests from the pilot user, not new
monetization infrastructure. This plan intentionally sits idle until the
pilot concludes.

---

## Confirmed product decisions (Farzad, 2026-08-07)

These are settled — not proposals, not open questions — and supersede the
corresponding "flagged as an open decision" language from the original
blueprint discussion:

1. **Coin balance is per-shop (tenant), not per-user.** Matches every
   other piece of business data in this app (`SHOP_SCOPE` pattern) — a
   technician spends the shop's coins, not a personal balance.

2. **Referral reward fires once: when the referred shop completes its
   first coin purchase, regardless of package size.** Not on signup, not
   on any usage/activation milestone — specifically gated on
   `coin_purchases.status` reaching `completed` for the first time for
   that shop. This was chosen deliberately to close the farming vector a
   signup-triggered or usage-triggered reward would leave open: a fake
   shop can be registered for free, but a real purchase is real money,
   which is what actually eliradicates abuse rather than just raising its
   cost. Implementation note: the purchase-completion handler (already
   idempotency-checked against `provider_reference` for webhook retries,
   see Section 1 below) is also the natural place to check "is this
   `shop_id`'s first `completed` row in `coin_purchases`" before firing
   the referrer's `referral_bonus_given` — one check, same transaction,
   no separate job needed.

3. **Self-registration stays closed until the pilot concludes and the
   coin economy (including the referral loop) is fully built.** Opening
   registration is a distinct, later go/no-day decision tied to
   readiness for growth/scale — not something that happens as a side
   effect of finishing this feature. Phase 6 below (the referral loop)
   is built *behind* this closed door and only becomes live the moment
   `kRegistrationOpen` is deliberately flipped, which is its own future
   decision, not part of "done" for this plan.

---

## 1. Database Schema & Ledger Architecture

- **Cached balance + immutable ledger**, kept in sync atomically in the
  same DB transaction — not a pure ledger-sum model. `shops.coin_balance`
  (`INTEGER NOT NULL DEFAULT 0 CHECK (coin_balance >= 0)`) plus a new
  `coin_transactions` table (one immutable row per credit/debit: `type`,
  signed `amount`, `balance_after` snapshot, typed nullable FKs
  `work_order_id`/`purchase_id`/`related_transaction_id`, `performed_by`,
  `note`, `created_at`).
- **No polymorphic `reference_type`/`reference_id`.** This codebase uses
  real typed foreign keys everywhere; the ledger keeps that convention
  rather than introducing a generic association pattern.
- **Double-spend prevention:** a single atomic conditional `UPDATE`:
  ```sql
  UPDATE shops SET coin_balance = coin_balance - $2
  WHERE id = $1 AND coin_balance >= $2
  RETURNING coin_balance;
  ```
  Zero rows returned = insufficient balance, checked and enforced in one
  statement with no read-then-write race window under concurrency.
- **Real-money purchases** get their own `coin_purchases` table
  (`pending -> completed/failed/refunded`), with a unique index on
  `(payment_provider, provider_reference)` so a payment provider's
  at-least-once webhook retry can never double-credit — this is the
  actual double-spend risk in this feature, more than concurrent API
  calls against the balance itself.
- **Referral columns on `shops`:** `referral_code` (unique, shareable) and
  `referred_by_shop_id`, captured at registration time.
- **Payment provider:** not yet chosen. Given this app is Turkish Lira,
  Turkish-tax-field, Turkish-locale-first end to end, the realistic
  candidates are **iyzico** or **PayTR** — Stripe has limited practical
  support for Turkish merchants. This is a business decision (fees,
  settlement) to make when Phase 5 starts, not now.

## 2. Backend API & Business Logic Layer

- New module `backend/src/modules/coins/` (schema/service/controller/
  routes), matching the existing per-domain module shape.
- Service functions: `getBalance`, `awardCoins`, `deductCoins`
  (throws a new `InsufficientCoinBalanceError`, `402`, carrying
  `{ required, available }`), `refundCoins`, `listTransactions`
  (paginated, same `Pagination` util every list endpoint already uses).
- **The "coin middleware" is a service-layer wrapper function
  (`withCoinCharge`), not Express middleware** — Express middleware can't
  cleanly know whether the wrapped operation succeeded, which is exactly
  what decides whether to refund.
- **Critical implementation constraint:** `withCoinCharge` must NOT use
  the request's `req.db` (the `tenantScope`-opened, whole-request-lifetime
  transaction). It runs its own short-lived transactions via
  `withTransaction`: deduct-and-commit, then the slow external call
  (Gemini, SMS provider, etc.) runs with **no transaction open at all**,
  then a separate commit-on-refund only if it failed. Doing this inside
  the shared per-request transaction would hold a pooled connection
  (`pool: max 10`) and a lock on the shop's balance row for the entire
  duration of a multi-second external call — a real production
  bottleneck under concurrent load, not a theoretical one.
- Endpoints: `GET /coins/balance`, `GET /coins/transactions`,
  `POST /coins/purchase`, and a **public** `POST /coins/purchase/webhook`
  (registered before `.use(authenticate, tenantScope)`, same pattern
  `invites.routes.ts` already uses for its two public routes).

## 3. Frontend Integration & UX Strategy (Flutter)

- Coin-balance chip in `app_shell.dart`'s AppBar, next to the existing
  streak badge — same gamified visual slot, not a new UI paradigm.
  Backed by a `coinBalanceProvider` (`FutureProvider.autoDispose`), same
  shape as every other data provider in this app.
- Cost preview inline on any coin-consuming button (e.g. "Scan with AI ·
  🪙 5"), sourced from a frontend constant that mirrors — but never
  substitutes for — the backend's own enforced cost.
- A `402` response (`{ required, available }`) drives a dedicated
  "Insufficient Balance" dialog with a "Top Up" CTA into a package
  screen, plugged into the existing `toApiException` error-handling
  pattern already used everywhere.
- **Real-time sync via plain `ref.invalidate` after each mutation** —
  the same pattern the rollback and draft-protection features already
  use. No WebSockets: every balance change is a direct result of an
  action the same client just took; this app has no real-time features
  anywhere today and this doesn't need to be the first.
- All new copy goes through the existing four-locale ARB convention
  (`en`/`tr`/`en_CP`/`tr_CP`).

## 4. Implementation Roadmap

| Phase | Scope | Depends on |
|---|---|---|
| 1 | DB schema + ledger, concurrency-tested | — |
| 2 | `coins` module, balance + history endpoints, `withCoinCharge` unit-tested against a fake operation | Phase 1 |
| 3 | Frontend balance chip + history screen | Phase 2 |
| 4 | Wire the first real consumer (AI scan or notifications, whichever ships first) through `withCoinCharge`; build the real cost-preview/402 UI against it | Phase 2–3, and that feature existing at all |
| 5 | Purchases: gateway decision (iyzico vs. PayTR), `coin_purchases` + webhook, idempotency-tested by replaying one webhook payload twice | Phase 1–2 |
| 6 | Referral loop: code generation, registration-time capture, first-purchase-triggered reward (Decision #2) | Phase 5, **and** the separate, later decision to reopen registration (Decision #3) |

Phases 1–3 touch no external systems and don't depend on any business
decision not already made — they're the safe part to start on whenever
work resumes. Phases 4–6 each still have a real open dependency (which
feature ships first, the gateway choice, the registration-reopen
decision) baked into the table above rather than glossed over.

---

## How to trigger implementation

This file — plus a pointer in project memory — is the entire handoff.
When you're ready, just say something like:

> **"Start Phase 1 of the coin economy plan."**

or reference it directly (`"implement COIN_ECONOMY_PLAN.md"`). A fresh
session doesn't need the original design conversation re-explained —
reading this file (and `DECISIONS.md` for the surrounding architecture
conventions it leans on) is enough context to start Phase 1 directly.
