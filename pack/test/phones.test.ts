import { describe, expect, test } from "bun:test";
import { canonicalCity, cityKey, isMetroManilaCity } from "../src/cities";
import { parsePhones, splitNumbers, toDial } from "../src/phones";

describe("toDial", () => {
  test("keeps mobile numbers and adds a missing leading zero", () => {
    expect(toDial("09995489244")).toBe("09995489244");
    expect(toDial("0917-847-5757 (Text Hotline)")).toBe("09178475757");
    expect(toDial("9171234567")).toBe("09171234567");
  });

  test("adds the Metro Manila area code to 8-digit numbers", () => {
    expect(toDial("88185150")).toBe("0288185150");
    expect(toDial("8682-9279")).toBe("0286829279");
    expect(toDial("0288746177")).toBe("0288746177");
  });

  test("rewrites international prefixes to local form", () => {
    expect(toDial("(632) 8657-3300")).toBe("0286573300");
    expect(toDial("+63 2 8523 8131")).toBe("0285238131");
    expect(toDial("+63 917 123 4567")).toBe("09171234567");
  });

  test("uses only the first number of a range and drops the extension", () => {
    expect(toDial("(02) 8911-5061 to 65 local 100")).toBe("0289115061");
    expect(toDial("8288-8811 loc. 2223, 2224")).toBe("0282888811");
  });

  test("keeps provincial numbers written with an area code", () => {
    expect(toDial("(047) 237-2256")).toBe("0472372256");
  });

  test("accepts short codes only when the source is a hotline list", () => {
    expect(toDial("911", { allowShort: true })).toBe("911");
    expect(toDial("143 (Hotline)", { allowShort: true })).toBe("143");
    expect(toDial("2527")).toBeNull();
  });

  test("refuses numbers it would have to guess at", () => {
    expect(toDial("2536808")).toBeNull();
    expect(toDial("935-1757 loc. 104")).toBeNull();
    expect(toDial("Text LTOHELP to 2600 (All networks)")).toBeNull();
    expect(toDial("8932-0179 F")).toBeNull();
    expect(toDial("loc. 2601, 3310")).toBeNull();
  });
});

describe("parsePhones", () => {
  test("splits lists, skips bare extensions and removes duplicates", () => {
    expect(splitNumbers("8682-9279; 8646-1634")).toEqual(["8682-9279", "8646-1634"]);
    const phones = parsePhones("loc. 2601, 3310; 8735-4936; 8735-4936");
    expect(phones).toEqual([{ display: "8735-4936", dial: "0287354936" }]);
  });

  test("keeps the written form next to the dialable form", () => {
    expect(parsePhones(["911"], { allowShort: true })).toEqual([{ display: "911", dial: "911" }]);
    expect(parsePhones(null)).toEqual([]);
  });
});

describe("cities", () => {
  test("spellings of one city share a key", () => {
    expect(cityKey("City of Las Piñas")).toBe(cityKey("las pinas city"));
    expect(cityKey("Quezon City")).toBe("quezon");
  });

  test("Metro Manila cities get one display name", () => {
    expect(canonicalCity("Las Pinas")).toBe("Las Piñas");
    expect(canonicalCity("City of Manila")).toBe("Manila");
    expect(canonicalCity("Quezon")).toBe("Quezon City");
    expect(isMetroManilaCity("Pateros")).toBe(true);
  });

  test("other places are kept as written", () => {
    expect(canonicalCity(" Iligan City ")).toBe("Iligan City");
    expect(canonicalCity("")).toBeNull();
    expect(isMetroManilaCity("Cebu City")).toBe(false);
  });
});
