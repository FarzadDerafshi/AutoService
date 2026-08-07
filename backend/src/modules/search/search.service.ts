import { PoolClient } from "pg";
import { toCamelList } from "../../utils/mapKeysToCamel";
import { normalizePlate } from "../../utils/licensePlate";

const RESULT_LIMIT = 10;

// RLS on these tables is defense-in-depth only (see db/init/008_row_level_security.sql) —
// the connecting DB role owns these tables, and Postgres exempts table owners from RLS
// by default, so every query here must explicitly scope by shop_id itself.
const SHOP_SCOPE = "shop_id = current_setting('app.current_shop_id')::uuid";

// Prioritizes license-plate matches (exact/prefix) above fuzzy name/phone
// matches, per the global-search requirement in the architecture doc.
export async function searchAll(db: PoolClient, q: string) {
  const normalizedPlate = normalizePlate(q);

  const { rows: vehicles } = await db.query(
    `SELECT * FROM vehicles
     WHERE license_plate ILIKE $1 AND ${SHOP_SCOPE}
     ORDER BY (license_plate = $2) DESC, (license_plate ILIKE $3) DESC, license_plate ASC
     LIMIT $4`,
    [`%${normalizedPlate}%`, normalizedPlate, `${normalizedPlate}%`, RESULT_LIMIT]
  );

  const { rows: clients } = await db.query(
    `SELECT * FROM clients
     WHERE (full_name ILIKE $1 OR phone ILIKE $1 OR email ILIKE $1) AND ${SHOP_SCOPE}
     ORDER BY full_name ASC
     LIMIT $2`,
    [`%${q}%`, RESULT_LIMIT]
  );

  const isNumeric = /^\d+$/.test(q);
  const { rows: workOrders } = isNumeric
    ? await db.query(
        `SELECT wo.*, c.full_name AS client_name, v.license_plate AS vehicle_plate
         FROM work_orders wo
         LEFT JOIN clients c ON c.id = wo.client_id
         JOIN vehicles v ON v.id = wo.vehicle_id
         WHERE wo.order_no = $1 AND wo.shop_id = current_setting('app.current_shop_id')::uuid
         LIMIT $2`,
        [Number(q), RESULT_LIMIT]
      )
    : { rows: [] as Record<string, unknown>[] };

  return {
    clients: toCamelList(clients),
    vehicles: toCamelList(vehicles),
    workOrders: toCamelList(workOrders),
  };
}
