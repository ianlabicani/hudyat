// Prints what a saved SMS inbox says about senders and links, for building
// the company and gambling lists. Run with `bun run inbox`. The inbox file is
// private: it lives in pack/raw/inbox/ (git-ignored) and nothing is written.
import { Database } from "bun:sqlite";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";

const ROOT = join(import.meta.dir, "..");
const FOLDER = join(ROOT, "raw", "inbox");
const PACK = join(ROOT, "..", "assets", "pack", "metro-manila.sqlite");

interface Message {
  sender: string;
  sender_kind: "name" | "code" | "mobile";
  body: string;
}

const files = existsSync(FOLDER) ? readdirSync(FOLDER).filter((f) => f.endsWith(".json")).sort() : [];
if (files.length === 0) {
  console.log(`No inbox file in ${FOLDER}.`);
  process.exit(0);
}
const messages: Message[] = JSON.parse(readFileSync(join(FOLDER, files.at(-1)!), "utf8")).messages;

const db = new Database(PACK, { readonly: true });
const senders = db.query("SELECT short, aliases, strict_aliases, domains FROM official_senders").all() as any[];
const meta = (key: string) => (db.query("SELECT value FROM meta WHERE key = ?").get(key) as any)?.value;
const shorteners: string[] = JSON.parse(meta("link_shorteners") ?? "[]");
const gambling: string[] = (JSON.parse(meta("gambling") ?? "{}").brands ?? []).flatMap((b: any) => b.domains);
const official: [string, string][] = senders.flatMap((s) =>
  (JSON.parse(s.domains) as string[]).map((d): [string, string] => [d, s.short]),
);
const names: [string, string][] = senders.flatMap((s) =>
  [...JSON.parse(s.aliases), ...JSON.parse(s.strict_aliases)].map((a: string): [string, string] => [
    a.toLowerCase().replace(/[^a-z0-9]/g, ""),
    s.short,
  ]),
);

const on = (host: string, domain: string) => host === domain || host.endsWith(`.${domain}`);
const count = <T>(items: T[]) => {
  const totals = new Map<T, number>();
  for (const item of items) totals.set(item, (totals.get(item) ?? 0) + 1);
  return [...totals].sort((a, b) => b[1] - a[1]);
};

console.log(`${messages.length} messages from ${files.at(-1)}\n\nSender names`);
for (const [name, n] of count(messages.filter((m) => m.sender_kind === "name").map((m) => m.sender))) {
  const key = name.toLowerCase().replace(/[^a-z0-9]/g, "");
  const match = names.find(([alias]) => alias.length >= 3 && key.startsWith(alias))?.[1];
  console.log(`  ${String(n).padStart(4)}  ${name.padEnd(16)} ${match ?? "— not in the pack"}`);
}

const LINK = /https?:\/\/([^\s/?#]+)|(?<![\w@.])((?:[a-z0-9-]+\.)+[a-z]{2,6})(?![\w-])/gi;
const hosts = messages.flatMap((m) =>
  [...m.body.matchAll(LINK)].map((x) => (x[1] ?? x[2]).toLowerCase().replace(/^www\./, "").replace(/\.$/, "")),
);
console.log("\nLink hosts");
for (const [host, n] of count(hosts)) {
  const label = host.endsWith(".gov.ph")
    ? "government"
    : (official.find(([d]) => on(host, d))?.[1] ??
      (shorteners.some((d) => on(host, d)) ? "shortener" : gambling.some((d) => on(host, d)) ? "gambling" : "— unknown"));
  console.log(`  ${String(n).padStart(4)}  ${host.padEnd(28)} ${label}`);
}

// A link written so that filters miss it: "word. com", "word .com".
const BROKEN = /\b([a-z][a-z0-9-]{4,})(?: \.|\. | \. |\s?[([]dot[)\]]\s?)(com|ph|net|org|xyz|top|cc)\b/gi;
console.log("\nBroken-up links");
for (const [key, n] of count(
  messages.flatMap((m) => [...m.body.matchAll(BROKEN)].map((x) => `${m.sender_kind.padEnd(6)} ${x[1]}.${x[2]}`.toLowerCase())),
)) {
  console.log(`  ${String(n).padStart(4)}  ${key}`);
}
