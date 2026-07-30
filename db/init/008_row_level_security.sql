ALTER TABLE clients        ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE catalog_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE work_orders    ENABLE ROW LEVEL SECURITY;
ALTER TABLE users          ENABLE ROW LEVEL SECURITY;

-- The API sets this per-transaction via: SET LOCAL app.current_shop_id = '<uuid>';
CREATE POLICY shop_isolation_clients ON clients
    USING (shop_id = current_setting('app.current_shop_id', true)::uuid);
CREATE POLICY shop_isolation_vehicles ON vehicles
    USING (shop_id = current_setting('app.current_shop_id', true)::uuid);
CREATE POLICY shop_isolation_catalog ON catalog_items
    USING (shop_id = current_setting('app.current_shop_id', true)::uuid);
CREATE POLICY shop_isolation_work_orders ON work_orders
    USING (shop_id = current_setting('app.current_shop_id', true)::uuid);
CREATE POLICY shop_isolation_users ON users
    USING (shop_id = current_setting('app.current_shop_id', true)::uuid);

-- work_order_items has no shop_id directly; secure it via a join-based policy
ALTER TABLE work_order_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY shop_isolation_wo_items ON work_order_items
    USING (
        work_order_id IN (
            SELECT id FROM work_orders
            WHERE shop_id = current_setting('app.current_shop_id', true)::uuid
        )
    );

-- The API connects as the table-owning role (DB_USER from .env, the same role
-- Postgres creates the schema as), and table owners bypass RLS by default
-- unless FORCE ROW LEVEL SECURITY is set (it isn't here). That's what lets the
-- auth module (register/login) look up users by email before a shop_id is
-- known; every other query still gets scoped via SET LOCAL app.current_shop_id
-- in tenantScope.ts, and RLS remains a real backstop against a missing
-- WHERE shop_id = $1 in any of those scoped queries.
