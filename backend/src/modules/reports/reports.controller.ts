import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { revenueQuerySchema, dateRangeQuerySchema, partsUsageQuerySchema, vehicleHistoryQuerySchema } from "./reports.schema";
import * as reportsService from "./reports.service";

export const revenue = asyncHandler(async (req: Request, res: Response) => {
  const query = revenueQuerySchema.parse(req.query);
  const result = await reportsService.getRevenueReport(req.db!, query, query.groupBy);
  res.status(200).json(result);
});

export const paymentStatus = asyncHandler(async (req: Request, res: Response) => {
  const query = dateRangeQuerySchema.parse(req.query);
  const result = await reportsService.getPaymentStatusReport(req.db!, query);
  res.status(200).json(result);
});

export const partsUsage = asyncHandler(async (req: Request, res: Response) => {
  const query = partsUsageQuerySchema.parse(req.query);
  const result = await reportsService.getPartsUsageReport(req.db!, query, query.catalogItemId);
  res.status(200).json(result);
});

export const vehicleHistory = asyncHandler(async (req: Request, res: Response) => {
  const query = vehicleHistoryQuerySchema.parse(req.query);
  const result = await reportsService.getVehicleHistoryByPlate(req.db!, query.plate);
  res.status(200).json(result);
});
