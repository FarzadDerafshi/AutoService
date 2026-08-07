import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import * as workOrdersController from "./workOrders.controller";

export const workOrdersRoutes = Router();

workOrdersRoutes.use(authenticate, tenantScope);

workOrdersRoutes.get("/", workOrdersController.list);
workOrdersRoutes.get("/:id", workOrdersController.getById);
workOrdersRoutes.get("/:id/pdf", workOrdersController.pdf);
workOrdersRoutes.post("/", workOrdersController.create);
workOrdersRoutes.patch("/:id", workOrdersController.update);
workOrdersRoutes.patch("/:id/status", workOrdersController.updateStatus);
workOrdersRoutes.patch("/:id/rollback", authorize("owner", "manager"), workOrdersController.rollback);
workOrdersRoutes.delete("/:id", authorize("owner", "manager"), workOrdersController.remove);
