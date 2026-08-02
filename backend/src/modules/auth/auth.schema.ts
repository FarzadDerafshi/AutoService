import { z } from "zod";

export const registerSchema = z.object({
  shopName: z.string().trim().min(1).max(150),
  fullName: z.string().trim().min(1).max(150),
  email: z.string().trim().toLowerCase().email().max(150),
  password: z.string().min(8, "Password must be at least 8 characters").max(200),
});

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  password: z.string().min(1),
});

export const updateMeSchema = z.object({
  fullName: z.string().trim().min(1).max(150),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1),
  newPassword: z.string().min(8, "Password must be at least 8 characters").max(200),
});

export type RegisterInput = z.infer<typeof registerSchema>;
export type LoginInput = z.infer<typeof loginSchema>;
export type UpdateMeInput = z.infer<typeof updateMeSchema>;
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>;
