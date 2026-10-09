# Where Hudyat's data comes from

Everything Hudyat shows or decides with comes from one of the sources
below. This page says what was taken from each, how it was changed, what
we wrote ourselves, and what is known to be incomplete.

- **Pack built:** 2026-10-09
- **Sources fetched:** 2026-10-09, by `bun run fetch` in `pack/`
- **How to rebuild:** see "Build and run" in the [README](../README.md)

The same source list is stored inside the pack (`meta.sources`), and the
app shows the source and the build date on every card.

## Summary

| What the app shows | Source | Collected or written | Licence |
|---|---|---|---|
| Agencies, officials, services, national hotlines | BetterGov | Collected | CC0-1.0 |
| City hotlines | BetterGov hotlines | Collected | None listed |
| Hospitals, clinics, pharmacies, police, fire, shelters | OpenStreetMap | Collected | ODbL |
| The offline map | Protomaps, from OpenStreetMap | Collected | ODbL data |
| Company contacts and websites | Each company's own website | Collected by hand | Facts, cited |
| First-aid steps | British Red Cross, MedlinePlus, WHO | Reworded by us | Cited per card |
| Request and scam example phrases | None | Written for this project | Own work |
| Gambling list and sender rules | The builder's own inbox | Written by hand | Own work |
| AI models | Google, via Hugging Face | Downloaded | Gemma terms |

## Collected data

### BetterGov (`bettergovph/bettergov`)

- **From:** `raw.githubusercontent.com/bettergovph/bettergov/main/src/data`
- **Files:** the directory files (executive, legislative, constitutional,
  diplomatic and others), the regional LGU files, the service lists,
  `philippines_hotlines.json` and `websites.json`.
- **Used for:** 295 agencies, 2,460 local officials, 194 government
  services, the national hotlines, and the official websites the message
  check compares links with.
- **Records in the pack:** 2,968.
- **Changes we made:** phone numbers are parsed into a dialable form
  (`pack/src/phones.ts`) and records are tagged with a city
  (`pack/src/cities.ts`). The converters are in `pack/src/sources/`.
- **Licence:** CC0-1.0 (public domain).

### BetterGov hotlines (`bettergovph/hotlines`)

- **From:** `raw.githubusercontent.com/bettergovph/hotlines/main/public/data/hotlines.json`
- **Used for:** hotlines by city and category.
- **Records in the pack:** 450.
- **Licence:** the repository lists none. We credit it as the source and
  have not been given explicit permission.

### OpenStreetMap

- **From:** the Overpass API (`overpass-api.de`), using the query in
  `pack/src/overpass.ql`.
- **Area:** the cities and municipality of the National Capital Region.
- **Tags taken:** `amenity` of hospital, clinic, doctors, pharmacy,
  police or fire_station; `emergency=assembly_point`;
  `social_facility=shelter`.
- **Records in the pack:** 3,206.

| Category | Count |
|---|---|
| Pharmacies | 1,548 |
| Clinics and doctors | 851 |
| Police stations | 326 |
| Fire stations | 225 |
| Hospitals | 224 |
| Shelters and assembly points | 32 |

- **Licence:** Open Database License. © OpenStreetMap contributors.

### The offline map

- **From:** the Protomaps daily build (`build.protomaps.com`), cut to the
  box 120.90–121.16 °E, 14.34–14.80 °N at a maximum zoom of 15.
- **Size:** about 53 MB. It is not stored in Git.
- **Licence:** the map data is OpenStreetMap's, under the ODbL.

### Company contacts

Seventeen commonly impersonated companies, each entered by hand from the
company's own contact page. The page is recorded in
`pack/data/companies.json` as `source_url`.

| Company | Source page |
|---|---|
| GCash | help.gcash.com/hc/en-us/p/contact-us |
| Maya | maya.ph/contact-us |
| BDO | bdo.com.ph/about-bdo/learn/help-and-support/contact-us |
| BPI | bpi.com.ph/contactus |
| Metrobank | metrobank.com.ph/contact-us |
| Landbank | landbank.com/customer-service |
| UnionBank | unionbankph.com/contact-us/directory |
| Globe | globe.com.ph/contact-us |
| Smart | smart.com.ph/Help/contact-support |
| DITO | dito.ph/faq |
| LBC | lbcexpress.com/contact-support |
| J&T Express | jtexpress.ph/contact-us |
| Meralco | company.meralco.com.ph/contact-us |
| Shopee | shopee.ph |
| Lazada | lazada.com.ph |
| Converge | convergeict.com/support/customer-support |
| PLDT | pldthome.com/contact |

### First-aid cards

Eight cards. The steps were reworded in Tagalog from the pages below and
are shown as fixed text. The AI chooses a card; it never writes a step.
Each card names its source in the app.

| Card | Source |
|---|---|
| Severe bleeding | British Red Cross, redcross.org.uk/first-aid/learn-first-aid/bleeding-heavily |
| Burn | British Red Cross, redcross.org.uk/first-aid/learn-first-aid/burns |
| Broken bone | British Red Cross, redcross.org.uk/first-aid/learn-first-aid/broken-bone |
| Drowning | British Red Cross, redcross.org.uk/first-aid/learn-first-aid/drowning |
| Head injury | British Red Cross, redcross.org.uk/first-aid/learn-first-aid/head-injury |
| Wound or nail puncture | MedlinePlus, medlineplus.gov/ency/article/000043.htm |
| Electric shock | MedlinePlus, medlineplus.gov/ency/article/000053.htm |
| Animal bite | World Health Organization, who.int/news-room/fact-sheets/detail/rabies |

The rewording has not been reviewed by a medical professional.

## Data we wrote

None of the files in this table was collected from real people.

| File in `pack/data/` | Contents | How it was made |
|---|---|---|
| `intents.json` | 9 needs with 10 example phrases each | Written for this project |
| `scam_examples.json` | 42 scam phrasings for the wording check | Written for this project |
| `ask_examples.json` | 169 labelled messages for the classifier that is switched off | Written by an AI assistant |
| `scam_reasons.json` | The fixed reason sentences | Written for this project |
| `gambling.json` | 15 gambling brands, 7 link words, 12 promo terms | By hand, from the builder's inbox |
| `sender_rules.json` | Aliases, blocked acronyms, link shorteners, neutral sites | By hand |
| `check_messages.json`, `test_messages.json` | Test messages | Written for this project |

The example phrases and messages are synthetic. They may not match real
scams, and they are never used to measure accuracy.

The first-aid cards are in `pack/data/first_aid.json`, reworded from the
sources listed above.

## Scam texts quoted from public reports

`pack/data/collected_scams.json` holds 29 scam texts copied word for word
from public pages, collected on 2026-10-09. Each one records the page it
came from.

| Kind of source | Texts |
|---|---|
| Personal blogs and comment threads | 22 |
| News organisations | 4 |
| A government agency or the named company | 3 |

- **Used for:** testing the classifier that is switched off. They are
  never used for training.
- **Not in the app.** The file is not part of the pack.
- **Weaker provenance for most.** A text reproduced on a blog cannot be
  confirmed as received, and the file says so.

How these files become the pack is described in [PACK.md](PACK.md).

## The builder's own inbox

The message rules were tuned against the builder's own SMS inbox.

- **What it was used for:** finding the broken-up link pattern, the
  gambling promos, the sender names real organisations text from, and
  replaying the rules as a test.
- **Where it is:** in the ignored `pack/raw/` folder on the builder's
  laptop. It is not in the repository and does not ship in the app.
- **What reached the repository:** only the rules and lists derived from
  it. No message text and no phone number.

## AI models

| Model | File | From |
|---|---|---|
| EmbeddingGemma | `embeddinggemma-300M_seq256_mixed-precision.tflite`, `sentencepiece.model` | huggingface.co/litert-community |
| Gemma 3 1B | `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm` | huggingface.co/litert-community |

Both are Google's open models under the Gemma terms. We did not train or
fine-tune them. The model files are not in the repository.

## What the app collects from the user

- **Typed requests and pasted messages:** processed on the phone and not
  stored, unless a checked message is flagged.
- **Incoming messages:** read only after the user turns on Automatic
  checking. Only flagged messages are kept, on the phone, in a list the
  user can clear.
- **Location:** used on the phone to sort places by distance. It is not
  sent anywhere.
- **Sent anywhere:** nothing. Hudyat has no server and no analytics.

## Known gaps

- **City hotlines have no stated licence.**
- **Shelters are far from complete:** 32 for all of Metro Manila.
- **Contacts go out of date.** Nothing has been checked by phone, and the
  pack reflects its sources on 2026-10-09.
- **OpenStreetMap is volunteer-made.** A place can be missing, closed or
  misplaced.
- **Company contacts were entered by hand** and can contain mistakes.
- **First-aid text is unreviewed** by a medical professional.
