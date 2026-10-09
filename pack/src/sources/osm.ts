import { METRO_MANILA, canonicalCity } from "../cities";
import { parsePhones } from "../phones";
import type { PackRecord } from "../types";

const SOURCE = "OpenStreetMap";

type Tags = Record<string, string>;

/**
 * Place category for an OpenStreetMap element, or null to leave it out.
 * `amenity=shelter` is mostly waiting sheds and gazebos, so a shelter only
 * counts when it is tagged as an assembly point or a shelter for displaced
 * people.
 */
export function placeCategory(tags: Tags): string | null {
  switch (tags.amenity) {
    case "hospital":
      return "hospital";
    case "clinic":
    case "doctors":
      return "clinic";
    case "pharmacy":
      return "pharmacy";
    case "police":
      return "police";
    case "fire_station":
      return "fire_station";
  }
  if (tags.emergency === "assembly_point") return "shelter";
  if (tags.social_facility === "shelter") {
    const audience = tags["social_facility:for"] ?? "";
    return audience === "" || /displaced/.test(audience) ? "shelter" : null;
  }
  return null;
}

function address(tags: Tags): string | null {
  const street = [tags["addr:housenumber"], tags["addr:street"]].filter(Boolean).join(" ");
  const parts = [street, tags["addr:suburb"] ?? tags["addr:barangay"], tags["addr:city"]]
    .map((part) => part?.trim())
    .filter((part): part is string => !!part);
  return parts.length > 0 ? parts.join(", ") : null;
}

/**
 * Overpass output from `pack/src/overpass.ql`: for each city an `area` element
 * followed by the places inside it. Places without a name are dropped, since a
 * card row with no name cannot be acted on.
 */
export function convertOverpass(json: { elements: any[] }): PackRecord[] {
  const records: PackRecord[] = [];
  const seen = new Set<string>();
  let city: string | null = null;

  for (const element of json.elements) {
    const tags: Tags = element.tags ?? {};
    if (element.type === "area") {
      city = canonicalCity(tags.name);
      continue;
    }
    const category = placeCategory(tags);
    const name = (tags.name ?? tags.operator)?.trim();
    const lat = element.lat ?? element.center?.lat;
    const lon = element.lon ?? element.center?.lon;
    if (!category || !name || typeof lat !== "number" || typeof lon !== "number") continue;

    const id = `${element.type}/${element.id}`;
    if (seen.has(id)) continue;
    seen.add(id);

    records.push({
      kind: "place",
      name,
      category,
      province: METRO_MANILA,
      city,
      phones: parsePhones(tags.phone ?? tags["contact:phone"]),
      address: address(tags),
      lat,
      lon,
      url: tags.website ?? null,
      source: SOURCE,
    });
  }
  return records;
}
