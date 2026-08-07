-- Snapshot the catalog item's unit of measure (e.g. "adet", "lt", "saat")
-- onto each work order line at add-time, same precedent as `description`
-- and `unit_price` (db/init/006_work_order_items.sql): stays meaningful
-- even if the catalog item's own unit is edited or the item is deleted
-- later. NULL for custom line items with no catalog link.
ALTER TABLE work_order_items ADD COLUMN unit VARCHAR(20);
