export function toCamel<T = Record<string, unknown>>(row: Record<string, unknown>): T {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(row)) {
    const camelKey = key.replace(/_([a-z0-9])/g, (_, c: string) => c.toUpperCase());
    out[camelKey] = value;
  }
  return out as T;
}

export function toCamelList<T = Record<string, unknown>>(rows: Record<string, unknown>[]): T[] {
  return rows.map((row) => toCamel<T>(row));
}
