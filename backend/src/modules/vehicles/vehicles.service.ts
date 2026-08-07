import { PoolClient } from "pg";
import { NotFoundError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { Pagination } from "../../utils/pagination";
import { normalizePlate } from "../../utils/licensePlate";
import { CreateVehicleInput, UpdateVehicleInput } from "./vehicles.schema";

// RLS on this table is defense-in-depth only (see db/init/008_row_level_security.sql) —
// the connecting DB role owns these tables, and Postgres exempts table owners from RLS
// by default, so every query here must explicitly scope by shop_id itself.
const SHOP_SCOPE = "shop_id = current_setting('app.current_shop_id')::uuid";

// Master-data Autocomplete pattern (DECISIONS.md) — small, uncounted result
// set for search-as-you-type. Prioritizes exact/prefix plate matches above
// fuzzy make/model matches, mirroring the global search bar's ordering
// (search.service.ts's searchAll). Joins the owner's name so the vehicle
// field can display/auto-fill the client without a second round-trip.
const SEARCH_LIMIT = 10;

export async function searchVehicles(db: PoolClient, q: string, clientId?: string) {
  const normalizedPlate = normalizePlate(q);
  const conditions = [
    `v.shop_id = current_setting('app.current_shop_id')::uuid`,
    `(v.license_plate ILIKE $1 OR v.make ILIKE $2 OR v.model ILIKE $2)`,
  ];
  const params: unknown[] = [`%${normalizedPlate}%`, `%${q}%`];
  if (clientId) {
    params.push(clientId);
    conditions.push(`v.client_id = $${params.length}`);
  }
  params.push(normalizedPlate, `${normalizedPlate}%`, SEARCH_LIMIT);
  const { rows } = await db.query(
    // LEFT JOIN — a walk-in vehicle has no client_id at all, and an INNER
    // JOIN here would silently drop it from every search result.
    `SELECT v.*, c.full_name AS client_name
     FROM vehicles v
     LEFT JOIN clients c ON c.id = v.client_id
     WHERE ${conditions.join(" AND ")}
     ORDER BY (v.license_plate = $${params.length - 2}) DESC,
              (v.license_plate ILIKE $${params.length - 1}) DESC,
              v.license_plate ASC
     LIMIT $${params.length}`,
    params
  );
  return toCamelList(rows);
}

// Distinct make/model values already used in this shop's own vehicles,
// most-frequent first — self-bootstrapping (a brand-new shop sees no
// suggestions until its first vehicle is entered) rather than a maintained
// reference table, since make/model have no id/FK of their own to look up.
const MAKE_MODEL_SEARCH_LIMIT = 10;

export async function searchMakes(db: PoolClient, q: string) {
  const { rows } = await db.query(
    `SELECT make FROM vehicles
     WHERE make IS NOT NULL AND make <> '' AND make ILIKE $1 AND ${SHOP_SCOPE}
     GROUP BY make
     ORDER BY COUNT(*) DESC, make ASC
     LIMIT $2`,
    [`%${q}%`, MAKE_MODEL_SEARCH_LIMIT]
  );
  return rows.map((r) => r.make as string);
}

export async function searchModels(db: PoolClient, q: string, make?: string) {
  const conditions = [`model IS NOT NULL`, `model <> ''`, `model ILIKE $1`, SHOP_SCOPE];
  const params: unknown[] = [`%${q}%`];
  if (make) {
    params.push(make);
    conditions.push(`make ILIKE $${params.length}`);
  }
  params.push(MAKE_MODEL_SEARCH_LIMIT);
  const { rows } = await db.query(
    `SELECT model FROM vehicles
     WHERE ${conditions.join(" AND ")}
     GROUP BY model
     ORDER BY COUNT(*) DESC, model ASC
     LIMIT $${params.length}`,
    params
  );
  return rows.map((r) => r.model as string);
}

export async function listVehicles(
  db: PoolClient,
  filters: { plate?: string; clientId?: string },
  pagination: Pagination
) {
  const conditions: string[] = [SHOP_SCOPE];
  const params: unknown[] = [];

  if (filters.plate) {
    params.push(`%${normalizePlate(filters.plate)}%`);
    conditions.push(`license_plate ILIKE $${params.length}`);
  }
  if (filters.clientId) {
    params.push(filters.clientId);
    conditions.push(`client_id = $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

  const { rows: countRows } = await db.query(`SELECT COUNT(*)::int AS total FROM vehicles ${where}`, params);
  const total = countRows[0]?.total ?? 0;

  params.push(pagination.pageSize, pagination.offset);
  const { rows } = await db.query(
    `SELECT * FROM vehicles ${where} ORDER BY created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  return { data: toCamelList(rows), total, page: pagination.page, pageSize: pagination.pageSize };
}

export async function getVehicleById(db: PoolClient, id: string) {
  const { rows } = await db.query(`SELECT * FROM vehicles WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
  if (!rows[0]) throw new NotFoundError("Vehicle not found");
  return toCamel(rows[0]);
}

export async function getVehicleHistory(db: PoolClient, id: string) {
  const vehicle = await getVehicleById(db, id);
  const { rows } = await db.query(
    `SELECT id, order_no, status, payment_method, subtotal, discount_amount, tax_rate,
            tax_amount, grand_total, mileage_at_service, created_at, completed_at, paid_at
     FROM work_orders WHERE vehicle_id = $1 AND ${SHOP_SCOPE} ORDER BY created_at DESC`,
    [id]
  );
  return { vehicle, workOrders: toCamelList(rows) };
}

export async function createVehicle(db: PoolClient, input: CreateVehicleInput) {
  const { rows } = await db.query(
    `INSERT INTO vehicles (shop_id, client_id, license_plate, make, model, engine_type, year, current_mileage_km, chassis_no, engine_no, color)
     VALUES (current_setting('app.current_shop_id')::uuid, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      input.clientId ?? null,
      normalizePlate(input.licensePlate),
      input.make || null,
      input.model || null,
      input.engineType || null,
      input.year ?? null,
      input.currentMileageKm ?? 0,
      input.chassisNo || null,
      input.engineNo || null,
      input.color || null,
    ]
  );
  return toCamel(rows[0]);
}

export async function updateVehicle(db: PoolClient, id: string, input: UpdateVehicleInput) {
  await getVehicleById(db, id);

  const fields: string[] = [];
  const params: unknown[] = [];

  const push = (column: string, value: unknown) => {
    params.push(value);
    fields.push(`${column} = $${params.length}`);
  };

  if (input.clientId !== undefined) push("client_id", input.clientId);
  if (input.licensePlate !== undefined) push("license_plate", normalizePlate(input.licensePlate));
  if (input.make !== undefined) push("make", input.make || null);
  if (input.model !== undefined) push("model", input.model || null);
  if (input.engineType !== undefined) push("engine_type", input.engineType || null);
  if (input.year !== undefined) push("year", input.year);
  if (input.currentMileageKm !== undefined) push("current_mileage_km", input.currentMileageKm);
  if (input.chassisNo !== undefined) push("chassis_no", input.chassisNo || null);
  if (input.engineNo !== undefined) push("engine_no", input.engineNo || null);
  if (input.color !== undefined) push("color", input.color || null);

  if (fields.length === 0) {
    return getVehicleById(db, id);
  }

  params.push(id);
  const { rows } = await db.query(
    `UPDATE vehicles SET ${fields.join(", ")} WHERE id = $${params.length} AND ${SHOP_SCOPE} RETURNING *`,
    params
  );
  return toCamel(rows[0]);
}

export async function deleteVehicle(db: PoolClient, id: string) {
  await getVehicleById(db, id);
  await db.query(`DELETE FROM vehicles WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
}
