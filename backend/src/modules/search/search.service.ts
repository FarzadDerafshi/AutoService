import { PoolClient } from "pg";
import { toCamelList } from "../../utils/mapKeysToCamel";
import { normalizePlate } from "../../utils/licensePlate";

const RESULT_LIMIT = 10;

// Prioritizes license-plate matches (exact/prefix) above fuzzy name/phone
// matches, per the global-search requirement in the architecture doc.
export async function searchAll(db: PoolClient, q: string) {
  const normalizedPlate = normalizePlate(q);

  const { rows: vehicles } = await db.query(
    `SELECT * FROM vehicles
     WHERE license_plate ILIKE $1
     ORDER BY (license_plate = $2) DESC, (license_plate ILIKE $3) DESC, license_plate ASC
     LIMIT $4`,
    [`%${normalizedPlate}%`, normalizedPlate, `${normalizedPlate}%`, RESULT_LIMIT]
  );

  const { rows: clients } = await db.query(
    `SELECT * FROM clients
     WHERE full_name ILIKE $1 OR phone ILIKE $1 OR email ILIKE $1
     ORDER BY full_name ASC
     LIMIT $2`,
    [`%${q}%`, RESULT_LIMIT]
  );

  const isNumeric = /^\d+$/.test(q);
  const { rows: workOrders } = isNumeric
    ? await db.query(
        `SELECT wo.*, c.full_name AS client_name, v.license_plate AS vehicle_plate
         FROM work_orders wo
         JOIN clients c ON c.id = wo.client_id
         JOIN vehicles v ON v.id = wo.vehicle_id
         WHERE wo.order_no = $1
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
