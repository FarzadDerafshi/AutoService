import fs from "fs";
import { Router } from "express";
import multer, { FileFilterCallback } from "multer";
import { Request } from "express";
import { authenticate } from "../../middleware/authenticate";
import { tenantScope } from "../../middleware/tenantScope";
import { authorize } from "../../middleware/authorize";
import { ValidationError } from "../../utils/errors";
import { SHOP_LOGOS_DIR } from "../../config/uploads";
import * as shopController from "./shop.controller";

fs.mkdirSync(SHOP_LOGOS_DIR, { recursive: true });

const EXTENSION_BY_MIME: Record<string, string> = {
  "image/png": "png",
  "image/jpeg": "jpg",
  "image/webp": "webp",
};

const upload = multer({
  storage: multer.diskStorage({
    destination: SHOP_LOGOS_DIR,
    filename: (req: Request, file, cb) => {
      const ext = EXTENSION_BY_MIME[file.mimetype];
      cb(null, `${req.auth!.shopId}.${ext}`);
    },
  }),
  limits: { fileSize: 2 * 1024 * 1024 },
  fileFilter: (_req, file, cb: FileFilterCallback) => {
    if (!EXTENSION_BY_MIME[file.mimetype]) {
      return cb(new ValidationError("Logo must be a PNG, JPEG, or WebP image"));
    }
    cb(null, true);
  },
});

export const shopRoutes = Router();

shopRoutes.use(authenticate, tenantScope);

shopRoutes.get("/", shopController.getProfile);
shopRoutes.patch("/", authorize("owner", "manager"), shopController.updateProfile);
shopRoutes.post("/logo", authorize("owner", "manager"), upload.single("logo"), shopController.uploadLogo);
shopRoutes.delete("/logo", authorize("owner", "manager"), shopController.deleteLogo);
