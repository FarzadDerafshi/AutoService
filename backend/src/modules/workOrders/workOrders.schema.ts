import { z } from "zod";

// Plain "YYYY-MM-DD" — validated as a string, never coerced into a JS Date.
// See config/db.ts's DATE type-parser override for why this column stays a
// string end-to-end rather than round-tripping through Date objects.
const dateOnlySchema = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Expected YYYY-MM-DD");

export const workOrderStatusSchema = z.enum(["draft", "completed", "paid"]);
export const paymentMethodSchema = z.enum(["cash", "card", "bank_transfer", "other"]);

export const lineItemSchema = z.object({
  catalogItemId: z.string().uuid().optional(),
  description: z.string().trim().min(1).max(255),
  quantity: z.coerce.number().positive(),
  unitPrice: z.coerce.number().min(0),
  unit: z.string().trim().max(20).optional(),
});

export const createWorkOrderSchema = z.object({
  // Optional — a walk-in job can be opened against a client-less vehicle
  // with no client at all. See DECISIONS.md's "Optional client link" entry.
  clientId: z.string().uuid().optional(),
  vehicleId: z.string().uuid(),
  mileageAtService: z.coerce.number().int().min(0).optional(),
  items: z.array(lineItemSchema).min(1, "At least one line item is required"),
  discountAmount: z.coerce.number().min(0).default(0),
  taxRate: z.coerce.number().min(0).max(100).default(0),
  notes: z.string().trim().max(4000).optional(),
  // Required, not defaulted here: "today" depends on the caller's local
  // timezone (this app is Turkey-only, UTC+3), and the server's own clock
  // — likely UTC inside the Docker container regardless of host timezone —
  // would silently misdate anything created between local midnight and 3am.
  // The frontend always sends its own device-local date; the DB column's
  // own DEFAULT CURRENT_DATE (see db/init/015_*.sql) is the fallback for
  // any direct-SQL/manual insert that bypasses the API entirely.
  serviceDate: dateOnlySchema,
});

export const updateWorkOrderSchema = z.object({
  mileageAtService: z.coerce.number().int().min(0).optional(),
  items: z.array(lineItemSchema).min(1).optional(),
  discountAmount: z.coerce.number().min(0).optional(),
  taxRate: z.coerce.number().min(0).max(100).optional(),
  notes: z.string().trim().max(4000).optional(),
  serviceDate: dateOnlySchema.optional(),
});

export const updateStatusSchema = z.object({
  status: workOrderStatusSchema,
  paymentMethod: paymentMethodSchema.optional(),
});

export const rollbackWorkOrderSchema = z.object({
  reason: z.string().trim().min(3).max(1000),
});

export const listWorkOrdersQuerySchema = z.object({
  status: workOrderStatusSchema.optional(),
  clientId: z.string().uuid().optional(),
  vehicleId: z.string().uuid().optional(),
  dateFrom: z.string().optional(),
  dateTo: z.string().optional(),
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().max(100).optional(),
});

export type LineItemInput = z.infer<typeof lineItemSchema>;
export type CreateWorkOrderInput = z.infer<typeof createWorkOrderSchema>;
export type UpdateWorkOrderInput = z.infer<typeof updateWorkOrderSchema>;
export type UpdateStatusInput = z.infer<typeof updateStatusSchema>;
export type RollbackWorkOrderInput = z.infer<typeof rollbackWorkOrderSchema>;
