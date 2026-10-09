import type { PackRecord } from "../types";

const SOURCE = "bettergovph/bettergov";

function host(url: string | null | undefined): string | null {
  if (!url) return null;
  try {
    return new URL(url).hostname.replace(/^www\./, "").toLowerCase();
  } catch {
    return null;
  }
}

/**
 * Online services from `src/data/services/*.json`. A service is only a title
 * and a link, so it is matched to an agency by web host to borrow that
 * agency's phone numbers. Unmatched services keep the link alone.
 */
export function convertServices(rows: any[], agencies: PackRecord[]): PackRecord[] {
  const agencyByHost = new Map<string, PackRecord>();
  for (const agency of agencies) {
    const agencyHost = host(agency.url);
    if (agencyHost && !agencyByHost.has(agencyHost)) agencyByHost.set(agencyHost, agency);
  }

  const records: PackRecord[] = [];
  for (const row of rows) {
    const name = typeof row.service === "string" ? row.service.trim() : "";
    if (!name || row.published === false) continue;
    const url = typeof row.url === "string" ? row.url.trim() : null;
    const serviceHost = host(url);
    let agency: PackRecord | undefined;
    if (serviceHost) {
      for (const [agencyHost, candidate] of agencyByHost) {
        if (serviceHost === agencyHost || serviceHost.endsWith(`.${agencyHost}`)) {
          agency = candidate;
          break;
        }
      }
    }
    records.push({
      kind: "service",
      name,
      category: row.category?.name ?? "Uncategorized",
      phones: agency?.phones ?? [],
      url,
      parent: agency?.name ?? null,
      source: SOURCE,
    });
  }
  return records;
}
