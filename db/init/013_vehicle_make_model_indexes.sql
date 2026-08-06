-- Trigram indexes backing the new /vehicles/makes/search and
-- /vehicles/models/search endpoints (Marka/Model master-data autocomplete,
-- see DECISIONS.md's "Master-data search-autocomplete pattern"). Neither
-- column had any index before this — vehicles' only prior indexes covered
-- shop_id, license_plate, and client_id (003_vehicles.sql).
CREATE INDEX idx_vehicles_make_trgm ON vehicles USING gin (make gin_trgm_ops);
CREATE INDEX idx_vehicles_model_trgm ON vehicles USING gin (model gin_trgm_ops);
