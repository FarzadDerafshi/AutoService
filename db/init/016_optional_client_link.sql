-- Walk-in support: a shop's real identity key for a car is the license
-- plate (already enforced by vehicles' UNIQUE (shop_id, license_plate)),
-- not the client record. Many walk-ins never give contact details at all
-- — only the plate. Relaxing both FKs to nullable, not just vehicles', is
-- required: a work order still hard-requiring a client would make a
-- client-less vehicle impossible to actually service.
--
-- Purely additive — every existing row already has a client_id, this only
-- relaxes the constraint for new rows going forward. ON DELETE RESTRICT is
-- unaffected by nullability (a NULL client_id has nothing to restrict).
ALTER TABLE vehicles ALTER COLUMN client_id DROP NOT NULL;
ALTER TABLE work_orders ALTER COLUMN client_id DROP NOT NULL;
