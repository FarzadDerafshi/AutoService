import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { parsePagination } from "../../utils/pagination";
import {
  createWorkOrderSchema,
  updateWorkOrderSchema,
  updateStatusSchema,
  rollbackWorkOrderSchema,
  listWorkOrdersQuerySchema,
} from "./workOrders.schema";
import * as workOrdersService from "./workOrders.service";
import { renderWorkOrderPdf } from "./workOrders.pdf";
import { UnauthorizedError } from "../../utils/errors";

export const list = asyncHandler(async (req: Request, res: Response) => {
  const query = listWorkOrdersQuerySchema.parse(req.query);
  const result = await workOrdersService.listWorkOrders(
    req.db!,
    {
      status: query.status,
      clientId: query.clientId,
      vehicleId: query.vehicleId,
      dateFrom: query.dateFrom,
      dateTo: query.dateTo,
    },
    parsePagination(req)
  );
  res.status(200).json(result);
});

export const getById = asyncHandler(async (req: Request, res: Response) => {
  const order = await workOrdersService.getWorkOrderById(req.db!, req.params.id);
  res.status(200).json(order);
});

export const create = asyncHandler(async (req: Request, res: Response) => {
  if (!req.auth) throw new UnauthorizedError();
  const input = createWorkOrderSchema.parse(req.body);
  const order = await workOrdersService.createWorkOrder(req.db!, input, req.auth.userId);
  res.status(201).json(order);
});

export const update = asyncHandler(async (req: Request, res: Response) => {
  const input = updateWorkOrderSchema.parse(req.body);
  const order = await workOrdersService.updateWorkOrder(req.db!, req.params.id, input);
  res.status(200).json(order);
});

export const updateStatus = asyncHandler(async (req: Request, res: Response) => {
  const input = updateStatusSchema.parse(req.body);
  const order = await workOrdersService.updateWorkOrderStatus(req.db!, req.params.id, input);
  res.status(200).json(order);
});

export const rollback = asyncHandler(async (req: Request, res: Response) => {
  if (!req.auth) throw new UnauthorizedError();
  const input = rollbackWorkOrderSchema.parse(req.body);
  const order = await workOrdersService.rollbackWorkOrderStatus(req.db!, req.params.id, input, req.auth.userId);
  res.status(200).json(order);
});

export const remove = asyncHandler(async (req: Request, res: Response) => {
  await workOrdersService.deleteWorkOrder(req.db!, req.params.id);
  res.status(204).send();
});

export const pdf = asyncHandler(async (req: Request, res: Response) => {
  await renderWorkOrderPdf(req.db!, req.params.id, res);
});
