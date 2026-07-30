import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { searchQuerySchema } from "./search.schema";
import * as searchService from "./search.service";

export const search = asyncHandler(async (req: Request, res: Response) => {
  const { q } = searchQuerySchema.parse(req.query);
  const result = await searchService.searchAll(req.db!, q);
  res.status(200).json(result);
});
