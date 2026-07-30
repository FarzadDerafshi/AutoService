import { PoolClient } from "pg";
import { NotFoundError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { Pagination } from "../../utils/pagination";
import { CreateClientInput, UpdateClientInput } from "./clients.schema";

export async function listClients(db: PoolClient, search: string | undefined, pagination: Pagination) {
  const conditions: string[] = [];
  const params: unknown[] = [];

  if (search) {
    params.push(`%${search}%`);
    conditions.push(`(full_name ILIKE $${params.length} OR phone ILIKE $${params.length} OR email ILIKE $${params.length})`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

  const { rows: countRows } = await db.query(`SELECT COUNT(*)::int AS total FROM clients ${where}`, params);
  const total = countRows[0]?.total ?? 0;

  params.push(pagination.pageSize, pagination.offset);
  const { rows } = await db.query(
    `SELECT * FROM clients ${where} ORDER BY full_name ASC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  return { data: toCamelList(rows), total, page: pagination.page, pageSize: pagination.pageSize };
}

export async function getClientById(db: PoolClient, id: string) {
  const { rows } = await db.query(`SELECT * FROM clients WHERE id = $1`, [id]);
  if (!rows[0]) throw new NotFoundError("Client not found");
  return toCamel(rows[0]);
}

export async function createClient(db: PoolClient, input: CreateClientInput) {
  const { rows } = await db.query(
    `INSERT INTO clients (shop_id, full_name, phone, email, address, tax_id, notes)
     VALUES (current_setting('app.current_shop_id')::uuid, $1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [input.fullName, input.phone || null, input.email || null, input.address || null, input.taxId || null, input.notes || null]
  );
  return toCamel(rows[0]);
}

export async function updateClient(db: PoolClient, id: string, input: UpdateClientInput) {
  await getClientById(db, id);

  const fields: string[] = [];
  const params: unknown[] = [];
  const columnMap: Record<keyof UpdateClientInput, string> = {
    fullName: "full_name",
    phone: "phone",
    email: "email",
    address: "address",
    taxId: "tax_id",
    notes: "notes",
  };

  for (const [key, column] of Object.entries(columnMap)) {
    const value = (input as Record<string, unknown>)[key];
    if (value !== undefined) {
      params.push(value === "" ? null : value);
      fields.push(`${column} = $${params.length}`);
    }
  }

  if (fields.length === 0) {
    return getClientById(db, id);
  }

  params.push(id);
  const { rows } = await db.query(`UPDATE clients SET ${fields.join(", ")} WHERE id = $${params.length} RETURNING *`, params);
  return toCamel(rows[0]);
}

export async function deleteClient(db: PoolClient, id: string) {
  await getClientById(db, id);
  await db.query(`DELETE FROM clients WHERE id = $1`, [id]);
}
