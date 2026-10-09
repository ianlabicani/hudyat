import { METRO_MANILA, canonicalCity } from "../cities";
import { parsePhones } from "../phones";
import type { PackRecord } from "../types";

const CITY_SOURCE = "bettergovph/hotlines";
const NATIONAL_SOURCE = "bettergovph/bettergov";

/** Offices that answer disaster and rescue calls, whatever list they sit in. */
const DISASTER_NAME = /drrm|disaster|rescue|emergency|command cent|\b911\b/i;

const CITY_CATEGORY: Record<string, string> = {
  medical_hotlines: "medical",
  fire_hotlines: "fire",
  police_hotlines: "police",
  utility_hotlines: "utility",
  government_hotlines: "government",
};

interface CityHotline {
  hotlineName: string;
  hotlineNumber: string;
  regionName?: string;
  province?: string;
  city?: string;
  category: string;
  alternateNumbers?: string[];
}

/** `public/data/hotlines.json` from bettergovph/hotlines: city-level numbers. */
export function convertCityHotlines(json: { hotlines: CityHotline[] }): PackRecord[] {
  const seen = new Set<string>();
  const records: PackRecord[] = [];
  for (const row of json.hotlines) {
    const name = row.hotlineName?.trim();
    if (!name) continue;
    const city = canonicalCity(row.city);
    const key = `${city}|${name}|${row.hotlineNumber}`;
    if (seen.has(key)) continue;
    seen.add(key);

    let category = CITY_CATEGORY[row.category] ?? "government";
    if ((category === "government" || category === "utility") && DISASTER_NAME.test(name)) {
      category = "disaster";
    }
    records.push({
      kind: "hotline",
      name,
      category,
      region: row.regionName ?? null,
      province: row.province ?? null,
      city,
      phones: parsePhones([row.hotlineNumber, ...(row.alternateNumbers ?? [])], {
        allowShort: true,
      }),
      source: CITY_SOURCE,
    });
  }
  return records;
}

interface NationalHotline {
  name: string;
  category: string;
  numbers: string[];
}

function nationalCategory(row: NationalHotline): string {
  if (/national emergency/i.test(row.name)) return "emergency";
  if (/police|pnp/i.test(row.name)) return "police";
  if (/fire/i.test(row.name)) return "fire";
  if (/coast guard|red cross/i.test(row.name)) return "disaster";
  const byGroup: Record<string, string> = {
    Emergency: "emergency",
    Disaster: "disaster",
    Security: "police",
    Transport: "transport",
    Weather: "weather",
    Utility: "utility",
    "Social Services": "social",
  };
  return byGroup[row.category] ?? "government";
}

/**
 * `src/data/philippines_hotlines.json` from bettergovph/bettergov: national
 * numbers, grouped under keys we do not need. Entries repeated across groups
 * are merged by name.
 */
export function convertNationalHotlines(
  json: Record<string, NationalHotline[]>,
): PackRecord[] {
  const byName = new Map<string, PackRecord>();
  for (const group of Object.values(json)) {
    if (!Array.isArray(group)) continue;
    for (const row of group) {
      const name = row.name?.trim();
      if (!name) continue;
      const phones = parsePhones(row.numbers, { allowShort: true });
      const existing = byName.get(name);
      if (existing) {
        for (const phone of phones) {
          if (!existing.phones.some((p) => p.dial === phone.dial && phone.dial !== null)) {
            existing.phones.push(phone);
          }
        }
        continue;
      }
      // The MMDA only covers Metro Manila, so it is a province-level number.
      const metroOnly = /metro manila development authority/i.test(name);
      byName.set(name, {
        kind: "hotline",
        name,
        category: nationalCategory(row),
        province: metroOnly ? METRO_MANILA : null,
        city: null,
        phones,
        source: NATIONAL_SOURCE,
      });
    }
  }
  return [...byName.values()];
}
