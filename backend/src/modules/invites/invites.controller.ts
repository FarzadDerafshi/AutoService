import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { UnauthorizedError } from "../../utils/errors";
import { createInviteSchema, joinInviteSchema } from "./invites.schema";
import * as invitesService from "./invites.service";

export const create = asyncHandler(async (req: Request, res: Response) => {
  if (!req.auth) throw new UnauthorizedError();
  const input = createInviteSchema.parse(req.body);
  const invite = await invitesService.createInvite(req.db!, req.auth.userId, input);
  res.status(201).json(invite);
});

export const list = asyncHandler(async (req: Request, res: Response) => {
  const result = await invitesService.listInvites(req.db!);
  res.status(200).json(result);
});

export const revoke = asyncHandler(async (req: Request, res: Response) => {
  await invitesService.revokeInvite(req.db!, req.params.id);
  res.status(204).send();
});

export const publicInfo = asyncHandler(async (req: Request, res: Response) => {
  const info = await invitesService.getInvitePublicInfo(req.params.id);
  res.status(200).json(info);
});

export const join = asyncHandler(async (req: Request, res: Response) => {
  const input = joinInviteSchema.parse(req.body);
  const result = await invitesService.joinInvite(req.params.id, input);
  res.status(201).json(result);
});
