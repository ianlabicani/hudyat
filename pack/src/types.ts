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
