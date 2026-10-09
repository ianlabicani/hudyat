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

export interface ScamData {
  senders: OfficialSender[];
  examples: ScamExample[];
  reasons: ScamReason[];
  shorteners: string[];
}
