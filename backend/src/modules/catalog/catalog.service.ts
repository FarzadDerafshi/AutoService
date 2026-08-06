import { PoolClient } from "pg";
import { NotFoundError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { CreateCatalogItemInput, UpdateCatalogItemInput } from "./catalog.schema";

// RLS on this table is defense-in-depth only (see db/init/008_row_level_security.sql) —
// the connecting DB role owns these tables, and Postgres exempts table owners from RLS
// by default, so every query here must explicitly scope by shop_id itself.
const SHOP_SCOPE = "shop_id = current_setting('app.current_shop_id')::uuid";

// Master-data Autocomplete pattern (DECISIONS.md) — small, active-only result
// set for search-as-you-type (excludes deactivated items — see
// deleteCatalogItem below — since those shouldn't be pickable into new work
// orders), unlike listCatalogItems' unbounded, all-items query below.
const SEARCH_LIMIT = 15;

export async function searchCatalogItems(db: PoolClient, q: string, type?: string) {
  const conditions = [SHOP_SCOPE, "is_active = true", "(name ILIKE $1 OR sku ILIKE $1)"];
  const params: unknown[] = [`%${q}%`];
  if (type) {
    params.push(type);
    conditions.push(`type = $${params.length}`);
  }
  params.push(SEARCH_LIMIT);
  const { rows } = await db.query(
    `SELECT * FROM catalog_items WHERE ${conditions.join(" AND ")} ORDER BY name ASC LIMIT $${params.length}`,
    params
  );
  return toCamelList(rows);
}

export async function listCatalogItems(db: PoolClient, filters: { type?: string; search?: string }) {
  const conditions: string[] = [SHOP_SCOPE];
  const params: unknown[] = [];

  if (filters.type) {
    params.push(filters.type);
    conditions.push(`type = $${params.length}`);
  }
  if (filters.search) {
    params.push(`%${filters.search}%`);
    conditions.push(`(name ILIKE $${params.length} OR sku ILIKE $${params.length})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const { rows } = await db.query(`SELECT * FROM catalog_items ${where} ORDER BY name ASC`, params);
  return { data: toCamelList(rows) };
}

export async function getCatalogItemById(db: PoolClient, id: string) {
  const { rows } = await db.query(`SELECT * FROM catalog_items WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
  if (!rows[0]) throw new NotFoundError("Catalog item not found");
  return toCamel(rows[0]);
}

export async function createCatalogItem(db: PoolClient, input: CreateCatalogItemInput) {
  const { rows } = await db.query(
    `INSERT INTO catalog_items (shop_id, type, sku, name, unit, default_unit_price)
     VALUES (current_setting('app.current_shop_id')::uuid, $1, $2, $3, $4, $5)
     RETURNING *`,
    [input.type, input.sku || null, input.name, input.unit || "adet", input.defaultUnitPrice]
  );
  return toCamel(rows[0]);
}

export async function updateCatalogItem(db: PoolClient, id: string, input: UpdateCatalogItemInput) {
  await getCatalogItemById(db, id);

  const fields: string[] = [];
  const params: unknown[] = [];
  const push = (column: string, value: unknown) => {
    params.push(value);
    fields.push(`${column} = $${params.length}`);
  };

  if (input.type !== undefined) push("type", input.type);
  if (input.sku !== undefined) push("sku", input.sku || null);
  if (input.name !== undefined) push("name", input.name);
  if (input.unit !== undefined) push("unit", input.unit);
  if (input.defaultUnitPrice !== undefined) push("default_unit_price", input.defaultUnitPrice);
  if (input.isActive !== undefined) push("is_active", input.isActive);

  if (fields.length === 0) {
    return getCatalogItemById(db, id);
  }

  params.push(id);
  const { rows } = await db.query(
    `UPDATE catalog_items SET ${fields.join(", ")} WHERE id = $${params.length} AND ${SHOP_SCOPE} RETURNING *`,
    params
  );
  return toCamel(rows[0]);
}

export async function deleteCatalogItem(db: PoolClient, id: string) {
  await getCatalogItemById(db, id);

  const { rows: referenced } = await db.query(`SELECT 1 FROM work_order_items WHERE catalog_item_id = $1 LIMIT 1`, [id]);

  if (referenced.length > 0) {
    await db.query(`UPDATE catalog_items SET is_active = false WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
  } else {
    await db.query(`DELETE FROM catalog_items WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
  }
}
