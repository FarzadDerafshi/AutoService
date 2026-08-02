import path from "path";

// Matches the volume Docker Compose already mounts (./backend/uploads:/app/uploads)
// and the directory the Dockerfile pre-creates for the `node` user.
export const UPLOADS_DIR = path.resolve(process.cwd(), "uploads");
export const SHOP_LOGOS_DIR = path.join(UPLOADS_DIR, "shop-logos");
