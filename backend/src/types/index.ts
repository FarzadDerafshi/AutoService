import { PoolClient } from "pg";

export type UserRole = "owner" | "manager" | "technician";

export interface AuthContext {
  userId: string;
  shopId: string;
  role: UserRole;
}

declare global {
  namespace Express {
    interface Request {
      auth?: AuthContext;
      db?: PoolClient;
    }
  }
}

export interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
}
