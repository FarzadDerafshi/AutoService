import { z } from "zod";

export const createVehicleSchema = z.object({
  clientId: z.string().uuid(),
  licensePlate: z.string().trim().min(1).max(20),
  make: z.string().trim().max(50).optional(),
  model: z.string().trim().max(50).optional(),
  engineType: z.string().trim().max(50).optional(),
  year: z.coerce.number().int().min(1900).max(2100).optional(),
  currentMileageKm: z.coerce.number().int().min(0).optional(),
  chassisNo: z.string().trim().max(50).optional(),
  engineNo: z.string().trim().max(50).optional(),
  color: z.string().trim().max(30).optional(),
});

export const updateVehicleSchema = createVehicleSchema.partial();

export const listVehiclesQuerySchema = z.object({
  plate: z.string().trim().max(20).optional(),
  clientId: z.string().uuid().optional(),
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().max(100).optional(),
});

// Master-data Autocomplete pattern (DECISIONS.md) — searches plate/make/model
// shop-wide (or narrowed to one owner via clientId), unlike listVehicles'
// plate-only, paginated filter above.
export const searchVehiclesQuerySchema = z.object({
  q: z.string().trim().min(2).max(30),
  clientId: z.string().uuid().optional(),
});

export type CreateVehicleInput = z.infer<typeof createVehicleSchema>;
export type UpdateVehicleInput = z.infer<typeof updateVehicleSchema>;
