import fs from "fs";
import path from "path";
import PDFDocument from "pdfkit";
import { PoolClient } from "pg";
import { Response } from "express";
import { NotFoundError } from "../../utils/errors";
import { SHOP_LOGOS_DIR } from "../../config/uploads";
import { FONT_REGULAR, FONT_BOLD } from "../../config/fonts";
import { ORDER_TAX_AND_DISCOUNT_VISIBLE } from "../../config/featureFlags";

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
  service_date: string;
  shop_name: string;
  shop_address: string | null;
  shop_phone: string | null;
  shop_tax_id: string | null;
  shop_tax_office: string | null;
  shop_logo_path: string | null;
  client_name: string | null; // null for a walk-in job with no linked client
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

// service_date arrives as a plain "YYYY-MM-DD" string (see config/db.ts's
// DATE type-parser override) — reformatted by string manipulation, not a
// Date object, so there's no timezone conversion to get wrong here.
function formatDMY(isoDate: string) {
  const [y, m, d] = isoDate.split("-");
  return `${d}.${m}.${y}`;
}

// Display only — the stored plate (vehicles.license_plate) stays
// space-free everywhere else (storage, search, uniqueness). Matches the
// general digits-letters-digits shape of a Turkish plate rather than
// validating the exact official letter/digit-count combinations, so a
// foreign or otherwise non-matching plate prints completely unchanged
// instead of being force-fitted into a Turkish pattern. Kept in sync with
// frontend/lib/core/utils/plate_formatter.dart's identical logic.
const TR_PLATE_PATTERN = /^(\d{2})([A-Z]{1,3})(\d{2,4})$/;
function formatPlateDisplay(plate: string) {
  const match = TR_PLATE_PATTERN.exec(plate.toUpperCase());
  if (!match) return plate;
  return `${match[1]} ${match[2]} ${match[3]}`;
}

// ---------------------------------------------------------------------------
// GarajOS work-order print design: a classy, modern, professional slip.
// Palette stays print-safe (white page, near-black ink) with the brand green
// used sparingly as an accent (letterhead rule, grand total, paid status).
// ---------------------------------------------------------------------------

const PAGE_WIDTH = 595.28; // A4 pt
const MARGIN = 50;
const LEFT = MARGIN;
const RIGHT = PAGE_WIDTH - MARGIN; // 545.28
const CONTENT_W = RIGHT - LEFT;

// "Helvetica"/"Helvetica-Bold" are PDF standard-14 fonts encoded as
// WinAnsi, which is missing Turkish letters (ı, İ, ğ, Ğ, ş, Ş) — they'd
// silently render as garbage. FONT_REGULAR/FONT_BOLD (DejaVu Sans) are
// registered below under these names and used everywhere a standard-14
// font name would otherwise appear. See DECISIONS.md.
const FONT = "PdfSans";
const FONT_BOLD_NAME = "PdfSans-Bold";

const COLORS = {
  ink: "#0F172A", // slate-900, primary text
  sub: "#64748B", // slate-500, secondary text
  faint: "#94A3B8", // slate-400, tertiary/labels
  hairline: "#E2E8F0", // slate-200, rules
  panel: "#F8FAFC", // slate-50, card fills
  panelAlt: "#F1F5F9", // slate-100, alt row fill
  brand: "#16A34A", // green-600, brand accent (print-safe "spark green")
  brandTint: "#DCFCE7", // green-100
  brandDark: "#15803D", // green-700
  headerBand: "#0F172A", // table header background
};

const STATUS_STYLE: Record<string, { bg: string; fg: string; label: string }> = {
  draft: { bg: "#F1F5F9", fg: "#475569", label: "DRAFT" },
  completed: { bg: "#FEF3C7", fg: "#B45309", label: "COMPLETED" },
  paid: { bg: COLORS.brandTint, fg: COLORS.brandDark, label: "PAID" },
};

function statusStyleFor(status: string) {
  return STATUS_STYLE[status] ?? { bg: "#F1F5F9", fg: "#475569", label: status.toUpperCase() };
}

/** Right-aligned rounded pill; returns the pill width. */
function drawPillRightAligned(doc: PDFKit.PDFDocument, rightX: number, y: number, text: string, bg: string, fg: string) {
  doc.font(FONT_BOLD_NAME).fontSize(8.5);
  const w = doc.widthOfString(text) + 20;
  const h = 17;
  doc.roundedRect(rightX - w, y, w, h, 8.5).fill(bg);
  doc.fillColor(fg).text(text, rightX - w, y + 4.5, { width: w, align: "center", characterSpacing: 0.3 });
  return w;
}

function drawLabelValue(doc: PDFKit.PDFDocument, x: number, y: number, width: number, label: string, value: string) {
  doc.font(FONT).fontSize(8).fillColor(COLORS.faint).text(label.toUpperCase(), x, y, { width, characterSpacing: 0.4 });
  doc.font(FONT_BOLD_NAME).fontSize(10.5).fillColor(COLORS.ink).text(value, x, doc.y + 1, { width });
  return doc.y;
}

export async function renderWorkOrderPdf(db: PoolClient, workOrderId: string, res: Response) {
  const { rows } = await db.query<PdfWorkOrder>(
    `SELECT wo.order_no, wo.status, wo.payment_method, wo.mileage_at_service,
            wo.subtotal, wo.discount_amount, wo.tax_rate, wo.tax_amount, wo.grand_total,
            wo.notes, wo.service_date,
            s.name AS shop_name, s.address AS shop_address, s.phone AS shop_phone,
            s.tax_id AS shop_tax_id, s.tax_office AS shop_tax_office, s.logo_path AS shop_logo_path,
            c.full_name AS client_name, c.phone AS client_phone,
            v.license_plate, v.make, v.model
     FROM work_orders wo
     JOIN shops s ON s.id = wo.shop_id
     LEFT JOIN clients c ON c.id = wo.client_id
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

  const doc = new PDFDocument({ size: "A4", margin: 0 });
  doc.registerFont(FONT, FONT_REGULAR);
  doc.registerFont(FONT_BOLD_NAME, FONT_BOLD);
  doc.pipe(res);

  // ---------------------------------------------------------------------
  // Letterhead: logo + shop identity (left), order number + status (right)
  // ---------------------------------------------------------------------
  const headerTop = 46;
  const LOGO_SIZE = 46;
  let textX = LEFT;

  if (order.shop_logo_path) {
    const logoAbsPath = path.join(SHOP_LOGOS_DIR, path.basename(order.shop_logo_path));
    if (fs.existsSync(logoAbsPath)) {
      doc.image(logoAbsPath, LEFT, headerTop, { fit: [LOGO_SIZE, LOGO_SIZE] });
      textX = LEFT + LOGO_SIZE + 14;
    }
  }

  const identityWidth = 300;
  doc.font(FONT_BOLD_NAME).fontSize(17).fillColor(COLORS.ink).text(order.shop_name, textX, headerTop, { width: identityWidth });

  const contactLine = [order.shop_address, order.shop_phone].filter(Boolean).join("   •   ");
  if (contactLine) {
    doc.font(FONT).fontSize(8.5).fillColor(COLORS.sub).text(contactLine, textX, doc.y + 3, { width: identityWidth });
  }

  const taxLine = [
    order.shop_tax_office ? `Vergi Dairesi: ${order.shop_tax_office}` : null,
    order.shop_tax_id ? `Vergi No: ${order.shop_tax_id}` : null,
  ]
    .filter(Boolean)
    .join("   •   ");
  if (taxLine) {
    doc.font(FONT).fontSize(8.5).fillColor(COLORS.sub).text(taxLine, textX, doc.y + 2, { width: identityWidth });
  }

  const rightColWidth = 190;
  const rightColX = RIGHT - rightColWidth;
  doc.font(FONT).fontSize(8.5).fillColor(COLORS.faint).text("WORK ORDER", rightColX, headerTop, { width: rightColWidth, align: "right", characterSpacing: 0.6 });
  doc.font(FONT_BOLD_NAME).fontSize(27).fillColor(COLORS.ink).text(`#${order.order_no}`, rightColX, headerTop + 11, { width: rightColWidth, align: "right" });
  doc.font(FONT).fontSize(9).fillColor(COLORS.sub).text(formatDMY(order.service_date), rightColX, headerTop + 45, { width: rightColWidth, align: "right" });

  const statusInfo = statusStyleFor(order.status);
  const statusText = order.payment_method ? `${statusInfo.label} · ${order.payment_method.toUpperCase()}` : statusInfo.label;
  drawPillRightAligned(doc, RIGHT, headerTop + 60, statusText, statusInfo.bg, statusInfo.fg);

  // Accent rule under the letterhead
  const headerBottom = Math.max(doc.y, headerTop + LOGO_SIZE, headerTop + 82) + 14;
  doc.rect(LEFT, headerBottom, CONTENT_W, 2.5).fill(COLORS.brand);

  // ---------------------------------------------------------------------
  // Client / Vehicle info cards
  // ---------------------------------------------------------------------
  let y = headerBottom + 24;
  const gap = 16;
  const cardW = (CONTENT_W - gap) / 2;
  const cardPad = 16;
  const cardH = 74;

  doc.roundedRect(LEFT, y, cardW, cardH, 6).fillColor(COLORS.panel).fill();
  doc.roundedRect(LEFT + cardW + gap, y, cardW, cardH, 6).fillColor(COLORS.panel).fill();

  let cy = drawLabelValue(doc, LEFT + cardPad, y + cardPad, cardW - cardPad * 2, "Client", order.client_name ?? "Walk-in Customer");
  if (order.client_phone) {
    doc.font(FONT).fontSize(9.5).fillColor(COLORS.sub).text(order.client_phone, LEFT + cardPad, cy + 3);
  }

  const vehicleTitle = `${order.make ?? ""} ${order.model ?? ""}`.trim() || "Vehicle";
  cy = drawLabelValue(doc, LEFT + cardW + gap + cardPad, y + cardPad, cardW - cardPad * 2, "Vehicle", `${formatPlateDisplay(order.license_plate)}  —  ${vehicleTitle}`);
  if (order.mileage_at_service != null) {
    doc.font(FONT).fontSize(9.5).fillColor(COLORS.sub).text(`${order.mileage_at_service.toLocaleString()} km at service`, LEFT + cardW + gap + cardPad, cy + 3);
  }

  y += cardH + 30;

  // ---------------------------------------------------------------------
  // Line items table
  // ---------------------------------------------------------------------
  const col = { desc: LEFT, qty: LEFT + 265, price: LEFT + 335, total: LEFT + 430 };
  const colW = { desc: 255, qty: 60, price: 85, total: RIGHT - col.total };

  const headerRowH = 24;
  doc.rect(LEFT, y, CONTENT_W, headerRowH).fill(COLORS.headerBand);
  doc.font(FONT_BOLD_NAME).fontSize(8.5).fillColor("#FFFFFF");
  doc.text("DESCRIPTION", col.desc + 4, y + 8, { width: colW.desc - 4, characterSpacing: 0.4 });
  doc.text("QTY", col.qty, y + 8, { width: colW.qty, align: "right", characterSpacing: 0.4 });
  doc.text("UNIT PRICE", col.price, y + 8, { width: colW.price, align: "right", characterSpacing: 0.4 });
  doc.text("TOTAL", col.total, y + 8, { width: colW.total - 4, align: "right", characterSpacing: 0.4 });
  y += headerRowH;

  items.forEach((item, i) => {
    doc.font(FONT).fontSize(9.5);
    const descHeight = doc.heightOfString(item.description, { width: colW.desc - 8 });
    const rowH = Math.max(26, descHeight + 14);

    if (i % 2 === 1) {
      doc.rect(LEFT, y, CONTENT_W, rowH).fill(COLORS.panelAlt);
    }

    const textY = y + (rowH - 10) / 2 - 2;
    doc.fillColor(COLORS.ink).font(FONT).fontSize(9.5).text(item.description, col.desc + 4, y + 7, { width: colW.desc - 8 });
    doc.text(String(item.quantity), col.qty, textY, { width: colW.qty, align: "right" });
    doc.text(money(item.unit_price), col.price, textY, { width: colW.price, align: "right" });
    doc.font(FONT_BOLD_NAME).text(money(item.line_total), col.total, textY, { width: colW.total - 4, align: "right" });

    y += rowH;
  });

  doc.moveTo(LEFT, y).lineTo(RIGHT, y).strokeColor(COLORS.hairline).lineWidth(1).stroke();
  y += 18;

  // ---------------------------------------------------------------------
  // Totals
  // ---------------------------------------------------------------------
  const totalsLabelX = RIGHT - 230;
  const totalsLabelW = 130;
  const totalsValueX = RIGHT - 100;
  const totalsValueW = 100;

  function totalsRow(label: string, value: string, opts?: { bold?: boolean; color?: string }) {
    doc
      .font(opts?.bold ? FONT_BOLD_NAME : FONT)
      .fontSize(opts?.bold ? 10.5 : 9.5)
      .fillColor(opts?.color ?? COLORS.sub)
      .text(label, totalsLabelX, y, { width: totalsLabelW, align: "right" });
    doc
      .font(opts?.bold ? FONT_BOLD_NAME : FONT)
      .fontSize(opts?.bold ? 10.5 : 9.5)
      .fillColor(opts?.color ?? COLORS.ink)
      .text(value, totalsValueX, y, { width: totalsValueW, align: "right" });
    y += opts?.bold ? 20 : 17;
  }

  totalsRow("Subtotal", money(order.subtotal));
  if (ORDER_TAX_AND_DISCOUNT_VISIBLE) {
    if (Number(order.discount_amount) > 0) {
      totalsRow("Discount", `−${money(order.discount_amount)}`);
    }
    totalsRow(`Tax (${order.tax_rate}%)`, money(order.tax_amount));
  }

  y += 4;
  const grandBoxW = 230;
  const grandBoxX = RIGHT - grandBoxW;
  doc.roundedRect(grandBoxX, y, grandBoxW, 34, 6).fill(COLORS.brandTint);
  doc.font(FONT_BOLD_NAME).fontSize(11).fillColor(COLORS.brandDark).text("GRAND TOTAL", grandBoxX + 16, y + 11, { width: 110 });
  doc.font(FONT_BOLD_NAME).fontSize(15).fillColor(COLORS.brandDark).text(money(order.grand_total), grandBoxX, y + 8, { width: grandBoxW - 16, align: "right" });
  y += 34 + 28;

  // ---------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------
  if (order.notes) {
    const noteWidth = CONTENT_W - 16;
    doc.font(FONT).fontSize(9.5);
    const noteHeight = doc.heightOfString(order.notes, { width: noteWidth - 16 });
    const boxH = noteHeight + 34;

    doc.roundedRect(LEFT, y, CONTENT_W, boxH, 6).fillColor(COLORS.panel).fill();
    doc.rect(LEFT, y, 3, boxH).fill(COLORS.brand);
    doc.font(FONT_BOLD_NAME).fontSize(8).fillColor(COLORS.faint).text("NOTES", LEFT + 16, y + 12, { characterSpacing: 0.5 });
    doc.font(FONT).fontSize(9.5).fillColor(COLORS.ink).text(order.notes, LEFT + 16, y + 24, { width: noteWidth - 16 });
    y += boxH;
  }

  // ---------------------------------------------------------------------
  // Footer
  // ---------------------------------------------------------------------
  const footerY = 792; // A4 height 841.89 minus ~50pt margin
  doc.moveTo(LEFT, footerY).lineTo(RIGHT, footerY).strokeColor(COLORS.hairline).lineWidth(1).stroke();
  doc.font(FONT).fontSize(8).fillColor(COLORS.faint).text(`Thank you for choosing ${order.shop_name}.`, LEFT, footerY + 8, { width: CONTENT_W - 140 });
  doc.text("Generated by GarajOS", LEFT, footerY + 8, { width: CONTENT_W, align: "right" });

  doc.end();
}
