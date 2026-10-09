import { describe, expect, test } from "bun:test";
import { convertAgencies, convertLgu } from "../src/sources/directory";
import { convertCityHotlines, convertNationalHotlines } from "../src/sources/hotlines";
import { convertOverpass, placeCategory } from "../src/sources/osm";
import { convertServices } from "../src/sources/services";

describe("city hotlines", () => {
  const records = convertCityHotlines({
    hotlines: [
      {
        hotlineName: "Makati Police Department",
        hotlineNumber: "88871798",
        regionName: "National Capital Region (NCR)",
        province: "Metro Manila",
        city: "Makati",
        category: "police_hotlines",
        alternateNumbers: ["09297936525"],
      },
      {
        hotlineName: "Caloocan City Disaster Risk Reduction and Management Department",
        hotlineNumber: "0288825664",
        province: "Metro Manila",
        city: "Caloocan",
        category: "government_hotlines",
      },
      {
        hotlineName: "Las Piñas City Hall - Budget",
        hotlineNumber: "0285110779",
        province: "Metro Manila",
        city: "Las Pinas",
        category: "government_hotlines",
      },
      {
        hotlineName: "Las Piñas City Hall - Budget",
        hotlineNumber: "0285110779",
        province: "Metro Manila",
        city: "Las Pinas",
        category: "government_hotlines",
      },
    ],
  });

  test("maps source categories and keeps both numbers", () => {
    expect(records[0]).toMatchObject({ kind: "hotline", category: "police", city: "Makati" });
    expect(records[0].phones.map((p) => p.dial)).toEqual(["0288871798", "09297936525"]);
  });

  test("moves disaster offices out of the general government list", () => {
    expect(records[1].category).toBe("disaster");
    expect(records[2].category).toBe("government");
  });

  test("normalises city names and drops exact duplicates", () => {
    expect(records).toHaveLength(3);
    expect(records[2].city).toBe("Las Piñas");
  });
});

describe("national hotlines", () => {
  const records = convertNationalHotlines({
    emergencyHotlines: [{ name: "National Emergency Hotline", category: "Emergency", numbers: ["911"] }],
    securityHotlines: [
      { name: "Philippine National Police (PNP)", category: "Security", numbers: ["117 (Emergency Hotline)"] },
      { name: "Bureau of Fire Protection (BFP)", category: "Security", numbers: ["(02) 8426-0219"] },
    ],
    transportHotlines: [
      { name: "Metro Manila Development Authority (MMDA)", category: "Transport", numbers: ["136 (Hotline)"] },
    ],
    quick: [{ name: "National Emergency Hotline", category: "Emergency", numbers: ["911"] }],
  });
  const byName = (part: string) => records.find((r) => r.name.includes(part))!;

  test("has no city and merges repeated entries", () => {
    expect(records).toHaveLength(4);
    expect(byName("National Emergency")).toMatchObject({ category: "emergency", city: null, province: null });
    expect(byName("National Emergency").phones).toEqual([{ display: "911", dial: "911" }]);
  });

  test("files police and fire under their own categories", () => {
    expect(byName("Police").category).toBe("police");
    expect(byName("Fire").category).toBe("fire");
  });

  test("scopes the MMDA to Metro Manila", () => {
    expect(byName("MMDA")).toMatchObject({ province: "Metro Manila", city: null });
  });
});

describe("directory", () => {
  test("reads the three agency shapes", () => {
    const records = convertAgencies(
      [
        { office_name: "DEPARTMENT OF HEALTH", trunkline: "(632) 8651-7800", website: "www.doh.gov.ph" },
        { office: "OFFICE OF THE PRESIDENT", trunkline: "(632) 8249-8310" },
        { name: "Civil Service Commission (CSC)", office_type: "Constitutional Office", trunklines: ["8931-7939"] },
        { address: "no name here" },
      ],
      "Department",
    );
    expect(records.map((r) => r.name)).toEqual([
      "DEPARTMENT OF HEALTH",
      "OFFICE OF THE PRESIDENT",
      "Civil Service Commission (CSC)",
    ]);
    expect(records[0]).toMatchObject({ kind: "agency", category: "Department", url: "https://www.doh.gov.ph" });
    expect(records[0].phones[0].dial).toBe("0286517800");
    expect(records[2].category).toBe("Constitutional Office");
  });

  test("reads capital-region and provincial LGU files", () => {
    const ncr = convertLgu({
      region: "NATIONAL CAPITAL REGION",
      cities: [{ city: "Marikina", mayor: { name: "A", contact: "8682-9279; 8646-1634" }, vice_mayor: { name: "B" } }],
    });
    expect(ncr).toHaveLength(2);
    expect(ncr[0]).toMatchObject({ kind: "official", category: "Mayor", city: "Marikina", province: "Metro Manila" });
    expect(ncr[0].phones.map((p) => p.dial)).toEqual(["0286829279", "0286461634"]);

    const province = convertLgu({
      region: "REGION IV-A CALABARZON",
      provinces: [{ province: "Batangas", municipalities: [{ municipality: "Agoncillo", mayor: { name: "C" } }] }],
    });
    expect(province).toEqual([expect.objectContaining({ city: "Agoncillo", province: "Batangas", name: "C" })]);
  });
});

describe("services", () => {
  const agencies = convertAgencies(
    [{ office_name: "DEPARTMENT OF FOREIGN AFFAIRS", trunkline: "(632) 8834-4000", website: "www.dfa.gov.ph" }],
    "Department",
  );
  const records = convertServices(
    [
      { service: "Renew a passport", url: "https://passport.dfa.gov.ph/", category: { name: "Passport & Travel" } },
      { service: "Unknown host", url: "https://example.org/x", category: { name: "Health" } },
      { service: "Hidden", url: "https://example.org/y", published: false },
    ],
    agencies,
  );

  test("borrows the agency's numbers when the web host matches", () => {
    expect(records[0]).toMatchObject({ kind: "service", parent: "DEPARTMENT OF FOREIGN AFFAIRS" });
    expect(records[0].phones[0].dial).toBe("0288344000");
  });

  test("keeps unmatched services with the link only and skips unpublished ones", () => {
    expect(records).toHaveLength(2);
    expect(records[1]).toMatchObject({ parent: null, phones: [], url: "https://example.org/x" });
  });
});

describe("OpenStreetMap places", () => {
  test("only real shelters count as shelters", () => {
    expect(placeCategory({ amenity: "shelter", shelter_type: "public_transport" })).toBeNull();
    expect(placeCategory({ social_facility: "shelter", "social_facility:for": "child;woman" })).toBeNull();
    expect(placeCategory({ social_facility: "shelter", "social_facility:for": "displaced" })).toBe("shelter");
    expect(placeCategory({ emergency: "assembly_point" })).toBe("shelter");
    expect(placeCategory({ amenity: "doctors" })).toBe("clinic");
  });

  const records = convertOverpass({
    elements: [
      { type: "area", id: 1, tags: { name: "Manila" } },
      {
        type: "way",
        id: 87741356,
        center: { lat: 14.5824, lon: 120.9855 },
        tags: {
          amenity: "hospital",
          name: "Medical Center Manila",
          phone: "+63 2 8523 8131",
          "addr:housenumber": "850",
          "addr:street": "United Nations Avenue",
          "addr:city": "Manila",
        },
      },
      { type: "node", id: 2, lat: 14.6, lon: 120.98, tags: { amenity: "pharmacy" } },
      { type: "area", id: 3, tags: { name: "Las Piñas" } },
      { type: "node", id: 4, lat: 14.45, lon: 120.98, tags: { amenity: "police", name: "Police Station 1" } },
    ],
  });

  test("takes the city from the enclosing area and the centre of a way", () => {
    expect(records[0]).toMatchObject({
      kind: "place",
      category: "hospital",
      city: "Manila",
      lat: 14.5824,
      lon: 120.9855,
      address: "850 United Nations Avenue, Manila",
    });
    expect(records[0].phones[0].dial).toBe("0285238131");
    expect(records[1]).toMatchObject({ category: "police", city: "Las Piñas" });
  });

  test("drops places without a name", () => {
    expect(records).toHaveLength(2);
  });
});
