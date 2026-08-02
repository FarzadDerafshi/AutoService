import { Router } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import * as invitesController from "./invites.controller";

export const invitesRoutes = Router();

// Public — the invitee has no account (and no shop context) yet, so these
// must run before the authenticate/tenantScope gate below.
invitesRoutes.get("/:id/public", invitesController.publicInfo);
invitesRoutes.post("/:id/join", invitesController.join);

invitesRoutes.use(authenticate, tenantScope);

invitesRoutes.get("/", invitesController.list);
invitesRoutes.post("/", authorize("owner", "manager"), invitesController.create);
invitesRoutes.delete("/:id", authorize("owner", "manager"), invitesController.revoke);
