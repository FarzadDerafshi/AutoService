CREATE TABLE work_order_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    work_order_id   UUID NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
    catalog_item_id UUID REFERENCES catalog_items(id) ON DELETE SET NULL,
    description     VARCHAR(255) NOT NULL, -- snapshot, editable even if catalog item changes later
    quantity        NUMERIC(10,2) NOT NULL DEFAULT 1,
    unit_price      NUMERIC(10,2) NOT NULL DEFAULT 0,
    line_total      NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
    sort_order      SMALLINT NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_woi_work_order_id ON work_order_items(work_order_id);
CREATE INDEX idx_woi_catalog_item_id ON work_order_items(catalog_item_id);
