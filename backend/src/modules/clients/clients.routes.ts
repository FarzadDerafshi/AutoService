import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import * as clientsController from "./clients.controller";

export const clientsRoutes = Router();

clientsRoutes.use(authenticate, tenantScope);

clientsRoutes.get("/", clientsController.list);
// Must precede "/:id" — otherwise Express would match "search" as an :id param.
clientsRoutes.get("/search", clientsController.search);
clientsRoutes.get("/:id", clientsController.getById);
clientsRoutes.post("/", clientsController.create);
clientsRoutes.patch("/:id", clientsController.update);
clientsRoutes.delete("/:id", authorize("owner", "manager"), clientsController.remove);
