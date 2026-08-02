import { z } from "zod";

export const updateShopSchema = z.object({
  name: z.string().trim().min(1).max(150).optional(),
  taxId: z.string().trim().max(50).optional(),
  taxOffice: z.string().trim().max(150).optional(),
  address: z.string().trim().max(2000).optional(),
  phone: z.string().trim().max(30).optional(),
  email: z.string().trim().email().max(150).optional().or(z.literal("")),
});

export type UpdateShopInput = z.infer<typeof updateShopSchema>;
