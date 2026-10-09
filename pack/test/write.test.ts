import { Database } from "bun:sqlite";
import { afterAll, describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import firstAidData from "../data/first_aid.json";
import type { FirstAidCard, PackRecord } from "../src/types";
import { validateFirstAid, validateRecords, validateScamData, writePack } from "../src/write";

const dir = mkdtempSync(join(tmpdir(), "hudyat-pack-"));
afterAll(() => rmSync(dir, { recursive: true, force: true }));

const hotline: PackRecord = {
  kind: "hotline",
  name: "Parañaque Rescue",
  category: "disaster",
  city: "Parañaque",
  province: "Metro Manila",
  phones: [{ display: "911", dial: "911" }],
  source: "test",
};
const place: PackRecord = {
  kind: "place",
  name: "Ospital ng Parañaque",
  category: "hospital",
  city: "Parañaque",
  phones: [],
  lat: 14.48,
  lon: 121.0,
  source: "test",
};

describe("validateRecords", () => {
  test("rejects a record with no name", () => {
    expect(() => validateRecords([{ ...hotline, name: " " }])).toThrow("without a kind or name");
  });

  test("rejects a place with no coordinates", () => {
    expect(() => validateRecords([{ ...place, lat: null }])).toThrow("without coordinates");
  });
});

describe("writePack", () => {
  const path = join(dir, "pack.sqlite");
  writePack(path, {
    meta: { name: "Test", area: "Test", buildDate: "2026-10-09", bbox: [120.9, 14.34, 121.16, 14.8], sources: [] },
    records: [hotline, place],
    intents: [
      { id: "fire", label: "Fire", hotline_categories: ["fire"], place_kinds: ["fire_station"], examples: ["may sunog"] },
    ],
  });
  const db = new Database(path, { readonly: true });

  test("stores meta, records and intents", () => {
    expect(db.query("SELECT value FROM meta WHERE key = 'build_date'").get()).toEqual({ value: "2026-10-09" });
    expect(db.query("SELECT value FROM meta WHERE key = 'bbox'").get()).toEqual({ value: "120.9,14.34,121.16,14.8" });
    expect(db.query("SELECT count(*) AS n FROM records").get()).toEqual({ n: 2 });
    const intent = db.query("SELECT examples FROM intents WHERE id = 'fire'").get() as { examples: string };
    expect(JSON.parse(intent.examples)).toEqual(["may sunog"]);
  });

  test("keeps phones as JSON with both forms", () => {
    const row = db.query("SELECT phones FROM records WHERE kind = 'hotline'").get() as { phones: string };
    expect(JSON.parse(row.phones)).toEqual([{ display: "911", dial: "911" }]);
  });

  test("keyword search ignores accents and matches prefixes", () => {
    const search = (q: string) =>
      db
        .query(
          "SELECT r.name FROM records_fts f JOIN records r ON r.id = f.rowid WHERE records_fts MATCH ? ORDER BY r.name",
        )
        .all(q)
        .map((row: any) => row.name);
    expect(search("paranaque")).toEqual(["Ospital ng Parañaque", "Parañaque Rescue"]);
    expect(search("ospit*")).toEqual(["Ospital ng Parañaque"]);
    expect(search("bumbero")).toEqual([]);
  });

  test("has an empty first-aid table ready for the cards", () => {
    expect(db.query("SELECT count(*) AS n FROM first_aid_cards").get()).toEqual({ n: 0 });
  });
});

describe("gambling rules", () => {
  const gambling = {
    brands: [{ name: "BingoPlus", aliases: ["BingoPlus"], domains: ["bingoplus.com"] }],
    host_words: ["casino"],
    terms: ["rebate", "cashback"],
  };
  const scam = { senders: [], examples: [], reasons: [], shorteners: [], neutralHosts: [], senderIds: [], gambling };

  test("are stored under one meta key", () => {
    const path = join(dir, "gambling.sqlite");
    writePack(path, {
      meta: { name: "Test", area: "Test", buildDate: "2026-10-09", bbox: [120.9, 14.34, 121.16, 14.8], sources: [] },
      records: [hotline],
      intents: [],
      scam,
    });
    const db = new Database(path, { readonly: true });
    const row = db.query("SELECT value FROM meta WHERE key = 'gambling'").get() as { value: string };
    expect(JSON.parse(row.value)).toEqual(gambling);
    db.close();
  });

  test("reject a brand with nothing to match", () => {
    const bad = { ...gambling, brands: [{ name: "Nameless", aliases: [], domains: [] }] };
    expect(() => validateScamData({ ...scam, gambling: bad })).toThrow("without a name or alias");
  });

  test("reject an empty word", () => {
    expect(() => validateScamData({ ...scam, gambling: { ...gambling, terms: [" "] } })).toThrow("Empty gambling word");
  });
});

describe("first-aid cards", () => {
  const card: FirstAidCard = {
    id: "burn",
    title: "Burn",
    title_tl: "Paso",
    steps: ["Palamigin sa umaagos na tubig.", "Takpan nang maluwag."],
    source_name: "British Red Cross",
    source_url: "https://example.org/burns",
    examples: ["napaso ang kamay", "nabanlian ng sabaw", "burned my hand"],
  };

  test("are stored with their steps, source and examples", () => {
    const path = join(dir, "first-aid.sqlite");
    writePack(path, {
      meta: { name: "Test", area: "Test", buildDate: "2026-10-09", bbox: [0, 0, 1, 1], sources: [] },
      records: [hotline],
      intents: [],
      firstAid: [card],
    });
    const db = new Database(path, { readonly: true });
    const row = db.query("SELECT * FROM first_aid_cards WHERE id = 'burn'").get() as Record<string, string>;
    db.close();
    expect(row.title).toBe("Burn");
    expect(row.title_tl).toBe("Paso");
    expect(JSON.parse(row.steps)).toEqual(card.steps);
    expect(row.source_url).toBe("https://example.org/burns");
    expect(JSON.parse(row.examples)).toHaveLength(3);
  });

  test("reject a card with no steps to follow", () => {
    expect(() => validateFirstAid([{ ...card, steps: ["Isa lang."] }])).toThrow("without steps");
    expect(() => validateFirstAid([{ ...card, steps: ["Una.", " "] }])).toThrow("without steps");
  });

  test("reject a card that cannot be cited", () => {
    expect(() => validateFirstAid([{ ...card, source_name: "" }])).toThrow("without a source");
    expect(() => validateFirstAid([{ ...card, source_url: "redcross.org" }])).toThrow("without a source");
  });

  test("reject a card that could not be matched or told apart", () => {
    expect(() => validateFirstAid([{ ...card, examples: ["napaso"] }])).toThrow("too few examples");
    expect(() => validateFirstAid([card, card])).toThrow("repeated id");
    expect(() => validateFirstAid([{ ...card, title_tl: "" }])).toThrow("without a title");
  });

  test("the shipped cards are all valid", () => {
    expect(() => validateFirstAid(firstAidData)).not.toThrow();
    expect(firstAidData.length).toBe(8);
  });
});
