export interface Phone {
  /** The number as the source wrote it. */
  display: string;
  /** A string safe to hand to the dialer, or null when we cannot be sure. */
  dial: string | null;
}

export type RecordKind = "hotline" | "agency" | "official" | "service" | "place";

export interface PackRecord {
  kind: RecordKind;
  name: string;
  category: string;
  region?: string | null;
  province?: string | null;
  city?: string | null;
  phones: Phone[];
  address?: string | null;
  lat?: number | null;
  lon?: number | null;
  url?: string | null;
  /** Agency a service belongs to, when the link could be matched. */
  parent?: string | null;
  source: string;
}

export interface Intent {
  id: string;
  label: string;
  hotline_categories: string[];
  place_kinds: string[];
  examples: string[];
}

/** A fixed first-aid card. Its text is checked by hand against its source. */
export interface FirstAidCard {
  id: string;
  title: string;
  /** The title in Filipino, shown as the gloss under it. */
  title_tl: string;
  /** Plain Tagalog, one action per step. */
  steps: string[];
  source_name: string;
  source_url: string;
  /** Taglish messages this card should match. */
  examples: string[];
}

/** An organisation scammers imitate: who it is, where it really lives. */
export interface OfficialSender {
  name: string;
  /** Short form used in reason text, e.g. "DSWD". */
  short: string;
  kind: "agency" | "company";
  /** Names matched as whole words, ignoring case. */
  aliases: string[];
  /** Names that are also ordinary words; the app asks for more context. */
  strict_aliases: string[];
  domains: string[];
  phones: Phone[];
  source_url: string | null;
}

export interface ScamExample {
  text: string;
  type: string;
  type_label: string;
}

export interface ScamReason {
  id: string;
  tl: string;
  en: string;
  fact: string;
}

/** An online gambling operator that advertises by text. */
export interface GamblingBrand {
  name: string;
  /** Names it goes by, matched in the sender, the text and link hosts. */
  aliases: string[];
  /** Domains seen in its messages. May be empty: aliases also match hosts. */
  domains: string[];
}

export interface GamblingRules {
  brands: GamblingBrand[];
  /** Words that mark a link host as a gambling site on their own. */
  host_words: string[];
  /** Promo wording; two different ones plus a link mark a message. */
  terms: string[];
}

export interface ScamData {
  senders: OfficialSender[];
  examples: ScamExample[];
  reasons: ScamReason[];
  shorteners: string[];
  /** Hosts anyone links to, such as facebook.com: never "not their website". */
  neutralHosts: string[];
  /** Sender names real organisations text from. Shown, never trusted. */
  senderIds: string[];
  /** Sender names by bank or e-wallet. A text under one may not carry a link. */
  bankSenders?: Record<string, string[]>;
  gambling?: GamblingRules;
}
