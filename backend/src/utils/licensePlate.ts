export function normalizePlate(plate: string): string {
  return plate.toUpperCase().replace(/\s+/g, "");
}
