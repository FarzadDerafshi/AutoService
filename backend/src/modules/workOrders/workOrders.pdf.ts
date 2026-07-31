import PDFDocument from "pdfkit";
import { PoolClient } from "pg";
import { Response } from "express";
import { NotFoundError } from "../../utils/errors";

interface PdfWorkOrder {
  order_no: number;
  status: string;
  payment_method: string | null;
  mileage_at_service: number | null;
  subtotal: number;
  discount_amount: number;
  tax_rate: number;
  tax_amount: number;
  grand_total: number;
  notes: string | null;
  created_at: Date;
  shop_name: string;
  client_name: string;
  client_phone: string | null;
  license_plate: string;
  make: string | null;
  model: string | null;
}

interface PdfItem {
  description: string;
  quantity: number;
  unit_price: number;
  line_total: number;
}

function money(value: number) {
  return value.toFixed(2);
}

export async function renderWorkOrderPdf(db: PoolClient, workOrderId: string, res: Response) {
  const { rows } = await db.query<PdfWorkOrder>(
    `SELECT wo.order_no, wo.status, wo.payment_method, wo.mileage_at_service,
            wo.subtotal, wo.discount_amount, wo.tax_rate, wo.tax_amount, wo.grand_total,
            wo.notes, wo.created_at,
            s.name AS shop_name,
            c.full_name AS client_name, c.phone AS client_phone,
            v.license_plate, v.make, v.model
     FROM work_orders wo
     JOIN shops s ON s.id = wo.shop_id
     JOIN clients c ON c.id = wo.client_id
     JOIN vehicles v ON v.id = wo.vehicle_id
     WHERE wo.id = $1 AND wo.shop_id = current_setting('app.current_shop_id')::uuid`,
    [workOrderId]
  );

  const order = rows[0];
  if (!order) throw new NotFoundError("Work order not found");

  const { rows: items } = await db.query<PdfItem>(
    `SELECT description, quantity, unit_price, line_total
     FROM work_order_items WHERE work_order_id = $1 ORDER BY sort_order ASC`,
    [workOrderId]
  );

  res.setHeader("Content-Type", "application/pdf");
  res.setHeader("Content-Disposition", `inline; filename="work-order-${order.order_no}.pdf"`);

  const doc = new PDFDocument({ size: "A4", margin: 50 });
  doc.pipe(res);

  doc.fontSize(18).text(order.shop_name, { align: "left" });
  doc.fontSize(10).fillColor("#555").text("Work Order / Repair Slip", { align: "left" });
  doc.moveDown(1.5);

  doc.fillColor("#000").fontSize(14).text(`Work Order #${order.order_no}`);
  doc.fontSize(10).fillColor("#555").text(`Date: ${order.created_at.toDateString()}`);
  doc.text(`Status: ${order.status.toUpperCase()}${order.payment_method ? ` (${order.payment_method})` : ""}`);
  doc.moveDown();

  doc.fillColor("#000").fontSize(11).text("Client", { underline: true });
  doc.fontSize(10).text(order.client_name);
  if (order.client_phone) doc.text(order.client_phone);
  doc.moveDown(0.5);

  doc.fontSize(11).text("Vehicle", { underline: true });
  doc.fontSize(10).text(`Plate: ${order.license_plate}`);
  if (order.make || order.model) doc.text(`${order.make ?? ""} ${order.model ?? ""}`.trim());
  if (order.mileage_at_service != null) doc.text(`Mileage at service: ${order.mileage_at_service} km`);
  doc.moveDown();

  // Line items table
  const tableTop = doc.y;
  const colX = { desc: 50, qty: 320, price: 380, total: 460 };
  doc.fontSize(10).fillColor("#000");
  doc.text("Description", colX.desc, tableTop, { bold: true } as never);
  doc.text("Qty", colX.qty, tableTop);
  doc.text("Unit Price", colX.price, tableTop);
  doc.text("Total", colX.total, tableTop);
  doc.moveTo(50, tableTop + 15).lineTo(545, tableTop + 15).strokeColor("#ccc").stroke();

  let y = tableTop + 22;
  for (const item of items) {
    doc.fontSize(10).fillColor("#000");
    doc.text(item.description, colX.desc, y, { width: 260 });
    doc.text(String(item.quantity), colX.qty, y);
    doc.text(money(item.unit_price), colX.price, y);
    doc.text(money(item.line_total), colX.total, y);
    y += 20;
  }

  doc.moveTo(50, y + 5).lineTo(545, y + 5).strokeColor("#ccc").stroke();
  y += 15;

  const totalsX = 380;
  doc.text("Subtotal:", totalsX, y);
  doc.text(money(order.subtotal), colX.total, y);
  y += 16;
  if (Number(order.discount_amount) > 0) {
    doc.text("Discount:", totalsX, y);
    doc.text(`-${money(order.discount_amount)}`, colX.total, y);
    y += 16;
  }
  doc.text(`Tax (${order.tax_rate}%):`, totalsX, y);
  doc.text(money(order.tax_amount), colX.total, y);
  y += 16;
  doc.fontSize(12).text("Grand Total:", totalsX, y);
  doc.text(money(order.grand_total), colX.total, y);

  if (order.notes) {
    doc.moveDown(2);
    doc.fontSize(11).fillColor("#000").text("Notes", { underline: true });
    doc.fontSize(10).fillColor("#333").text(order.notes);
  }

  doc.end();
}
