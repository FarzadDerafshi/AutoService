-- One-time backfill for db/init/017_work_order_item_unit.sql: that
-- migration added the `unit` column, but only work order lines created
-- *after* the deploy get it populated (the frontend only snapshots it at
-- add-time). Every line item added before the deploy is stuck at NULL.
--
-- Backfills from the linked catalog item's *current* unit — the exact
-- value at the time the line was originally added isn't recoverable, but
-- a catalog item's unit rarely changes after creation, so "current" is a
-- reasonable stand-in for "what it almost certainly was". Custom
-- (non-catalog) line items have no catalog_item_id and are correctly left
-- NULL — there's nothing to backfill them from.
--
-- Idempotent (only touches rows where unit IS NULL) and a no-op on a
-- fresh install (no pre-existing rows to backfill), so it's safe to run
-- more than once or leave in db/init permanently.
UPDATE work_order_items woi
SET unit = ci.unit
FROM catalog_items ci
WHERE woi.catalog_item_id = ci.id
  AND woi.unit IS NULL
  AND ci.unit IS NOT NULL;
