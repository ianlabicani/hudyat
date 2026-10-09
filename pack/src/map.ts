// Cuts assets/pack/metro-manila.pmtiles from the newest Protomaps daily build.
// Needs the `pmtiles` command (brew install pmtiles).
import { mkdirSync } from "node:fs";
import { dirname, join } from "node:path";

const OUT = join(import.meta.dir, "..", "..", "assets", "pack", "metro-manila.pmtiles");
const BBOX = "120.90,14.34,121.16,14.80";

async function latestBuild(): Promise<string> {
  for (let daysAgo = 0; daysAgo < 7; daysAgo++) {
    const day = new Date(Date.now() - daysAgo * 86_400_000);
    const stamp = day.toISOString().slice(0, 10).replaceAll("-", "");
    const url = `https://build.protomaps.com/${stamp}.pmtiles`;
    if ((await fetch(url, { method: "HEAD" })).ok) return url;
  }
  throw new Error("No Protomaps build found in the last 7 days");
}

mkdirSync(dirname(OUT), { recursive: true });
const source = await latestBuild();
console.log(`extracting from ${source}`);
const result = Bun.spawnSync(["pmtiles", "extract", source, OUT, `--bbox=${BBOX}`, "--maxzoom=15"], {
  stdout: "ignore",
  stderr: "inherit",
});
if (result.exitCode !== 0) throw new Error(`pmtiles exited with ${result.exitCode}`);
console.log(`wrote ${OUT}`);
