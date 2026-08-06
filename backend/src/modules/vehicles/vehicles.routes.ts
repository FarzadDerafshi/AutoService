import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import * as vehiclesController from "./vehicles.controller";

export const vehiclesRoutes = Router();

vehiclesRoutes.use(authenticate, tenantScope);

vehiclesRoutes.get("/", vehiclesController.list);
// Must precede "/:id" — otherwise Express would match "search" as an :id param.
vehiclesRoutes.get("/search", vehiclesController.search);
vehiclesRoutes.get("/makes/search", vehiclesController.searchMakes);
vehiclesRoutes.get("/models/search", vehiclesController.searchModels);
vehiclesRoutes.get("/:id", vehiclesController.getById);
vehiclesRoutes.get("/:id/history", vehiclesController.history);
vehiclesRoutes.post("/", vehiclesController.create);
vehiclesRoutes.patch("/:id", vehiclesController.update);
vehiclesRoutes.delete("/:id", authorize("owner", "manager"), vehiclesController.remove);
