import { Request } from "express";

export interface Pagination {
  page: number;
  pageSize: number;
  offset: number;
}

export function parsePagination(req: Request): Pagination {
  const page = Math.max(1, parseInt(String(req.query.page ?? "1"), 10) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(String(req.query.pageSize ?? "20"), 10) || 20));
  return { page, pageSize, offset: (page - 1) * pageSize };
}
