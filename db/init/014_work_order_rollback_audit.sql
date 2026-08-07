-- One row per rollback event (paid/completed -> draft). Deliberately its own
-- table, not a generic multi-entity audit log — work orders are the only
-- entity in this app that needs reversible-status auditing today.
--
-- work_order_id uses ON DELETE SET NULL, not CASCADE: a rollback sets the
-- order's status to 'draft', and draft orders are deletable
-- (see deleteWorkOrder in workOrders.service.ts) — CASCADE would let
-- deleting the now-draft order silently erase the very audit row proving
-- the rollback happened. Every prior_* column plus order_no/performed_by_name
-- is denormalized at write time so this row stays meaningful even after the
-- order (or the acting user) is later deleted.
CREATE TABLE work_order_rollbacks (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id               UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    work_order_id         UUID REFERENCES work_orders(id) ON DELETE SET NULL,

    order_no              INTEGER NOT NULL,
    from_status           work_order_status NOT NULL,
    to_status             work_order_status NOT NULL DEFAULT 'draft',
    reason                TEXT NOT NULL CHECK (char_length(trim(reason)) >= 3),

    performed_by          UUID REFERENCES users(id) ON DELETE SET NULL,
    performed_by_name     TEXT NOT NULL,
    performed_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    prior_payment_method  payment_method,
    prior_completed_at    TIMESTAMPTZ,
    prior_paid_at         TIMESTAMPTZ,
    prior_grand_total     NUMERIC(10,2) NOT NULL
);

CREATE INDEX idx_wo_rollbacks_shop_id    ON work_order_rollbacks(shop_id, performed_at DESC);
CREATE INDEX idx_wo_rollbacks_work_order ON work_order_rollbacks(work_order_id);
