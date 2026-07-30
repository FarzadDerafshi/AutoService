import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { parsePagination } from "../../utils/pagination";
import { createVehicleSchema, updateVehicleSchema, listVehiclesQuerySchema } from "./vehicles.schema";
import * as vehiclesService from "./vehicles.service";

export const list = asyncHandler(async (req: Request, res: Response) => {
  const query = listVehiclesQuerySchema.parse(req.query);
  const result = await vehiclesService.listVehicles(
    req.db!,
    { plate: query.plate, clientId: query.clientId },
    parsePagination(req)
  );
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req: Request, res: Response) => {
  const vehicle = await vehiclesService.getVehicleById(req.db!, req.params.id);
  res.status(200).json(vehicle);
});

export const history = asyncHandler(async (req: Request, res: Response) => {
  const result = await vehiclesService.getVehicleHistory(req.db!, req.params.id);
  res.status(200).json(result);
});

export const create = asyncHandler(async (req: Request, res: Response) => {
  const input = createVehicleSchema.parse(req.body);
  const vehicle = await vehiclesService.createVehicle(req.db!, input);
  res.status(201).json(vehicle);
});

export const update = asyncHandler(async (req: Request, res: Response) => {
  const input = updateVehicleSchema.parse(req.body);
  const vehicle = await vehiclesService.updateVehicle(req.db!, req.params.id, input);
  res.status(200).json(vehicle);
});

export const remove = asyncHandler(async (req: Request, res: Response) => {
  await vehiclesService.deleteVehicle(req.db!, req.params.id);
  res.status(204).send();
});
