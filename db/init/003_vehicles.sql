CREATE TABLE vehicles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shop_id         UUID NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    client_id       UUID NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    license_plate   VARCHAR(20) NOT NULL, -- normalized: uppercase, no spaces
    make            VARCHAR(50),
    model           VARCHAR(50),
    engine_type     VARCHAR(50), -- e.g. "1.4 16V"
    year            SMALLINT,
    current_mileage_km INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (shop_id, license_plate)
);

CREATE INDEX idx_vehicles_shop_id ON vehicles(shop_id);
CREATE INDEX idx_vehicles_plate ON vehicles(shop_id, license_plate);
CREATE INDEX idx_vehicles_client_id ON vehicles(client_id);
