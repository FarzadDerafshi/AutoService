import { z } from "zod";

export const createClientSchema = z.object({
  fullName: z.string().trim().min(1).max(150),
  phone: z.string().trim().max(30).optional(),
  email: z.string().trim().email().max(150).optional().or(z.literal("")),
  address: z.string().trim().max(2000).optional(),
  taxId: z.string().trim().max(50).optional(),
  notes: z.string().trim().max(4000).optional(),
});

export const updateClientSchema = createClientSchema.partial();

export const listClientsQuerySchema = z.object({
  search: z.string().trim().max(150).optional(),
  page: z.coerce.number().int().positive().optional(),
  pageSize: z.coerce.number().int().positive().max(100).optional(),
});

export type CreateClientInput = z.infer<typeof createClientSchema>;
export type UpdateClientInput = z.infer<typeof updateClientSchema>;
