import bcrypt from "bcryptjs";
import { PoolClient } from "pg";
import { pool, withTransaction } from "../../config/db";
import { BCRYPT_ROUNDS, signToken } from "../auth/auth.service";
import { NotFoundError, ValidationError, ConflictError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { CreateInviteInput, JoinInviteInput } from "./invites.schema";

// RLS on this table is defense-in-depth only — the connecting DB role owns
// every table, so every query here must explicitly scope by shop_id itself
// (see db/init/008_row_level_security.sql and the note in DECISIONS.md).
const SHOP_SCOPE = "shop_id = current_setting('app.current_shop_id')::uuid";

export async function createInvite(db: PoolClient, createdByUserId: string, input: CreateInviteInput) {
  const expiresAt = new Date(Date.now() + input.expiresInHours * 60 * 60 * 1000);
  const { rows } = await db.query(
    `INSERT INTO shop_invites (shop_id, role, created_by, expires_at)
     VALUES (current_setting('app.current_shop_id')::uuid, $1, $2, $3)
     RETURNING *`,
    [input.role, createdByUserId, expiresAt]
  );
  return toCamel(rows[0]);
}

export async function listInvites(db: PoolClient) {
  const { rows } = await db.query(
    `SELECT * FROM shop_invites WHERE ${SHOP_SCOPE} ORDER BY created_at DESC`
  );
  return { data: toCamelList(rows) };
}

export async function revokeInvite(db: PoolClient, id: string) {
  const { rows } = await db.query(
    `UPDATE shop_invites SET revoked_at = now()
     WHERE id = $1 AND ${SHOP_SCOPE} AND used_at IS NULL AND revoked_at IS NULL
     RETURNING id`,
    [id]
  );
  if (!rows[0]) throw new NotFoundError("Invite not found, or already used/revoked");
}

function assertInviteUsable(invite: { used_at: Date | null; revoked_at: Date | null; expires_at: Date }) {
  if (invite.revoked_at) throw new ValidationError("This invite has been revoked");
  if (invite.used_at) throw new ValidationError("This invite has already been used");
  if (new Date(invite.expires_at) < new Date()) throw new ValidationError("This invite has expired");
}

export async function getInvitePublicInfo(id: string) {
  const { rows } = await pool.query(
    `SELECT si.role, si.expires_at, si.used_at, si.revoked_at, s.name AS shop_name
     FROM shop_invites si
     JOIN shops s ON s.id = si.shop_id
     WHERE si.id = $1`,
    [id]
  );
  const invite = rows[0];
  if (!invite) throw new NotFoundError("Invite not found");
  assertInviteUsable(invite);
  return { shopName: invite.shop_name as string, role: invite.role as string };
}

export async function joinInvite(id: string, input: JoinInviteInput) {
  return withTransaction(async (client) => {
    const { rows } = await client.query(
      `SELECT shop_id, role, expires_at, used_at, revoked_at FROM shop_invites WHERE id = $1 FOR UPDATE`,
      [id]
    );
    const invite = rows[0];
    if (!invite) throw new NotFoundError("Invite not found");
    assertInviteUsable(invite);

    const existing = await client.query(`SELECT id FROM users WHERE email = $1 AND shop_id = $2`, [
      input.email,
      invite.shop_id,
    ]);
    if (existing.rowCount) throw new ConflictError("An account with this email already exists");

    const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);
    const {
      rows: [user],
    } = await client.query(
      `INSERT INTO users (shop_id, full_name, email, password_hash, role)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, shop_id, full_name, email, role`,
      [invite.shop_id, input.fullName, input.email, passwordHash, invite.role]
    );

    await client.query(`UPDATE shop_invites SET used_at = now(), used_by = $1 WHERE id = $2`, [user.id, id]);

    const token = signToken({ userId: user.id, shopId: user.shop_id, role: user.role });

    return {
      token,
      user: {
        id: user.id,
        fullName: user.full_name,
        email: user.email,
        role: user.role,
        shopId: user.shop_id,
      },
    };
  });
}
