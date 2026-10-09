/** The 17 local government units of Metro Manila, as shown in the app. */
export const METRO_MANILA_CITIES = [
  "Caloocan",
  "Las Piñas",
  "Makati",
  "Malabon",
  "Mandaluyong",
  "Manila",
  "Marikina",
  "Muntinlupa",
  "Navotas",
  "Parañaque",
  "Pasay",
  "Pasig",
  "Pateros",
  "Quezon City",
  "San Juan",
  "Taguig",
  "Valenzuela",
] as const;

export const METRO_MANILA = "Metro Manila";

/** Comparison key: "City of Las Piñas", "Las Pinas City" and "las piñas" agree. */
export function cityKey(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/^city of\s+/, "")
    .replace(/\s+city$/, "")
    .replace(/\s+/g, " ")
    .trim();
}

const metroByKey = new Map(METRO_MANILA_CITIES.map((city) => [cityKey(city), city]));

/** One spelling per city, so a hotline and a hospital in the same city match. */
export function canonicalCity(name: string | null | undefined): string | null {
  if (name == null) return null;
  const trimmed = name.trim();
  if (trimmed.length === 0) return null;
  return metroByKey.get(cityKey(trimmed)) ?? trimmed;
}

export function isMetroManilaCity(name: string | null | undefined): boolean {
  return name != null && metroByKey.has(cityKey(name));
}
