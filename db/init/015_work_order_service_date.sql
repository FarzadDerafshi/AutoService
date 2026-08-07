-- The user-facing "date" on a work order — distinct from created_at, which
-- stays a pure system audit timestamp (when the row was inserted) and is
-- never edited. service_date is what actually prints on the slip/PDF and
-- what the shop backdates when entering a repair that happened before
-- today. DATE, not TIMESTAMPTZ — this is a calendar date, not a moment in
-- time, and keeping it that type sidesteps timezone-shift bugs entirely
-- (see config/db.ts's DATE type-parser override, which keeps this column
-- as a plain "YYYY-MM-DD" string everywhere in the stack, never a JS Date).
ALTER TABLE work_orders ADD COLUMN service_date DATE NOT NULL DEFAULT CURRENT_DATE;

CREATE INDEX idx_wo_service_date ON work_orders(shop_id, service_date DESC);
