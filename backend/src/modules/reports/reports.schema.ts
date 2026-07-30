import { z } from "zod";

export const dateRangeQuerySchema = z.object({
  dateFrom: z.string().optional(),
  dateTo: z.string().optional(),
});

export const revenueQuerySchema = dateRangeQuerySchema.extend({
  groupBy: z.enum(["day", "week", "month"]).default("day"),
});

export const partsUsageQuerySchema = dateRangeQuerySchema.extend({
  catalogItemId: z.string().uuid().optional(),
});

export const vehicleHistoryQuerySchema = z.object({
  plate: z.string().trim().min(1).max(20),
});
