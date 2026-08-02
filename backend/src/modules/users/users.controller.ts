import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { UnauthorizedError } from "../../utils/errors";
import { updateUserActiveSchema } from "./users.schema";
import * as usersService from "./users.service";

export const list = asyncHandler(async (req: Request, res: Response) => {
  const result = await usersService.listUsers(req.db!);
  res.status(200).json(result);
});

export const updateActive = asyncHandler(async (req: Request, res: Response) => {
  if (!req.auth) throw new UnauthorizedError();
  const input = updateUserActiveSchema.parse(req.body);
  const user = await usersService.setUserActive(req.db!, req.params.id, req.auth.userId, input);
  res.status(200).json(user);
});

export const remove = asyncHandler(async (req: Request, res: Response) => {
  if (!req.auth) throw new UnauthorizedError();
  await usersService.deleteUser(req.db!, req.params.id, req.auth.userId);
  res.status(204).send();
});
