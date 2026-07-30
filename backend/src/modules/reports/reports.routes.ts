import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import * as reportsController from "./reports.controller";

export const reportsRoutes = Router();

reportsRoutes.use(authenticate, tenantScope);

reportsRoutes.get("/revenue", reportsController.revenue);
reportsRoutes.get("/payment-status", reportsController.paymentStatus);
reportsRoutes.get("/parts-usage", reportsController.partsUsage);
reportsRoutes.get("/vehicle-history", reportsController.vehicleHistory);
