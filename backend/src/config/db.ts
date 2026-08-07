import { Pool, PoolClient, types } from "pg";
import { env } from "./env";
import { logger } from "../utils/logger";

// NUMERIC columns (money, quantities) come back from pg as strings by default
// to avoid float-precision surprises at arbitrary scale. This app's amounts
// fit comfortably in a JS double at NUMERIC(10,2)/(5,2), so parse them to
// numbers here once instead of in every service function.
const NUMERIC_OID = 1700;
types.setTypeParser(NUMERIC_OID, (value: string) => parseFloat(value));

// DATE columns (work_orders.service_date) come back from pg as a JS Date
// by default, constructed from local server time — a real timezone-shift
// risk for a plain calendar date with no time component. Keep it as the
// raw "YYYY-MM-DD" string instead; nothing downstream (JSON response,
// SQL writes) needs it as a Date object.
const DATE_OID = 1082;
types.setTypeParser(DATE_OID, (value: string) => value);

export const pool = new Pool({
  connectionString: env.DATABASE_URL,
  max: 10,
  idleTimeoutMillis: 30000,
});

pool.on("error", (err) => {
  logger.error("Unexpected error on idle Postgres client", { error: err.message });
});

/**
 * Runs `fn` inside a BEGIN/COMMIT/ROLLBACK transaction on a dedicated
 * connection, and always releases the connection back to the pool.
 * Use this for anything that must run before a shop_id is known (e.g.
 * registration), or for one-off scripts. Request-scoped route handlers get
 * their transaction from tenantScope middleware instead (req.db).
 */
export async function withTransaction<T>(fn: (client: PoolClient) => Promise<T>): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
