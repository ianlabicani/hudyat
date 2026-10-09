// Downloads the raw sources into pack/raw/. Run with `bun run fetch`; pass
// --force to download files that are already there.
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const RAW = join(import.meta.dir, "..", "raw");
const BETTERGOV = "https://raw.githubusercontent.com/bettergovph/bettergov/main/src/data";
const HOTLINES = "https://raw.githubusercontent.com/bettergovph/hotlines/main/public/data";

export const DIRECTORY_FILES = ["departments", "executive", "constitutional", "legislative", "judicial"];
export const LGU_FILES = [
  "bangsamoro-autonomous-region-in-muslim-mindanao",
  "cordillera-administrative-region",
  "mimaropa-region",
  "national-capital-region",
  "negros-island-region",
  "region-i-ilocos-region",
  "region-ii-cagayan-valley",
  "region-iii-central-luzon",
  "region-iva-calabarzon",
  "region-ix-zamboanga-peninsula",
  "region-v-bicol-region",
  "region-x-northern-mindanao",
  "region-xi-davao-region",
  "region-xii-soccsksargen",
  "region-xiiicaraga",
  "special-geographic-area",
];
export const SERVICE_FILES = [
  "business-trade",
  "certificates-ids",
  "contributions",
  "disaster-weather",
  "education",
  "employment",
  "health",
  "housing",
  "passport-travel",
  "social-services",
  "tax",
  "transport-driving",
  "uncategorized",
];

const force = process.argv.includes("--force");

async function download(url: string, target: string, init?: RequestInit): Promise<void> {
  const path = join(RAW, target);
  if (existsSync(path) && !force) return;
  const response = await fetch(url, init);
  if (!response.ok) throw new Error(`${response.status} for ${url}`);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, await response.text());
  console.log(`fetched ${target}`);
}

await download(`${HOTLINES}/hotlines.json`, "hotlines.json");
await download(`${BETTERGOV}/philippines_hotlines.json`, "philippines_hotlines.json");
for (const name of DIRECTORY_FILES) {
  await download(`${BETTERGOV}/directory/${name}.json`, `directory/${name}.json`);
}
for (const name of LGU_FILES) {
  await download(`${BETTERGOV}/directory/lgu/${name}.json`, `lgu/${name}.json`);
}
for (const name of SERVICE_FILES) {
  await download(`${BETTERGOV}/services/${name}.json`, `services/${name}.json`);
}

const query = readFileSync(join(import.meta.dir, "overpass.ql"), "utf8");
await download("https://overpass-api.de/api/interpreter", "overpass.json", {
  method: "POST",
  headers: { "User-Agent": "hudyat-pack-builder/0.1" },
  body: new URLSearchParams({ data: query }),
});
console.log("raw sources ready");
