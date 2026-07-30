import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { env } from "../config/env";
import { UnauthorizedError } from "../utils/errors";
import { AuthContext } from "../types";

export function authenticate(req: Request, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  // The PDF endpoint is opened as a plain browser navigation (new tab /
  // download), which can't attach an Authorization header, so it also
  // accepts the JWT as ?token=... . Every other route requires the header.
  const queryToken = typeof req.query.token === "string" ? req.query.token : undefined;

  const token = header?.startsWith("Bearer ") ? header.slice("Bearer ".length) : queryToken;

  if (!token) {
    return next(new UnauthorizedError("Missing or malformed Authorization header"));
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as AuthContext;
    req.auth = {
      userId: payload.userId,
      shopId: payload.shopId,
      role: payload.role,
    };
    next();
  } catch {
    next(new UnauthorizedError("Invalid or expired token"));
  }
}
