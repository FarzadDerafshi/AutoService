import { PoolClient } from "pg";
import fs from "fs/promises";
import path from "path";
import { NotFoundError } from "../../utils/errors";
import { toCamel } from "../../utils/mapKeysToCamel";
import { SHOP_LOGOS_DIR } from "../../config/uploads";
import { UpdateShopInput } from "./shop.schema";

const SHOP_SCOPE = "id = current_setting('app.current_shop_id')::uuid";

interface ShopRow {
  id: string;
  name: string;
  taxId: string | null;
  taxOffice: string | null;
  address: string | null;
  phone: string | null;
  email: string | null;
  logoPath: string | null;
  createdAt: Date;
  updatedAt: Date;
}

function toProfile(row: ShopRow) {
  const { logoPath, ...rest } = row;
  return { ...rest, logoUrl: logoPath ? `/api/v1/uploads/shop-logos/${path.basename(logoPath)}` : null };
}

export async function getShopProfile(db: PoolClient) {
  const { rows } = await db.query(`SELECT * FROM shops WHERE ${SHOP_SCOPE}`);
  if (!rows[0]) throw new NotFoundError("Shop not found");
  return toProfile(toCamel<ShopRow>(rows[0]));
}

export async function updateShopProfile(db: PoolClient, input: UpdateShopInput) {
  const fields: string[] = [];
  const params: unknown[] = [];
  const push = (column: string, value: unknown) => {
    params.push(value);
    fields.push(`${column} = $${params.length}`);
  };

  if (input.name !== undefined) push("name", input.name);
  if (input.taxId !== undefined) push("tax_id", input.taxId || null);
  if (input.taxOffice !== undefined) push("tax_office", input.taxOffice || null);
  if (input.address !== undefined) push("address", input.address || null);
  if (input.phone !== undefined) push("phone", input.phone || null);
  if (input.email !== undefined) push("email", input.email || null);

  if (fields.length === 0) {
    return getShopProfile(db);
  }

  const { rows } = await db.query(
    `UPDATE shops SET ${fields.join(", ")} WHERE ${SHOP_SCOPE} RETURNING *`,
    params
  );
  if (!rows[0]) throw new NotFoundError("Shop not found");
  return toProfile(toCamel<ShopRow>(rows[0]));
}

/**
 * Persists the just-uploaded file (already written to disk by multer under
 * SHOP_LOGOS_DIR, named `${shopId}.<ext>`) as the shop's logo, and removes
 * any previous logo file with a different extension so switching PNG->JPEG
 * (etc.) doesn't leave an orphaned file behind.
 */
export async function setShopLogo(db: PoolClient, filename: string) {
  const { rows } = await db.query(`SELECT logo_path FROM shops WHERE ${SHOP_SCOPE}`);
  if (!rows[0]) throw new NotFoundError("Shop not found");
  const previous = rows[0].logo_path as string | null;

  const { rows: updated } = await db.query(
    `UPDATE shops SET logo_path = $1 WHERE ${SHOP_SCOPE} RETURNING *`,
    [filename]
  );

  if (previous && previous !== filename) {
    await fs.unlink(path.join(SHOP_LOGOS_DIR, path.basename(previous))).catch(() => undefined);
  }

  return toProfile(toCamel<ShopRow>(updated[0]));
}

export async function clearShopLogo(db: PoolClient) {
  const { rows } = await db.query(`SELECT logo_path FROM shops WHERE ${SHOP_SCOPE}`);
  if (!rows[0]) throw new NotFoundError("Shop not found");
  const previous = rows[0].logo_path as string | null;

  const { rows: updated } = await db.query(
    `UPDATE shops SET logo_path = NULL WHERE ${SHOP_SCOPE} RETURNING *`
  );

  if (previous) {
    await fs.unlink(path.join(SHOP_LOGOS_DIR, path.basename(previous))).catch(() => undefined);
  }

  return toProfile(toCamel<ShopRow>(updated[0]));
}
