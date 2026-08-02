import express from "express";
import cors from "cors";
import helmet from "helmet";
import rateLimit from "express-rate-limit";
import { env } from "./config/env";
import { UPLOADS_DIR } from "./config/uploads";
import { errorHandler } from "./middleware/errorHandler";
import { authRoutes } from "./modules/auth/auth.routes";
import { clientsRoutes } from "./modules/clients/clients.routes";
import { vehiclesRoutes } from "./modules/vehicles/vehicles.routes";
import { catalogRoutes } from "./modules/catalog/catalog.routes";
import { workOrdersRoutes } from "./modules/workOrders/workOrders.routes";
import { reportsRoutes } from "./modules/reports/reports.routes";
import { searchRoutes } from "./modules/search/search.routes";
import { shopRoutes } from "./modules/shop/shop.routes";
import { invitesRoutes } from "./modules/invites/invites.routes";
import { usersRoutes } from "./modules/users/users.routes";

export const app = express();

app.use(helmet());
app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }));
app.use(express.json({ limit: "2mb" }));

// Generous but present rate limit — this is a single small shop's traffic,
// not a public API, so the goal is just to blunt brute-force/scripted abuse.
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 600,
  standardHeaders: true,
  legacyHeaders: false,
});
app.use("/api/", apiLimiter);

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many auth attempts, please try again later." },
});
app.use("/api/v1/auth/login", authLimiter);
app.use("/api/v1/auth/register", authLimiter);
app.use("/api/v1/invites/:id/join", authLimiter);

app.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok" });
});

// Publicly readable (no auth) — same treatment as the app's own static
// branding assets. Shop logos aren't sensitive, and the printed PDF/browser
// need to load them without attaching a JWT.
app.use("/api/v1/uploads", express.static(UPLOADS_DIR));

app.use("/api/v1/auth", authRoutes);
app.use("/api/v1/clients", clientsRoutes);
app.use("/api/v1/vehicles", vehiclesRoutes);
app.use("/api/v1/catalog", catalogRoutes);
app.use("/api/v1/work-orders", workOrdersRoutes);
app.use("/api/v1/reports", reportsRoutes);
app.use("/api/v1/search", searchRoutes);
app.use("/api/v1/shop", shopRoutes);
app.use("/api/v1/invites", invitesRoutes);
app.use("/api/v1/users", usersRoutes);

app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

app.use(errorHandler);
