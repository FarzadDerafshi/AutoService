import { z } from "zod";

export const workOrderStatusSchema = z.enum(["draft", "completed", "paid"]);
export const paymentMethodSchema = z.enum(["cash", "card", "bank_transfer", "other"]);

export const lineItemSchema = z.object({
  catalogItemId: z.string().uuid().optional(),
  description: z.string().trim().min(1).max(255),
  quantity: z.coerce.number().positive(),
  unitPrice: z.coerce.number().min(0),
});

export const createWorkOrderSchema = z.object({
  clientId: z.string().uuid(),
  vehicleId: z.string().uuid(),
  mileageAtService: z.coerce.number().int().min(0).optional(),
  items: z.array(lineItemSchema).min(1, "At least one line item is required"),
  discountAmount: z.coerce.number().min(0).default(0),
  taxRate: z.coerce.number().min(0).max(100).default(0),
  notes: z.string().trim().max(4000).optional(),
});

export const updateWorkOrderSchema = z.object({
  mileageAtService: z.coerce.number().int().min(0).optional(),
  items: z.array(lineItemSchema).min(1).optional(),
  discountAmount: z.coerce.number().min(0).optional(),
  taxRate: z.coerce.number().min(0).max(100).optional(),
  notes: z.string().trim().max(4000).optional(),
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
