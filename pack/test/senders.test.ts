import { Database } from "bun:sqlite";
import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  acronymFor,
  convertAgencySenders,
  convertCompanies,
  hostOf,
  mergeSenders,
} from "../src/sources/senders";
import type { PackRecord, ScamData } from "../src/types";
import { validateScamData, writePack } from "../src/write";

const rules = { aliases: { "philhealth.gov.ph": ["PhilHealth"] }, blocked_acronyms: ["DA"] };
const row = (name: string, website: string | null, extra: object = {}) => ({
  name,
  website,
  contact: null,
  type: "departments",
  ...extra,
});

describe("hostOf", () => {
  test("strips the scheme, www and path", () => {
    expect(hostOf("https://www.DSWD.gov.ph/about")).toBe("dswd.gov.ph");
    expect(hostOf("www.landbank.com")).toBe("landbank.com");
  });
  test("is null for something that is not a host", () => {
    expect(hostOf(null)).toBeNull();
    expect(hostOf("none")).toBeNull();
  });
});

describe("acronymFor", () => {
  test("takes the domain label when it is the initials of the name", () => {
    expect(acronymFor("DEPARTMENT OF SOCIAL WELFARE AND DEVELOPMENT", "dswd.gov.ph")).toBe("DSWD");
    expect(acronymFor("SOCIAL SECURITY SYSTEM", "sss.gov.ph")).toBe("SSS");
  });
  test("is null when the label is something else, or too short", () => {
    expect(acronymFor("PHILIPPINE HEALTH INSURANCE CORPORATION", "philhealth.gov.ph")).toBeNull();
    expect(acronymFor("DEPARTMENT OF AGRICULTURE", "da.gov.ph")).toBeNull();
  });
});

describe("convertAgencySenders", () => {
  test("gives a readable name, the acronym and the domain", () => {
    const [dswd] = convertAgencySenders([row("DEPARTMENT OF SOCIAL WELFARE AND DEVELOPMENT", "www.dswd.gov.ph")], rules);
    expect(dswd.name).toBe("Department of Social Welfare and Development");
    expect(dswd.short).toBe("DSWD");
    expect(dswd.aliases).toContain("DSWD");
    expect(dswd.domains).toEqual(["dswd.gov.ph"]);
  });

  test("uses the listed alias when the acronym cannot be derived", () => {
    const [philhealth] = convertAgencySenders([row("PHILIPPINE HEALTH INSURANCE CORPORATION", "philhealth.gov.ph")], rules);
    expect(philhealth.short).toBe("PhilHealth");
  });

  test("leaves out schools, embassies, rows without a website and repeats", () => {
    const senders = convertAgencySenders(
      [
        row("UNIVERSITY OF ABRA", "www.asist.edu.ph"),
        row("Embassy of Japan", "ph.emb-japan.go.jp", { type: "diplomatic" }),
        row("ADJUDICATION BUREAU", null),
        row("BUREAU OF INTERNAL REVENUE", "www.bir.gov.ph"),
        row("BUREAU OF INTERNAL REVENUE", "www.bir.gov.ph"),
      ],
      rules,
    );
    expect(senders.map((s) => s.short)).toEqual(["BIR"]);
  });

  test("keeps only dialable numbers, and borrows the agency trunkline", () => {
    const agency: PackRecord = {
      kind: "agency",
      name: "DSWD",
      category: "Department",
      phones: [{ display: "8931-8101", dial: "0289318101" }],
      url: "https://www.dswd.gov.ph",
      source: "test",
    };
    const senders = convertAgencySenders(
      [
        row("BUREAU OF INTERNAL REVENUE", "bir.gov.ph", { contact: "8922-3293; 922-1234" }),
        row("DEPARTMENT OF SOCIAL WELFARE AND DEVELOPMENT", "dswd.gov.ph"),
      ],
      rules,
      [agency],
    );
    expect(senders[0].phones).toEqual([{ display: "8922-3293", dial: "0289223293" }]);
    expect(senders[1].phones).toEqual(agency.phones);
  });
});

describe("the shipped data files", () => {
  const data = (name: string) => JSON.parse(readFileSync(join(import.meta.dir, "..", "data", name), "utf8"));
  const companies = convertCompanies(data("companies.json"));

  test("every company number has a dial string and a source on its own site", () => {
    for (const company of companies) {
      for (const phone of company.phones) expect(phone.dial).toMatch(/^[*\d]+$/);
      const source = hostOf(company.source_url);
      expect(company.domains.some((d) => source === d || source?.endsWith(`.${d}`))).toBe(true);
    }
  });

  test("a company replaces the agency row with the same domain", () => {
    const merged = mergeSenders(companies, convertAgencySenders([row("LAND BANK OF THE PHILIPPINES", "www.landbank.com")], rules));
    expect(merged.filter((s) => s.domains.includes("landbank.com"))).toHaveLength(1);
  });

  test("scam examples cover eight types and reasons have both languages", () => {
    const examples = data("scam_examples.json");
    expect(new Set(examples.map((e: any) => e.type)).size).toBe(8);
    for (const reason of data("scam_reasons.json")) {
      expect(reason.tl.length).toBeGreaterThan(10);
      expect(reason.en.length).toBeGreaterThan(10);
    }
  });

  test("the held-out test messages are not among the examples", () => {
    const examples = new Set(data("scam_examples.json").map((e: any) => e.text));
    for (const message of data("check_messages.json")) expect(examples.has(message.text)).toBe(false);
  });
});

describe("writePack with scam data", () => {
  const scam: ScamData = {
    senders: convertCompanies([
      {
        name: "GCash",
        aliases: ["GCash"],
        strict_aliases: [],
        domains: ["gcash.com"],
        phones: [{ display: "2882", dial: "2882" }],
        source_url: "https://help.gcash.com",
      },
    ]),
    examples: [{ text: "Na-lock ang account mo", type: "account_lock", type_label: "Na-lock na account" }],
    reasons: [{ id: "phrasing", tl: "Kahawig ng scam.", en: "Close to a scam.", fact: "Uri: {type}" }],
    shorteners: ["bit.ly"],
  };
  const meta = { name: "T", area: "T", buildDate: "2026-10-09", bbox: [0, 0, 1, 1] as [number, number, number, number], sources: [] };

  test("stores senders, examples, reasons and shorteners", () => {
    const path = join(import.meta.dir, "..", "raw", ".test-scam.sqlite");
    writePack(path, { meta, records: [], intents: [], scam });
    const db = new Database(path, { readonly: true });
    const sender = db.query("SELECT * FROM official_senders").get() as any;
    expect(JSON.parse(sender.domains)).toEqual(["gcash.com"]);
    expect(JSON.parse(sender.phones)[0].dial).toBe("2882");
    expect(db.query("SELECT count(*) AS n FROM scam_examples").get()).toEqual({ n: 1 });
    expect(db.query("SELECT tl FROM scam_reasons WHERE id = 'phrasing'").get()).toEqual({ tl: "Kahawig ng scam." });
    expect(JSON.parse((db.query("SELECT value FROM meta WHERE key = 'link_shorteners'").get() as any).value)).toEqual(["bit.ly"]);
    db.close();
  });

  test("rejects a company number with no source", () => {
    const bad = { ...scam, senders: [{ ...scam.senders[0], source_url: null }] };
    expect(() => validateScamData(bad)).toThrow("without a source");
  });
});
