// Builds assets/pack/metro-manila.sqlite from pack/raw/. Run `bun run fetch`
// first, then `bun run build`.
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { convertAgencies, convertLgu } from "./sources/directory";
import { convertCityHotlines, convertNationalHotlines } from "./sources/hotlines";
import { convertOverpass } from "./sources/osm";
import { convertAgencySenders, convertCompanies, mergeSenders } from "./sources/senders";
import { convertServices } from "./sources/services";
import type { Intent, PackRecord } from "./types";
import { writePack } from "./write";

const ROOT = join(import.meta.dir, "..");
const RAW = join(ROOT, "raw");
const OUT = join(ROOT, "..", "assets", "pack", "metro-manila.sqlite");

const read = (path: string) => JSON.parse(readFileSync(join(RAW, path), "utf8"));
const list = (dir: string) =>
  readdirSync(join(RAW, dir))
    .filter((file) => file.endsWith(".json"))
    .sort();

const AGENCY_CATEGORY: Record<string, string> = {
  departments: "Department",
  executive: "Executive office",
  constitutional: "Constitutional office",
  legislative: "Legislature",
  judicial: "Judiciary",
};

const hotlines = [
  ...convertNationalHotlines(read("philippines_hotlines.json")),
  ...convertCityHotlines(read("hotlines.json")),
];
const agencies = list("directory").flatMap((file) =>
  convertAgencies(read(`directory/${file}`), AGENCY_CATEGORY[file.replace(".json", "")] ?? "Agency"),
);
const officials = list("lgu").flatMap((file) => convertLgu(read(`lgu/${file}`)));
const services = list("services").flatMap((file) => convertServices(read(`services/${file}`), agencies));
const places = convertOverpass(read("overpass.json"));

const records: PackRecord[] = [...hotlines, ...agencies, ...officials, ...services, ...places];
const data = (name: string) => JSON.parse(readFileSync(join(ROOT, "data", name), "utf8"));
const intents: Intent[] = data("intents.json");

const senderRules = data("sender_rules.json");
const senders = mergeSenders(
  convertCompanies(data("companies.json")),
  convertAgencySenders(read("websites.json"), senderRules, agencies),
);

writePack(OUT, {
  meta: {
    name: "Metro Manila",
    area: "Metro Manila",
    buildDate: new Date().toISOString().slice(0, 10),
    bbox: [120.9, 14.34, 121.16, 14.8],
    sources: [
      { name: "bettergovph/bettergov", used_for: "Agencies, officials, services, national hotlines", licence: "CC0-1.0" },
      { name: "bettergovph/hotlines", used_for: "City hotlines", licence: "None listed" },
      { name: "OpenStreetMap contributors", used_for: "Places and map", licence: "ODbL" },
      { name: "bettergovph/bettergov websites list", used_for: "Official agency websites", licence: "CC0-1.0" },
      { name: "Company websites", used_for: "Official company websites and hotlines", licence: "Facts, cited per company" },
      { name: "Hand-made gambling list", used_for: "Online gambling brands, domains and promo wording", licence: "Own work" },
    ],
  },
  records,
  intents,
  scam: {
    senders,
    examples: data("scam_examples.json"),
    reasons: data("scam_reasons.json"),
    shorteners: senderRules.shorteners,
    gambling: data("gambling.json"),
  },
});

const count = (kind: string) => records.filter((r) => r.kind === kind).length;
console.log(`wrote ${OUT}`);
for (const kind of ["hotline", "agency", "official", "service", "place"]) {
  console.log(`  ${kind}: ${count(kind)}`);
}
console.log(`  official senders: ${senders.length} (${senders.filter((s) => s.phones.length > 0).length} with a number)`);
const dialable = records.filter((r) => r.phones.some((p) => p.dial)).length;
console.log(`  records with a dialable number: ${dialable} of ${records.length}`);
