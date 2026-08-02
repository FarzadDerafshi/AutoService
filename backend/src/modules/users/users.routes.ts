import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import * as usersController from "./users.controller";

export const usersRoutes = Router();

usersRoutes.use(authenticate, tenantScope, authorize("owner", "manager"));

usersRoutes.get("/", usersController.list);
usersRoutes.patch("/:id", usersController.updateActive);
usersRoutes.delete("/:id", usersController.remove);
