import { z } from "zod";

export const createVehicleSchema = z.object({
  // Optional — a walk-in vehicle can be entered with only a plate, no
  // linked client. See DECISIONS.md's "Optional client link" entry.
  clientId: z.string().uuid().optional(),
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

// Make/model aren't a separate master-data entity with their own table —
// there's nothing to "quick-create" beyond the typed text itself, so these
// just suggest distinct values already used elsewhere in the shop's own
// vehicles (see DECISIONS.md's "Master-data search-autocomplete pattern").
export const searchMakesQuerySchema = z.object({
  q: z.string().trim().min(2).max(50),
});

export const searchModelsQuerySchema = z.object({
  q: z.string().trim().min(2).max(50),
  make: z.string().trim().max(50).optional(),
});

export type CreateVehicleInput = z.infer<typeof createVehicleSchema>;
export type UpdateVehicleInput = z.infer<typeof updateVehicleSchema>;
