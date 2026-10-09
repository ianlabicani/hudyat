import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { dirname } from "node:path";
import type { Intent, PackRecord, ScamData } from "./types";

export interface PackMeta {
  name: string;
  area: string;
  /** ISO date, shown on every card. */
  buildDate: string;
  /** West, south, east, north of the area the places and map cover. */
  bbox: [number, number, number, number];
  sources: { name: string; used_for: string; licence: string }[];
}

export interface PackContents {
  meta: PackMeta;
  records: PackRecord[];
  intents: Intent[];
  /** Data for the message check. The tables are created empty without it. */
  scam?: ScamData;
}

const SCHEMA = `
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE records (
  id INTEGER PRIMARY KEY,
  kind TEXT NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  region TEXT,
  province TEXT,
  city TEXT,
  phones TEXT NOT NULL,
  address TEXT,
  lat REAL,
  lon REAL,
  url TEXT,
  parent TEXT,
  source TEXT NOT NULL
);
CREATE INDEX records_kind_city ON records (kind, city, category);
CREATE INDEX records_kind_category ON records (kind, category);

CREATE VIRTUAL TABLE records_fts USING fts5 (
  name, category, city, parent,
  content = 'records', content_rowid = 'id',
  tokenize = 'unicode61 remove_diacritics 2'
);

CREATE TABLE intents (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  examples TEXT NOT NULL,
  hotline_categories TEXT NOT NULL,
  place_kinds TEXT NOT NULL
);

CREATE TABLE first_aid_cards (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  steps TEXT NOT NULL,
  source_name TEXT NOT NULL,
  source_url TEXT NOT NULL,
  examples TEXT NOT NULL
);

CREATE TABLE official_senders (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  short TEXT NOT NULL,
  kind TEXT NOT NULL,
  aliases TEXT NOT NULL,
  strict_aliases TEXT NOT NULL,
  domains TEXT NOT NULL,
  phones TEXT NOT NULL,
  source_url TEXT
);

CREATE TABLE scam_examples (
  id INTEGER PRIMARY KEY,
  text TEXT NOT NULL,
  type TEXT NOT NULL,
  type_label TEXT NOT NULL
);

CREATE TABLE scam_reasons (
  id TEXT PRIMARY KEY,
  tl TEXT NOT NULL,
  en TEXT NOT NULL,
  fact TEXT NOT NULL
);
`;

/** Throws when a sender could not be matched or would show a bad contact. */
export function validateScamData(scam: ScamData): void {
  for (const sender of scam.senders) {
    if (!sender.name.trim() || sender.domains.length === 0) {
      throw new Error(`Sender without a name or domain: ${JSON.stringify(sender)}`);
    }
    if (sender.aliases.length + sender.strict_aliases.length === 0) {
      throw new Error(`Sender with nothing to match: ${sender.name}`);
    }
    if (sender.kind === "company" && sender.phones.length > 0 && !sender.source_url) {
      throw new Error(`Company number without a source: ${sender.name}`);
    }
  }
  const gambling = scam.gambling;
  if (!gambling) return;
  for (const brand of gambling.brands) {
    if (!brand.name.trim() || brand.aliases.length === 0 || brand.aliases.some((alias) => !alias.trim())) {
      throw new Error(`Gambling brand without a name or alias: ${JSON.stringify(brand)}`);
    }
  }
  if ([...gambling.host_words, ...gambling.terms].some((word) => !word.trim())) {
    throw new Error("Empty gambling word");
  }
}

/** Throws on the first record the app could not show or locate. */
export function validateRecords(records: PackRecord[]): void {
  for (const record of records) {
    if (!record.kind || !record.name?.trim()) {
      throw new Error(`Record without a kind or name: ${JSON.stringify(record)}`);
    }
    if (record.kind === "place" && (record.lat == null || record.lon == null)) {
      throw new Error(`Place without coordinates: ${record.name}`);
    }
  }
}

export function writePack(path: string, contents: PackContents): void {
  validateRecords(contents.records);
  if (contents.scam) validateScamData(contents.scam);
  if (path !== ":memory:") {
    mkdirSync(dirname(path), { recursive: true });
    if (existsSync(path)) rmSync(path);
  }

  const db = new Database(path);
  db.exec(SCHEMA);

  const insertMeta = db.prepare("INSERT INTO meta (key, value) VALUES (?, ?)");
  const insertRecord = db.prepare(
    `INSERT INTO records
       (kind, name, category, region, province, city, phones, address, lat, lon, url, parent, source)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  const insertIntent = db.prepare(
    "INSERT INTO intents (id, label, examples, hotline_categories, place_kinds) VALUES (?, ?, ?, ?, ?)",
  );

  db.transaction(() => {
    insertMeta.run("name", contents.meta.name);
    insertMeta.run("area", contents.meta.area);
    insertMeta.run("build_date", contents.meta.buildDate);
    insertMeta.run("bbox", contents.meta.bbox.join(","));
    insertMeta.run("sources", JSON.stringify(contents.meta.sources));

    for (const r of contents.records) {
      insertRecord.run(
        r.kind,
        r.name.trim(),
        r.category,
        r.region ?? null,
        r.province ?? null,
        r.city ?? null,
        JSON.stringify(r.phones),
        r.address ?? null,
        r.lat ?? null,
        r.lon ?? null,
        r.url ?? null,
        r.parent ?? null,
        r.source,
      );
    }
    const scam = contents.scam;
    if (scam) {
      insertMeta.run("link_shorteners", JSON.stringify(scam.shorteners));
      insertMeta.run("neutral_hosts", JSON.stringify(scam.neutralHosts));
      insertMeta.run("sender_ids", JSON.stringify(scam.senderIds));
      if (scam.gambling) insertMeta.run("gambling", JSON.stringify(scam.gambling));
      const insertSender = db.prepare(
        `INSERT INTO official_senders
           (name, short, kind, aliases, strict_aliases, domains, phones, source_url)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      );
      for (const s of scam.senders) {
        insertSender.run(
          s.name,
          s.short,
          s.kind,
          JSON.stringify(s.aliases),
          JSON.stringify(s.strict_aliases),
          JSON.stringify(s.domains),
          JSON.stringify(s.phones),
          s.source_url,
        );
      }
      const insertExample = db.prepare("INSERT INTO scam_examples (text, type, type_label) VALUES (?, ?, ?)");
      for (const e of scam.examples) insertExample.run(e.text, e.type, e.type_label);
      const insertReason = db.prepare("INSERT INTO scam_reasons (id, tl, en, fact) VALUES (?, ?, ?, ?)");
      for (const r of scam.reasons) insertReason.run(r.id, r.tl, r.en, r.fact);
    }
    for (const intent of contents.intents) {
      insertIntent.run(
        intent.id,
        intent.label,
        JSON.stringify(intent.examples),
        JSON.stringify(intent.hotline_categories),
        JSON.stringify(intent.place_kinds),
      );
    }
  })();

  db.exec("INSERT INTO records_fts (records_fts) VALUES ('rebuild')");
  if (path !== ":memory:") db.exec("VACUUM");
  db.close();
}
