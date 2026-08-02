import { PoolClient } from "pg";
import { ForbiddenError, NotFoundError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { UpdateUserActiveInput } from "./users.schema";

// RLS on this table is defense-in-depth only — the connecting DB role owns
// every table, so every query here must explicitly scope by shop_id itself
// (see db/init/008_row_level_security.sql and the note in DECISIONS.md).
const SHOP_SCOPE = "shop_id = current_setting('app.current_shop_id')::uuid";

export async function listUsers(db: PoolClient) {
  const { rows } = await db.query(
    `SELECT id, full_name, email, role, is_active, created_at
     FROM users WHERE ${SHOP_SCOPE} ORDER BY created_at ASC`
  );
  return { data: toCamelList(rows) };
}

/**
 * Loads the target user and enforces the two safety guards shared by every
 * mutation in this module: nobody can manage their own account through
 * this endpoint (self-service lives in the auth module), and an owner
 * account can never be deactivated/deleted here — there's no flow to
 * create a second owner, so this prevents a shop from locking itself out.
 */
async function getManageableUser(db: PoolClient, id: string, callerUserId: string) {
  if (id === callerUserId) {
    throw new ForbiddenError("You can't manage your own account here — use your profile page instead");
  }
  const { rows } = await db.query(`SELECT id, role FROM users WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
  const user = rows[0];
  if (!user) throw new NotFoundError("User not found");
  if (user.role === "owner") throw new ForbiddenError("Owner accounts can't be managed here");
  return user;
}

export async function setUserActive(
  db: PoolClient,
  id: string,
  callerUserId: string,
  input: UpdateUserActiveInput
) {
  await getManageableUser(db, id, callerUserId);
  const { rows } = await db.query(
    `UPDATE users SET is_active = $1 WHERE id = $2 AND ${SHOP_SCOPE}
     RETURNING id, full_name, email, role, is_active, created_at`,
    [input.isActive, id]
  );
  return toCamel(rows[0]);
}

export async function deleteUser(db: PoolClient, id: string, callerUserId: string) {
  await getManageableUser(db, id, callerUserId);
  await db.query(`DELETE FROM users WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
}
