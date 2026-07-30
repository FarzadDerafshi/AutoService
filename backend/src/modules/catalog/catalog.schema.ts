import { z } from "zod";

export const catalogItemTypeSchema = z.enum(["service", "part"]);

export const createCatalogItemSchema = z.object({
  type: catalogItemTypeSchema,
  sku: z.string().trim().max(50).optional(),
  name: z.string().trim().min(1).max(150),
  unit: z.string().trim().max(20).optional(),
  defaultUnitPrice: z.coerce.number().min(0).default(0),
});

export const updateCatalogItemSchema = createCatalogItemSchema.partial().extend({
  isActive: z.boolean().optional(),
});

export const listCatalogQuerySchema = z.object({
  type: catalogItemTypeSchema.optional(),
  search: z.string().trim().max(150).optional(),
});

export type CreateCatalogItemInput = z.infer<typeof createCatalogItemSchema>;
export type UpdateCatalogItemInput = z.infer<typeof updateCatalogItemSchema>;
