import { NextFunction, Request, Response } from "express";
import { ForbiddenError, UnauthorizedError } from "../utils/errors";
import { UserRole } from "../types";

export function authorize(...roles: UserRole[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.auth) {
      return next(new UnauthorizedError());
    }
    if (!roles.includes(req.auth.role)) {
      return next(new ForbiddenError("You do not have permission to perform this action"));
    }
    next();
  };
}
