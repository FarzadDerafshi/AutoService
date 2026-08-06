import { Request, Response } from "express";
import { asyncHandler } from "../../utils/asyncHandler";
import { parsePagination } from "../../utils/pagination";
import { createClientSchema, updateClientSchema, listClientsQuerySchema, searchClientsQuerySchema } from "./clients.schema";
import * as clientsService from "./clients.service";

export const list = asyncHandler(async (req: Request, res: Response) => {
  const query = listClientsQuerySchema.parse(req.query);
  const result = await clientsService.listClients(req.db!, query.search, parsePagination(req));
  res.status(200).json(result);
});

export const search = asyncHandler(async (req: Request, res: Response) => {
  const { q } = searchClientsQuerySchema.parse(req.query);
  const clients = await clientsService.searchClients(req.db!, q);
  res.status(200).json(clients);
});

export const getById = asyncHandler(async (req: Request, res: Response) => {
  const client = await clientsService.getClientById(req.db!, req.params.id);
  res.status(200).json(client);
});

export const create = asyncHandler(async (req: Request, res: Response) => {
  const input = createClientSchema.parse(req.body);
  const client = await clientsService.createClient(req.db!, input);
  res.status(201).json(client);
});

export const update = asyncHandler(async (req: Request, res: Response) => {
  const input = updateClientSchema.parse(req.body);
  const client = await clientsService.updateClient(req.db!, req.params.id, input);
  res.status(200).json(client);
});

export const remove = asyncHandler(async (req: Request, res: Response) => {
  await clientsService.deleteClient(req.db!, req.params.id);
  res.status(204).send();
});
