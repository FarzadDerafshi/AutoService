ALTER TABLE shops
    ADD COLUMN tax_office  VARCHAR(150),
    ADD COLUMN address     TEXT,
    ADD COLUMN phone       VARCHAR(30),
    ADD COLUMN email       VARCHAR(150),
    ADD COLUMN logo_path   VARCHAR(255),
    ADD COLUMN updated_at  TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE TRIGGER trg_shops_updated_at BEFORE UPDATE ON shops
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
