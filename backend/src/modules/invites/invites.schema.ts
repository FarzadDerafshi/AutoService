import { z } from "zod";

export const inviteRoleSchema = z.enum(["manager", "technician"]);

export const createInviteSchema = z.object({
  role: inviteRoleSchema,
  expiresInHours: z.coerce.number().int().positive().max(24 * 30),
});

export const joinInviteSchema = z.object({
  fullName: z.string().trim().min(1).max(150),
  email: z.string().trim().toLowerCase().email().max(150),
  password: z.string().min(8, "Password must be at least 8 characters").max(200),
});

export type CreateInviteInput = z.infer<typeof createInviteSchema>;
export type JoinInviteInput = z.infer<typeof joinInviteSchema>;
