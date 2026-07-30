import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { registerSchema, loginSchema } from "./auth.schema";
import * as authService from "./auth.service";
import { UnauthorizedError } from "../../utils/errors";

export const register = asyncHandler(async (req: Request, res: Response) => {
  const input = registerSchema.parse(req.body);
  const result = await authService.registerShopAndOwner(input);
  res.status(201).json(result);
});

export const login = asyncHandler(async (req: Request, res: Response) => {
  const input = loginSchema.parse(req.body);
  const result = await authService.login(input);
  res.status(200).json(result);
});

export const logout = asyncHandler(async (_req: Request, res: Response) => {
  // Stateless JWT — nothing to invalidate server-side; client discards the token.
  res.status(204).send();
});

export const me = asyncHandler(async (req: Request, res: Response) => {
  if (!req.auth) throw new UnauthorizedError();
  const user = await authService.getCurrentUser(req.auth.userId, req.auth.shopId);
  res.status(200).json(user);
});
