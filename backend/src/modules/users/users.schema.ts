import { z } from "zod";

export const updateUserActiveSchema = z.object({
  isActive: z.boolean(),
});

export type UpdateUserActiveInput = z.infer<typeof updateUserActiveSchema>;
