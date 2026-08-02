import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { ValidationError } from "../../utils/errors";
import { updateShopSchema } from "./shop.schema";
import * as shopService from "./shop.service";

export const getProfile = asyncHandler(async (req: Request, res: Response) => {
  const profile = await shopService.getShopProfile(req.db!);
  res.status(200).json(profile);
});

export const updateProfile = asyncHandler(async (req: Request, res: Response) => {
  const input = updateShopSchema.parse(req.body);
  const profile = await shopService.updateShopProfile(req.db!, input);
  res.status(200).json(profile);
});

export const uploadLogo = asyncHandler(async (req: Request, res: Response) => {
  if (!req.file) throw new ValidationError("No logo file was uploaded");
  const profile = await shopService.setShopLogo(req.db!, req.file.filename);
  res.status(200).json(profile);
});

export const deleteLogo = asyncHandler(async (req: Request, res: Response) => {
  const profile = await shopService.clearShopLogo(req.db!);
  res.status(200).json(profile);
});
