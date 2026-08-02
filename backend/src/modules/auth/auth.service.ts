import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { PoolClient } from "pg";
import { pool, withTransaction } from "../../config/db";
import { env } from "../../config/env";
import { ConflictError, UnauthorizedError } from "../../utils/errors";
import { UserRole } from "../../types";
import { RegisterInput, LoginInput, UpdateMeInput, ChangePasswordInput } from "./auth.schema";

export const BCRYPT_ROUNDS = 12;

export function signToken(payload: { userId: string; shopId: string; role: UserRole }) {
  return jwt.sign(payload, env.JWT_SECRET, { expiresIn: env.JWT_EXPIRES_IN } as jwt.SignOptions);
}

export async function registerShopAndOwner(input: RegisterInput) {
  return withTransaction(async (client: PoolClient) => {
    const existing = await client.query("SELECT id FROM users WHERE email = $1", [input.email]);
    if (existing.rowCount) {
      throw new ConflictError("An account with this email already exists");
    }

    const {
      rows: [shop],
    } = await client.query(`INSERT INTO shops (name) VALUES ($1) RETURNING id, name, tax_id, created_at`, [
      input.shopName,
    ]);

    const passwordHash = await bcrypt.hash(input.password, BCRYPT_ROUNDS);

    const {
      rows: [user],
    } = await client.query(
      `INSERT INTO users (shop_id, full_name, email, password_hash, role)
       VALUES ($1, $2, $3, $4, 'owner')
       RETURNING id, shop_id, full_name, email, role, is_active, created_at`,
      [shop.id, input.fullName, input.email, passwordHash]
    );

    const token = signToken({ userId: user.id, shopId: user.shop_id, role: user.role });

    return {
      shop: { id: shop.id, name: shop.name, taxId: shop.tax_id, createdAt: shop.created_at },
      user: {
        id: user.id,
        shopId: user.shop_id,
        fullName: user.full_name,
        email: user.email,
        role: user.role,
      },
      token,
    };
  });
}

export async function login(input: LoginInput) {
  // Users' emails are only unique per-shop (see UNIQUE (shop_id, email) in
  // 001_shops_and_users.sql). This login form takes email+password with no
  // shop identifier, which matches the doc's scale target of a single (or a
  // handful of) self-hosted shop per deployment. If the same email exists in
  // more than one shop on one deployment, this picks the first active match.
  const { rows } = await pool.query(
    `SELECT id, shop_id, full_name, email, password_hash, role, is_active
     FROM users WHERE email = $1 AND is_active = true LIMIT 1`,
    [input.email]
  );

  const user = rows[0];
  if (!user) {
    throw new UnauthorizedError("Invalid email or password");
  }

  const valid = await bcrypt.compare(input.password, user.password_hash);
  if (!valid) {
    throw new UnauthorizedError("Invalid email or password");
  }

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
}

export async function getCurrentUser(userId: string, shopId: string) {
  const { rows } = await pool.query(
    `SELECT id, full_name, email, role, shop_id FROM users WHERE id = $1 AND shop_id = $2`,
    [userId, shopId]
  );
  const user = rows[0];
  if (!user) {
    throw new UnauthorizedError("User no longer exists");
  }
  return {
    id: user.id,
    fullName: user.full_name,
    email: user.email,
    role: user.role,
    shopId: user.shop_id,
  };
}

export async function updateCurrentUser(userId: string, shopId: string, input: UpdateMeInput) {
  const { rows } = await pool.query(
    `UPDATE users SET full_name = $1 WHERE id = $2 AND shop_id = $3
     RETURNING id, full_name, email, role, shop_id`,
    [input.fullName, userId, shopId]
  );
  const user = rows[0];
  if (!user) {
    throw new UnauthorizedError("User no longer exists");
  }
  return {
    id: user.id,
    fullName: user.full_name,
    email: user.email,
    role: user.role,
    shopId: user.shop_id,
  };
}

export async function changePassword(userId: string, shopId: string, input: ChangePasswordInput) {
  const { rows } = await pool.query(`SELECT password_hash FROM users WHERE id = $1 AND shop_id = $2`, [
    userId,
    shopId,
  ]);
  const user = rows[0];
  if (!user) {
    throw new UnauthorizedError("User no longer exists");
  }

  const valid = await bcrypt.compare(input.currentPassword, user.password_hash);
  if (!valid) {
    throw new UnauthorizedError("Current password is incorrect");
  }

  const passwordHash = await bcrypt.hash(input.newPassword, BCRYPT_ROUNDS);
  await pool.query(`UPDATE users SET password_hash = $1 WHERE id = $2 AND shop_id = $3`, [
    passwordHash,
    userId,
    shopId,
  ]);
}
