CREATE TYPE work_order_status AS ENUM ('draft', 'completed', 'paid');
CREATE TYPE payment_method AS ENUM ('cash', 'card', 'bank_transfer', 'other');

CREATE TABLE work_orders (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id         UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    order_no        SERIAL, -- human-friendly sequential number per DB (see note below)
    client_id       UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    vehicle_id      UUID NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    mileage_at_service INTEGER,
    status          work_order_status NOT NULL DEFAULT 'draft',
    payment_method  payment_method,
    subtotal        NUMERIC(10,2) NOT NULL DEFAULT 0,
    discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    tax_rate        NUMERIC(5,2) NOT NULL DEFAULT 0, -- percentage, e.g. 18.00
    tax_amount      NUMERIC(10,2) NOT NULL DEFAULT 0,
    grand_total     NUMERIC(10,2) NOT NULL DEFAULT 0,
    notes           TEXT,
    created_by      UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    paid_at         TIMESTAMPTZ
);

CREATE INDEX idx_wo_shop_id ON work_orders(shop_id);
CREATE INDEX idx_wo_vehicle_id ON work_orders(vehicle_id);
CREATE INDEX idx_wo_client_id ON work_orders(client_id);
CREATE INDEX idx_wo_status ON work_orders(shop_id, status);
CREATE INDEX idx_wo_created_at ON work_orders(shop_id, created_at DESC);

-- Note on order_no: a global SERIAL gives a simple monotonically increasing
-- number across all shops, which is sufficient at this scale (single-shop
-- deployments in practice). If per-shop sequential numbering is required
-- later, replace with a trigger keyed on MAX(order_no) WHERE shop_id = NEW.shop_id
-- or a dedicated shop_counters table to avoid race conditions under concurrent writes.
