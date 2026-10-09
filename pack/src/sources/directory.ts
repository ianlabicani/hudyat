import { METRO_MANILA, canonicalCity } from "../cities";
import { parsePhones } from "../phones";
import type { PackRecord } from "../types";

const SOURCE = "bettergovph/bettergov";

function website(raw: unknown): string | null {
  if (typeof raw !== "string" || raw.trim().length === 0) return null;
  const url = raw.trim();
  return /^https?:\/\//i.test(url) ? url : `https://${url}`;
}

function text(raw: unknown): string | null {
  return typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : null;
}

/**
 * National offices from `src/data/directory/*.json`. The files do not share
 * one shape: the name is `office_name`, `office` or `name`, and the phone is
 * `trunkline` or `trunklines`.
 */
export function convertAgencies(rows: any[], fallbackCategory: string): PackRecord[] {
  const records: PackRecord[] = [];
  for (const row of rows) {
    const name = text(row.office_name) ?? text(row.office) ?? text(row.name) ?? text(row.chamber);
    if (!name) continue;
    records.push({
      kind: "agency",
      name,
      category: text(row.office_type) ?? fallbackCategory,
      phones: parsePhones(row.trunklines ?? row.trunkline),
      address: text(row.address),
      url: website(row.website),
      source: SOURCE,
    });
  }
  return records;
}

interface Official {
  name?: string;
  contact?: string;
}

/**
 * Mayors and vice mayors from `src/data/directory/lgu/*.json`. The capital
 * region lists `cities` directly; every other region nests them under
 * `provinces`, as `cities` or `municipalities`.
 */
export function convertLgu(json: any): PackRecord[] {
  const records: PackRecord[] = [];
  const region = text(json.region);

  const addPlace = (place: any, province: string | null) => {
    const city = canonicalCity(text(place.city) ?? text(place.municipality));
    if (!city) return;
    const roles: [string, Official | undefined][] = [
      ["Mayor", place.mayor],
      ["Vice Mayor", place.vice_mayor],
    ];
    for (const [role, official] of roles) {
      const name = text(official?.name);
      if (!name) continue;
      records.push({
        kind: "official",
        name,
        category: role,
        region,
        province,
        city,
        phones: parsePhones(official?.contact),
        source: SOURCE,
      });
    }
  };

  for (const place of json.cities ?? []) addPlace(place, METRO_MANILA);
  for (const province of json.provinces ?? []) {
    const provinceName = text(province.province);
    for (const place of [...(province.cities ?? []), ...(province.municipalities ?? [])]) {
      addPlace(place, provinceName);
    }
  }
  return records;
}
