import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import * as searchController from "./search.controller";

export const searchRoutes = Router();

searchRoutes.get("/", authenticate, tenantScope, searchController.search);
