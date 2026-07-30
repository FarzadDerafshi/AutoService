CREATE TYPE catalog_item_type AS ENUM ('service', 'part');

CREATE TABLE catalog_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id         UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    type            catalog_item_type NOT NULL,
    sku             VARCHAR(50), -- optional part number
    name            VARCHAR(150) NOT NULL, -- e.g. "Spark Plug", "Engine Oil Change (Labor)"
    unit            VARCHAR(20) DEFAULT 'unit', -- e.g. "unit", "hour", "liter"
    default_unit_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_catalog_shop_id ON catalog_items(shop_id);
CREATE INDEX idx_catalog_name ON catalog_items(shop_id, name);
