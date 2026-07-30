import { NextFunction, Request, Response } from "express";
import { pool } from "../config/db";
import { UnauthorizedError } from "../utils/errors";

/**
 * Opens a DB transaction scoped to the authenticated user's shop and attaches
 * the scoped client to req.db. SET LOCAL app.current_shop_id makes every RLS
 * policy in db/init/008_row_level_security.sql apply automatically for the
 * lifetime of this request/transaction, so a missing `WHERE shop_id = $1` in
 * a query can't leak another shop's rows.
 *
 * Must run after `authenticate` (needs req.auth.shopId).
 */
export async function tenantScope(req: Request, res: Response, next: NextFunction) {
  if (!req.auth) {
    return next(new UnauthorizedError());
  }

  const client = await pool.connect();
  let finished = false;

  const finish = async () => {
    if (finished) return;
    finished = true;
    try {
      const ok = res.statusCode < 400;
      await client.query(ok ? "COMMIT" : "ROLLBACK");
    } catch {
      // connection may already be broken; nothing more we can do
    } finally {
      client.release();
    }
  };

  try {
    await client.query("BEGIN");
    await client.query("SET LOCAL app.current_shop_id = $1", [req.auth.shopId]);
    req.db = client;
    res.on("finish", finish);
    res.on("close", finish);
    next();
  } catch (err) {
    await client.query("ROLLBACK").catch(() => undefined);
    client.release();
    next(err);
  }
}
