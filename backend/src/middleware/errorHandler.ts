import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import multer from "multer";
import { AppError } from "../utils/errors";
import { logger } from "../utils/logger";

export function errorHandler(err: unknown, req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ZodError) {
    return res.status(400).json({
      error: "Validation failed",
      fields: err.flatten().fieldErrors,
    });
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(err.message, { path: req.path, details: err.details });
    }
    return res.status(err.statusCode).json({
      error: err.message,
      ...(err.details ? { details: err.details } : {}),
    });
  }

  if (err instanceof multer.MulterError) {
    return res.status(400).json({ error: err.message });
  }

  // Postgres unique_violation surfaced without being wrapped as a ConflictError
  if (typeof err === "object" && err !== null && (err as { code?: string }).code === "23505") {
    return res.status(409).json({ error: "A record with this value already exists" });
  }

  // Postgres foreign_key_violation — e.g. deleting a client that still has vehicles
  if (typeof err === "object" && err !== null && (err as { code?: string }).code === "23503") {
    return res.status(409).json({ error: "Cannot delete: this record is referenced by other data" });
  }

  const message = err instanceof Error ? err.message : "Unknown error";
  logger.error("Unhandled error", { path: req.path, message });

  return res.status(500).json({ error: "Internal server error" });
}
