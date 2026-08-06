-- Trigram indexes backing the master-data search-as-you-type endpoints
-- (clients/vehicles/catalog "/search", see DECISIONS.md's "Master-data
-- search-autocomplete pattern"). clients.full_name already had one
-- (002_clients.sql); vehicles.license_plate and catalog_items.name/sku did
-- not, so ILIKE '%term%' substring search on those columns was a sequential
-- scan. pg_trgm is already enabled (000_extensions.sql).
CREATE INDEX idx_vehicles_plate_trgm ON vehicles USING gin (license_plate gin_trgm_ops);
CREATE INDEX idx_catalog_name_trgm ON catalog_items USING gin (name gin_trgm_ops);
CREATE INDEX idx_catalog_sku_trgm ON catalog_items USING gin (sku gin_trgm_ops);
