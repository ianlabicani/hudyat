import { Database } from "bun:sqlite";
import { existsSync, mkdirSync, rmSync } from "node:fs";
import { dirname } from "node:path";
import type { Intent, PackRecord } from "./types";

export interface PackMeta {
  name: string;
  area: string;
  /** ISO date, shown on every card. */
  buildDate: string;
  sources: { name: string; used_for: string; licence: string }[];
}

export interface PackContents {
  meta: PackMeta;
  records: PackRecord[];
  intents: Intent[];
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
`;

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
