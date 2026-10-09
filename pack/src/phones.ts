import type { Phone } from "./types";

export interface PhoneOptions {
  /** Accept 3 to 5 digit numbers such as 911. Only hotline sources set this. */
  allowShort?: boolean;
}

/** Splits "8682-9279; 8646-1634" or "a / b" into separate numbers. */
export function splitNumbers(raw: string): string[] {
  return raw
    .split(/\s*;\s*|\s+\/\s+/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
}

/**
 * Turns a number as written in a source into something the dialer accepts.
 * Returns null whenever the result would be a guess: a wrong number on an
 * emergency card is worse than no Call button.
 */
export function toDial(display: string, options: PhoneOptions = {}): string | null {
  const text = display.trim();
  if (/^text\b/i.test(text)) return null;
  // "8932-0179 F" is a fax line; "TF" (telefax) still takes voice calls.
  if (/\d\s+F$/.test(text)) return null;

  const lead = text.match(/^\+?[\d\s().-]+/)?.[0] ?? "";
  let digits = lead.replace(/\D/g, "");
  if (digits.length === 0) return null;

  if (lead.trimStart().startsWith("+63") || (digits.startsWith("63") && digits.length >= 11)) {
    digits = `0${digits.slice(2)}`;
  }

  if (digits.length <= 5) {
    return options.allowShort && digits.length >= 3 ? digits : null;
  }
  // Mobile, with or without the leading zero.
  if (/^09\d{9}$/.test(digits)) return digits;
  if (/^9\d{9}$/.test(digits)) return `0${digits}`;
  // Only Metro Manila has 8-digit subscriber numbers, so the area code is 02.
  if (/^[2-9]\d{7}$/.test(digits)) return `02${digits}`;
  if (/^02\d{8}$/.test(digits)) return digits;
  // Provincial landline written with its area code, for example (047) 237-2256.
  if (/^0[3-8]\d{8}$/.test(digits)) return digits;
  // Seven digits is a pre-2019 Manila number or a provincial number without
  // its area code. Either way it cannot be dialled as written.
  return null;
}

export function parsePhones(
  raw: string | string[] | null | undefined,
  options: PhoneOptions = {},
): Phone[] {
  if (raw == null) return [];
  const parts = (Array.isArray(raw) ? raw : [raw]).flatMap(splitNumbers);
  const seen = new Set<string>();
  const phones: Phone[] = [];
  for (const display of parts) {
    // "loc. 2601, 3310" on its own is an extension list, not a number.
    if (/^loc\b/i.test(display)) continue;
    if (seen.has(display)) continue;
    seen.add(display);
    phones.push({ display, dial: toDial(display, options) });
  }
  return phones;
}
