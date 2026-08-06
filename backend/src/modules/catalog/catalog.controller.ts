import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { createCatalogItemSchema, updateCatalogItemSchema, listCatalogQuerySchema, searchCatalogQuerySchema } from "./catalog.schema";
import * as catalogService from "./catalog.service";

export const list = asyncHandler(async (req: Request, res: Response) => {
  const query = listCatalogQuerySchema.parse(req.query);
  const result = await catalogService.listCatalogItems(req.db!, query);
  res.status(200).json(result);
});

export const search = asyncHandler(async (req: Request, res: Response) => {
  const { q, type } = searchCatalogQuerySchema.parse(req.query);
  const items = await catalogService.searchCatalogItems(req.db!, q, type);
  res.status(200).json(items);
});

export const create = asyncHandler(async (req: Request, res: Response) => {
  const input = createCatalogItemSchema.parse(req.body);
  const item = await catalogService.createCatalogItem(req.db!, input);
  res.status(201).json(item);
});

export const update = asyncHandler(async (req: Request, res: Response) => {
  const input = updateCatalogItemSchema.parse(req.body);
  const item = await catalogService.updateCatalogItem(req.db!, req.params.id, input);
  res.status(200).json(item);
});

export const remove = asyncHandler(async (req: Request, res: Response) => {
  await catalogService.deleteCatalogItem(req.db!, req.params.id);
  res.status(204).send();
});
