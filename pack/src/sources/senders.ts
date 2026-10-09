import { parsePhones } from "../phones";
import type { OfficialSender, PackRecord } from "../types";

export interface SenderRules {
  /** Extra names by domain, for agencies whose acronym is not derivable. */
  aliases: Record<string, string[]>;
  /** Acronyms that are also ordinary words or belong to other bodies. */
  blocked_acronyms: string[];
}

export interface Company {
  name: string;
  aliases: string[];
  strict_aliases: string[];
  domains: string[];
  phones: OfficialSender["phones"];
  source_url: string;
}

const SMALL_WORDS = new Set(["OF", "THE", "AND", "NG", "FOR", "ON", "IN", "SA"]);
const SKIPPED_TYPES = new Set(["diplomatic", "foreign-service"]);

/** "https://www.DSWD.gov.ph/about" becomes "dswd.gov.ph". */
export function hostOf(url: string | null | undefined): string | null {
  if (typeof url !== "string") return null;
  const host = url
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .split(/[/?#]/)[0]
    .replace(/^www\./, "");
  return /^[a-z0-9-]+(\.[a-z0-9-]+)+$/.test(host) ? host : null;
}

/**
 * The acronym an agency goes by, taken from its domain when the first label
 * is the initials of its name: dswd.gov.ph for "Department of Social Welfare
 * and Development". Returns null when the label is something else.
 */
export function acronymFor(name: string, host: string): string | null {
  const words = name.split("(")[0].toUpperCase().match(/[A-Z]+/g) ?? [];
  const all = words.map((word) => word[0]).join("");
  const main = words
    .filter((word) => !SMALL_WORDS.has(word))
    .map((word) => word[0])
    .join("");
  const label = host.split(".")[0].toUpperCase();
  return label.length >= 3 && (label === all || label === main) ? label : null;
}

function titleCase(name: string): string {
  if (name !== name.toUpperCase()) return name;
  return name
    .toLowerCase()
    .replace(/\b[a-z]/g, (letter) => letter.toUpperCase())
    .replace(/\b(Of|The|And|Ng|For|On|In)\b/g, (word) => word.toLowerCase())
    .replace(/^[a-z]/, (letter) => letter.toUpperCase());
}

/**
 * Agencies from bettergov's `websites.json`. Schools and embassies are left
 * out: nobody is sent a fake text in their name. When the row has no phone,
 * the trunkline of the matching agency record is used.
 */
export function convertAgencySenders(
  rows: any[],
  rules: SenderRules,
  agencies: PackRecord[] = [],
): OfficialSender[] {
  const blocked = new Set(rules.blocked_acronyms.map((item) => item.toUpperCase()));
  const phonesByHost = new Map<string, PackRecord["phones"]>();
  for (const agency of agencies) {
    const host = hostOf(agency.url);
    if (host && agency.phones.length > 0 && !phonesByHost.has(host)) {
      phonesByHost.set(host, agency.phones);
    }
  }

  const senders = new Map<string, OfficialSender>();
  for (const row of rows) {
    const host = hostOf(row.website);
    const rawName = typeof row.name === "string" ? row.name.trim() : "";
    if (!host || !rawName || SKIPPED_TYPES.has(row.type) || host.endsWith(".edu.ph")) continue;
    if (senders.has(host)) continue;

    const fullName = titleCase(rawName.split("(")[0].trim());
    const inBrackets = rawName.match(/\(([A-Za-z-]{3,12})\)/)?.[1] ?? null;
    const acronym = acronymFor(rawName, host) ?? inBrackets?.toUpperCase() ?? null;
    const extra = rules.aliases[host] ?? [];
    const aliases = [fullName, ...extra];
    if (acronym && !blocked.has(acronym)) aliases.push(acronym);

    const own = parsePhones(row.contact).filter((phone) => phone.dial);
    senders.set(host, {
      name: fullName,
      short: acronym && !blocked.has(acronym) ? acronym : (extra[0] ?? fullName),
      kind: "agency",
      aliases: [...new Set(aliases)],
      strict_aliases: [],
      domains: [host],
      phones: own.length > 0 ? own : (phonesByHost.get(host) ?? []).filter((phone) => phone.dial),
      source_url: `https://${host}`,
    });
  }
  return [...senders.values()];
}

/** The hand-made company list, already in the right shape. */
export function convertCompanies(companies: Company[]): OfficialSender[] {
  return companies.map((company) => ({
    name: company.name,
    short: company.name,
    kind: "company",
    aliases: company.aliases,
    strict_aliases: company.strict_aliases,
    domains: company.domains,
    phones: company.phones,
    source_url: company.source_url,
  }));
}

/** Companies win when an agency row has the same domain (Landbank). */
export function mergeSenders(companies: OfficialSender[], agencies: OfficialSender[]): OfficialSender[] {
  const taken = new Set(companies.flatMap((company) => company.domains));
  return [...companies, ...agencies.filter((agency) => !agency.domains.some((d) => taken.has(d)))];
}
