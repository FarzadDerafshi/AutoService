import { PoolClient } from "pg";
import { NotFoundError } from "../../utils/errors";
import { toCamel, toCamelList } from "../../utils/mapKeysToCamel";
import { normalizePlate } from "../../utils/licensePlate";

interface DateRange {
  dateFrom?: string;
  dateTo?: string;
}

function dateRangeClause(column: string, range: DateRange, params: unknown[]) {
  const conditions: string[] = [];
  if (range.dateFrom) {
    params.push(range.dateFrom);
    conditions.push(`${column} >= $${params.length}`);
  }
  if (range.dateTo) {
    params.push(range.dateTo);
    conditions.push(`${column} <= $${params.length}`);
  }
  return conditions;
}

// Revenue is recognized when a work order is marked paid, so this reports
// on paid_at (not created_at) within the requested range.
export async function getRevenueReport(db: PoolClient, range: DateRange, groupBy: "day" | "week" | "month") {
  const params: unknown[] = [];
  const conditions = ["status = 'paid'", "paid_at IS NOT NULL", ...dateRangeClause("paid_at", range, params)];

  const { rows } = await db.query(
    `SELECT date_trunc('${groupBy}', paid_at) AS period,
            SUM(grand_total)::numeric(12,2) AS revenue,
            COUNT(*)::int AS order_count
     FROM work_orders
     WHERE ${conditions.join(" AND ")}
     GROUP BY period
     ORDER BY period ASC`,
    params
  );

  return { data: toCamelList(rows) };
}

export async function getPaymentStatusReport(db: PoolClient, range: DateRange) {
  const params: unknown[] = [];
  const conditions = dateRangeClause("created_at", range, params);
  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";

  const { rows } = await db.query(
    `SELECT status, COUNT(*)::int AS count, COALESCE(SUM(grand_total), 0)::numeric(12,2) AS total
     FROM work_orders ${where}
     GROUP BY status`,
    params
  );

  const result = { draft: 0, completed: 0, paid: 0, totalOutstanding: 0 };
  for (const row of rows) {
    const status = row.status as "draft" | "completed" | "paid";
    result[status] = row.count;
    if (status !== "paid") {
      result.totalOutstanding += Number(row.total);
    }
  }
  result.totalOutstanding = Number(result.totalOutstanding.toFixed(2));
  return result;
}

export async function getPartsUsageReport(db: PoolClient, range: DateRange, catalogItemId?: string) {
  const params: unknown[] = [];
  const conditions = ["woi.catalog_item_id IS NOT NULL", ...dateRangeClause("wo.created_at", range, params)];

  if (catalogItemId) {
    params.push(catalogItemId);
    conditions.push(`woi.catalog_item_id = $${params.length}`);
  }

  const { rows } = await db.query(
    `SELECT ci.id AS catalog_item_id, ci.name,
            SUM(woi.quantity)::numeric(12,2) AS total_quantity,
            SUM(woi.line_total)::numeric(12,2) AS total_revenue
     FROM work_order_items woi
     JOIN work_orders wo ON wo.id = woi.work_order_id
     JOIN catalog_items ci ON ci.id = woi.catalog_item_id
     WHERE ${conditions.join(" AND ")}
     GROUP BY ci.id, ci.name
     ORDER BY total_revenue DESC`,
    params
  );

  return { data: toCamelList(rows) };
}

export async function getVehicleHistoryByPlate(db: PoolClient, plate: string) {
  const { rows } = await db.query(`SELECT * FROM vehicles WHERE license_plate = $1`, [normalizePlate(plate)]);
  const vehicle = rows[0];
  if (!vehicle) throw new NotFoundError("Vehicle not found for that license plate");

  const { rows: orders } = await db.query(
    `SELECT id, order_no, status, payment_method, subtotal, discount_amount, tax_rate,
            tax_amount, grand_total, mileage_at_service, created_at, completed_at, paid_at
     FROM work_orders WHERE vehicle_id = $1 ORDER BY created_at DESC`,
    [vehicle.id]
  );

  return { vehicle: toCamel(vehicle), workOrders: toCamelList(orders) };
}
