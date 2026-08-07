import { PoolClient } from "pg";
import { ConflictError, NotFoundError, ValidationError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { Pagination } from "../../utils/pagination";
import {
  CreateWorkOrderInput,
  LineItemInput,
  RollbackWorkOrderInput,
  UpdateStatusInput,
  UpdateWorkOrderInput,
} from "./workOrders.schema";

export interface WorkOrderFilters {
  status?: string;
  clientId?: string;
  vehicleId?: string;
  dateFrom?: string;
  dateTo?: string;
}

type WorkOrderStatus = "draft" | "completed" | "paid";

// RLS on these tables is defense-in-depth only (see db/init/008_row_level_security.sql) —
// the connecting DB role owns these tables, and Postgres exempts table owners from RLS
// by default, so every query here must explicitly scope by shop_id itself.
const SHOP_SCOPE = "shop_id = current_setting('app.current_shop_id')::uuid";
const WO_SHOP_SCOPE = "wo.shop_id = current_setting('app.current_shop_id')::uuid";

// Forward-only status machine: draft -> completed -> paid.
// Skipping a step (e.g. draft -> paid) returns a 400 rather than silently
// allowing it, so payment is always recorded against a "completed" job.
const ALLOWED_TRANSITIONS: Record<WorkOrderStatus, WorkOrderStatus[]> = {
  draft: ["completed"],
  completed: ["paid"],
  paid: [],
};

// The one deliberate, audited exception to the forward-only rule above.
// Both roll back straight to draft (not to the intermediate step) — going
// through "completed" on the way down from "paid" doesn't match the
// real-world reason this exists ("we marked this wrong, put it back").
const ALLOWED_ROLLBACKS: Partial<Record<WorkOrderStatus, true>> = {
  completed: true,
  paid: true,
};

function computeTotals(items: LineItemInput[], discountAmount: number, taxRate: number) {
  const subtotal = Number(items.reduce((sum, i) => sum + i.quantity * i.unitPrice, 0).toFixed(2));
  const taxable = Math.max(0, subtotal - discountAmount);
  const taxAmount = Number((taxable * (taxRate / 100)).toFixed(2));
  const grandTotal = Number((taxable + taxAmount).toFixed(2));
  return { subtotal, taxAmount, grandTotal };
}

async function insertItems(db: PoolClient, workOrderId: string, items: LineItemInput[]) {
  for (const [index, item] of items.entries()) {
    await db.query(
      `INSERT INTO work_order_items (work_order_id, catalog_item_id, description, quantity, unit_price, sort_order)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [workOrderId, item.catalogItemId ?? null, item.description, item.quantity, item.unitPrice, index]
    );
  }
}

async function fetchItems(db: PoolClient, workOrderId: string) {
  const { rows } = await db.query(
    `SELECT * FROM work_order_items WHERE work_order_id = $1 ORDER BY sort_order ASC`,
    [workOrderId]
  );
  return toCamelList(rows);
}

export async function listWorkOrders(db: PoolClient, filters: WorkOrderFilters, pagination: Pagination) {
  const conditions: string[] = [WO_SHOP_SCOPE];
  const params: unknown[] = [];

  if (filters.status) {
    params.push(filters.status);
    conditions.push(`wo.status = $${params.length}`);
  }
  if (filters.clientId) {
    params.push(filters.clientId);
    conditions.push(`wo.client_id = $${params.length}`);
  }
  if (filters.vehicleId) {
    params.push(filters.vehicleId);
    conditions.push(`wo.vehicle_id = $${params.length}`);
  }
  if (filters.dateFrom) {
    params.push(filters.dateFrom);
    conditions.push(`wo.created_at >= $${params.length}`);
  }
  if (filters.dateTo) {
    params.push(filters.dateTo);
    conditions.push(`wo.created_at <= $${params.length}`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

  const { rows: countRows } = await db.query(`SELECT COUNT(*)::int AS total FROM work_orders wo ${where}`, params);
  const total = countRows[0]?.total ?? 0;

  params.push(pagination.pageSize, pagination.offset);
  const { rows } = await db.query(
    `SELECT wo.*, c.full_name AS client_name, v.license_plate AS vehicle_plate, v.make AS vehicle_make, v.model AS vehicle_model
     FROM work_orders wo
     JOIN clients c ON c.id = wo.client_id
     JOIN vehicles v ON v.id = wo.vehicle_id
     ${where}
     ORDER BY wo.created_at DESC
     LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );

  return { data: toCamelList(rows), total, page: pagination.page, pageSize: pagination.pageSize };
}

async function getHeaderById(db: PoolClient, id: string) {
  const { rows } = await db.query(`SELECT * FROM work_orders WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
  if (!rows[0]) throw new NotFoundError("Work order not found");
  return rows[0];
}

export async function getWorkOrderById(db: PoolClient, id: string) {
  // JOIN clients and vehicles so the response includes denormalized display
  // fields (clientName, vehiclePlate, vehicleMake, vehicleModel) — the same
  // fields the list endpoint returns. Without the JOIN the detail view only
  // receives raw UUIDs and displays them instead of human-readable values.
  const { rows } = await db.query(
    `SELECT wo.*,
            c.full_name        AS client_name,
            v.license_plate    AS vehicle_plate,
            v.make             AS vehicle_make,
            v.model            AS vehicle_model
     FROM   work_orders wo
     JOIN   clients  c ON c.id = wo.client_id
     JOIN   vehicles v ON v.id = wo.vehicle_id
     WHERE  wo.id = $1 AND ${WO_SHOP_SCOPE}`,
    [id]
  );
  if (!rows[0]) throw new NotFoundError("Work order not found");
  const items = await fetchItems(db, id);
  return { ...toCamel(rows[0]), items };
}

export async function createWorkOrder(db: PoolClient, input: CreateWorkOrderInput, createdBy: string) {
  // Verify the referenced client/vehicle actually belong to this shop before
  // creating a work order against them — otherwise a caller could pass another
  // shop's id and (a) attach their own work order to someone else's records, or
  // (b) via the mileage-sync UPDATE below, write into another shop's vehicle row.
  const { rows: ownedRows } = await db.query(
    `SELECT
       EXISTS(SELECT 1 FROM clients  WHERE id = $1 AND ${SHOP_SCOPE}) AS client_owned,
       EXISTS(SELECT 1 FROM vehicles WHERE id = $2 AND ${SHOP_SCOPE}) AS vehicle_owned`,
    [input.clientId, input.vehicleId]
  );
  if (!ownedRows[0].client_owned) throw new NotFoundError("Client not found");
  if (!ownedRows[0].vehicle_owned) throw new NotFoundError("Vehicle not found");

  // The two ownership checks above don't verify the pair belongs together —
  // a vehicle owned by a *different* client in the same shop would otherwise
  // slip through. This matters more now that the frontend's vehicle-search
  // Autocomplete can auto-fill the owner (see DECISIONS.md's master-data
  // search-autocomplete pattern): if that client/vehicle sync ever drifts
  // (stale state, a future client-only edit flow, a direct API call), this
  // is the backstop that keeps a work order's client and vehicle consistent.
  const { rows: pairRows } = await db.query(`SELECT client_id FROM vehicles WHERE id = $1`, [input.vehicleId]);
  if (pairRows[0].client_id !== input.clientId) {
    throw new ValidationError("Selected vehicle does not belong to the selected client");
  }

  const { subtotal, taxAmount, grandTotal } = computeTotals(input.items, input.discountAmount, input.taxRate);

  const {
    rows: [order],
  } = await db.query(
    `INSERT INTO work_orders
       (shop_id, client_id, vehicle_id, mileage_at_service, subtotal,
        discount_amount, tax_rate, tax_amount, grand_total, notes, created_by)
     VALUES (current_setting('app.current_shop_id')::uuid, $1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [
      input.clientId,
      input.vehicleId,
      input.mileageAtService ?? null,
      subtotal,
      input.discountAmount,
      input.taxRate,
      taxAmount,
      grandTotal,
      input.notes || null,
      createdBy,
    ]
  );

  await insertItems(db, order.id, input.items);

  // Keep the vehicle's odometer reading current — only ever moves forward.
  if (input.mileageAtService) {
    await db.query(
      `UPDATE vehicles SET current_mileage_km = $1 WHERE id = $2 AND current_mileage_km < $1 AND ${SHOP_SCOPE}`,
      [input.mileageAtService, input.vehicleId]
    );
  }

  return getWorkOrderById(db, order.id);
}

export async function updateWorkOrder(db: PoolClient, id: string, input: UpdateWorkOrderInput) {
  const header = await getHeaderById(db, id);

  if (input.items && header.status !== "draft") {
    throw new ConflictError("Line items can only be edited while the work order is in draft status");
  }

  let items: LineItemInput[];
  if (input.items) {
    items = input.items;
  } else {
    interface ExistingItemRow {
      catalogItemId?: string;
      description: string;
      quantity: number;
      unitPrice: number;
    }
    items = (await fetchItems(db, id)) as unknown as ExistingItemRow[];
  }

  const discountAmount = input.discountAmount ?? Number(header.discount_amount);
  const taxRate = input.taxRate ?? Number(header.tax_rate);
  const { subtotal, taxAmount, grandTotal } = computeTotals(items, discountAmount, taxRate);

  if (input.items) {
    await db.query(`DELETE FROM work_order_items WHERE work_order_id = $1`, [id]);
    await insertItems(db, id, input.items);
  }

  await db.query(
    `UPDATE work_orders
     SET mileage_at_service = COALESCE($1, mileage_at_service),
         subtotal = $2, discount_amount = $3, tax_rate = $4, tax_amount = $5, grand_total = $6,
         notes = COALESCE($7, notes)
     WHERE id = $8 AND ${SHOP_SCOPE}`,
    [input.mileageAtService ?? null, subtotal, discountAmount, taxRate, taxAmount, grandTotal, input.notes ?? null, id]
  );

  if (input.mileageAtService) {
    await db.query(
      `UPDATE vehicles SET current_mileage_km = $1 WHERE id = $2 AND current_mileage_km < $1 AND ${SHOP_SCOPE}`,
      [input.mileageAtService, header.vehicle_id]
    );
  }

  return getWorkOrderById(db, id);
}

export async function updateWorkOrderStatus(db: PoolClient, id: string, input: UpdateStatusInput) {
  const header = await getHeaderById(db, id);
  const current = header.status as WorkOrderStatus;

  if (current === input.status) {
    return getWorkOrderById(db, id);
  }

  if (!ALLOWED_TRANSITIONS[current].includes(input.status)) {
    throw new ValidationError(
      `Cannot change status from '${current}' to '${input.status}'. Allowed next step: ${
        ALLOWED_TRANSITIONS[current][0] ?? "none (already final)"
      }.`
    );
  }

  if (input.status === "paid" && !input.paymentMethod) {
    throw new ValidationError("paymentMethod is required when marking a work order as paid");
  }

  const timestampColumn = input.status === "completed" ? "completed_at" : input.status === "paid" ? "paid_at" : null;

  await db.query(
    `UPDATE work_orders
     SET status = $1,
         payment_method = COALESCE($2, payment_method)
         ${timestampColumn ? `, ${timestampColumn} = now()` : ""}
     WHERE id = $3 AND ${SHOP_SCOPE}`,
    [input.status, input.paymentMethod ?? null, id]
  );

  return getWorkOrderById(db, id);
}

export async function rollbackWorkOrderStatus(
  db: PoolClient,
  id: string,
  input: RollbackWorkOrderInput,
  actorUserId: string
) {
  const header = await getHeaderById(db, id);
  const current = header.status as WorkOrderStatus;

  if (!ALLOWED_ROLLBACKS[current]) {
    throw new ValidationError(
      `Cannot roll back a work order from '${current}'. Only 'completed' or 'paid' orders can be rolled back to draft.`
    );
  }

  // Looked up here rather than carried on the JWT — the JWT payload
  // (auth.service.ts's signToken) only ever held userId/shopId/role, and
  // widening it would leave already-issued tokens without the field until
  // they expire. This is a rare, owner/manager-only action, so one extra
  // lookup per rollback is a non-issue.
  const { rows: actorRows } = await db.query(`SELECT full_name FROM users WHERE id = $1`, [actorUserId]);
  const actorName = actorRows[0]?.full_name ?? "Unknown";

  await db.query(
    `UPDATE work_orders
     SET status = 'draft', payment_method = NULL, completed_at = NULL, paid_at = NULL
     WHERE id = $1 AND ${SHOP_SCOPE}`,
    [id]
  );

  await db.query(
    `INSERT INTO work_order_rollbacks
       (shop_id, work_order_id, order_no, from_status, to_status, reason,
        performed_by, performed_by_name,
        prior_payment_method, prior_completed_at, prior_paid_at, prior_grand_total)
     VALUES (current_setting('app.current_shop_id')::uuid, $1, $2, $3, 'draft', $4,
             $5, $6, $7, $8, $9, $10)`,
    [
      id,
      header.order_no,
      current,
      input.reason,
      actorUserId,
      actorName,
      header.payment_method,
      header.completed_at,
      header.paid_at,
      header.grand_total,
    ]
  );

  return getWorkOrderById(db, id);
}

export async function deleteWorkOrder(db: PoolClient, id: string) {
  const header = await getHeaderById(db, id);
  if (header.status !== "draft") {
    throw new ConflictError("Only draft work orders can be deleted");
  }
  await db.query(`DELETE FROM work_orders WHERE id = $1 AND ${SHOP_SCOPE}`, [id]);
}
