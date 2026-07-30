import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import * as catalogController from "./catalog.controller";

export const catalogRoutes = Router();

catalogRoutes.use(authenticate, tenantScope);

catalogRoutes.get("/", catalogController.list);
catalogRoutes.post("/", authorize("owner", "manager"), catalogController.create);
catalogRoutes.patch("/:id", authorize("owner", "manager"), catalogController.update);
catalogRoutes.delete("/:id", authorize("owner", "manager"), catalogController.remove);
