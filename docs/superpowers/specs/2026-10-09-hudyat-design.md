# Hudyat: design spec

- **Date:** 2026-10-09
- **Event:** AppBuildersPH Hackathon 2026, theme "Local AI"
- **Builder:** solo
- **Submission deadline:** 2026-10-10, 10:00 AM, no extensions
- **Status:** awaiting review

## 1. Purpose

Hudyat ("signal") is an Android app that keeps emergency and government
contact information usable when a typhoon has taken the mobile signal.
The user types what happened in Taglish. On-device AI decides what they
need and shows a card: who to call, the nearest place to go, and a fixed
first-aid card when one applies.

It is the offline counterpart to Kuya J (chat.bettergov.ph), which needs
an internet connection. Hudyat is independent of BetterGov and claims no
affiliation.

### Required submission answer: why local?

> A typhoon takes the signal at the exact moment people need help. Hudyat
> keeps the data and the AI on a budget phone, so it still works, and
> nothing you type about your emergency leaves the device.

### Success criteria

1. With airplane mode on, a Taglish message produces a correct card on
   the Infinix X6876 (Dimensity 7400, 8 GB RAM).
2. The card appears without waiting for the chat model.
3. Every phone number, address and first-aid step shown is copied from
   the pack, never generated.
4. Submitted by 9:30 AM with a demo video, public repo and disclosures.

## 2. Scope

### In scope

| Area | What it covers |
|---|---|
| Emergency flow | Taglish message to a card with hotlines and nearest facilities |
| First aid | About 8 fixed cards for flood and typhoon cases |
| Everyday lookup | National agencies, LGU officials and contacts, hotlines, services list |
| Map | Offline map of Metro Manila with a line and distance to a place |
| Packs | One downloadable data file per area; Metro Manila is the first |

- Lookup data (hotlines, agencies, LGU contacts) is nationwide.
- Places and the map are Metro Manila only.
- Service entries are a title and a web link, so each is shown with its
  agency's contact details and marked "needs internet".

### Stretch, in build order

1. Road path drawn on the map (own shortest path over OpenStreetMap roads).
2. Button that hands off to Google Maps when installed.
3. Bills in Congress, search by title or topic only.
4. iPad Air M3 build.

### Out of scope

- Medical advice beyond the fixed cards.
- Budget, laws and statistics.
- Spoken turn-by-turn directions.
- Offline maps outside Metro Manila.
- Voice input.
- Accounts, sync, or any server of our own.

## 3. Local AI design

Two open models run on the phone. Neither is trained by us.

### 3.1 Decision step (embedding match)

- **Model:** EmbeddingGemma (about 300M, multilingual).
- **Job:** map the message to one intent from a fixed list.
- **Method:** each intent has about 10 example phrases in Taglish,
  Filipino and English. The message is embedded and compared by cosine
  similarity to the example vectors. The best intent wins if its score
  passes a threshold.
- **Below threshold:** treat the message as an everyday lookup and run a
  keyword search.
- **Output:** an intent id and a score. No free text.

Fixed intent list (final names set against the hotline categories in the
data):

| Intent | Card content |
|---|---|
| `medical_emergency` | Emergency hotline, nearest hospitals |
| `injury` | Same, plus a matched first-aid card |
| `fire` | Fire hotline for the city, nearest fire station |
| `flood_rescue` | Rescue and disaster hotlines for the city |
| `crime_police` | Police hotline, nearest police station |
| `need_medicine` | Nearest pharmacies |
| `need_clinic` | Nearest clinics |
| `shelter` | Nearest shelters (secondary layer, not complete) |
| `general_lookup` | Keyword search over agencies, officials, services |

First-aid card selection uses the same method: the message is compared
to example phrases for each card, and a card is attached only above a
threshold.

### 3.2 Wording step (chat model)

- **Model:** Gemma 3 1B.
- **Job:** write one or two Taglish sentences under the card.
- **Input:** the user message plus the card's facts as structured text.
- **Rules:** the prompt forbids adding numbers, names or steps that are
  not in the facts. The sentences are labelled as AI-written.
- **Failure handling:** if the model is missing, slow past a timeout, or
  errors, the sentences are simply not shown. The card is unaffected.

### 3.3 Hour-one test

A throwaway test app, kept outside the product code, run before any
product work.

- **Pass bar:** the chat model's reply starts within about 3 seconds, and
  8 of 10 written Taglish test messages map to the right intent.
- **Comparison:** the embedding match is tested against the chat model
  forced to choose from the list. The better one becomes the decision
  step.
- **If the phone fails:** the iPad Air M3 becomes the main device and the
  pitch becomes "a tablet at the barangay hall".
- **If the Flutter package fails but the phone is capable:** switch the
  model layer to native Kotlin.

## 4. Data

### 4.1 Sources

| Source | Used for | Licence |
|---|---|---|
| `bettergovph/bettergov` | Agencies, LGU officials and contacts, services | CC0 |
| `bettergovph/hotlines` | Emergency hotlines by city and category | None listed |
| OpenStreetMap | Hospitals, clinics, pharmacies, police, fire, shelters, roads, map tiles | ODbL, attribution required |
| DOH, Red Cross, WHO guidance | Text of first-aid cards | Cited per card |

Metro Manila counts in OpenStreetMap, checked 2026-10-09: 233 hospitals,
893 clinics and doctors, 1,598 pharmacies, 605 police and fire stations,
98 shelters and assembly points.

### 4.2 Pack format

One SQLite file per pack, built on the laptop by a script.

| Table | Contents |
|---|---|
| `meta` | Pack name, area, build date, sources, licences |
| `records` | One row per hotline, agency, official, service or place |
| `records_fts` | FTS5 keyword index over `records` |
| `intents` | Intent id, label, example phrases, linked record kinds |
| `first_aid_cards` | Title, steps, source name, source link, example phrases |

`records` columns: `id`, `kind`, `name`, `category`, `region`,
`province`, `city`, `phones`, `address`, `lat`, `lon`, `url`, `source`.

The map is a separate PMTiles file for Metro Manila.

### 4.3 Where embeddings are computed

Only intent and first-aid example phrases are embedded, a few hundred
vectors. They are computed on the phone at first launch and cached, so
they always match the on-device model. Records are found by intent,
location and keyword search, not by embeddings.

This differs from the earlier wording "precomputed embeddings in the
pack". It removes the need to run the identical model on the laptop.

## 5. App architecture

Flutter, Android first.

| Unit | Responsibility | Depends on |
|---|---|---|
| `PackStore` | Open the SQLite pack; keyword, kind and city queries | `sqlite3` |
| `ModelManager` | Check models are present, download on first run | `flutter_edge_ai` |
| `IntentMatcher` | Message to intent id and score; first-aid card match | `ModelManager` |
| `LocationService` | GPS fix, last known position, manual city choice | Platform location |
| `Resolver` | Intent plus location to a `Card` | `PackStore` |
| `Explainer` | Stream the Taglish sentences for a `Card` | `ModelManager` |
| `MapView` | Offline map, markers, line and distance | `maplibre_gl` |
| UI screens | Home, Card, Map, Setup | All above |

Backup model runner: `llamadart`.

### 5.1 Data flow

1. The user types a message on Home.
2. `IntentMatcher` returns an intent and score.
3. `LocationService` returns a position, or the manually chosen city.
4. `Resolver` builds the `Card`:
   - Hotlines for the city, falling back to province, then national.
   - Nearest facilities by straight-line distance.
   - A first-aid card if one matched.
5. The Card screen shows immediately.
6. `Explainer` streams its sentences under the card.
7. Tapping a place opens the Map screen with a line and distance.

### 5.2 Screens

- **Setup:** first run. Downloads models and the pack while online.
- **Home:** text box, quick buttons for the main emergencies, pack status.
- **Card:** hotlines with tap-to-call, places list, first-aid card, AI
  sentences, source credits.
- **Map:** offline map, user position, place markers, line and distance.

### 5.3 Error handling

| Situation | Behaviour |
|---|---|
| No GPS fix | Ask for city from a list; distances are hidden |
| Intent score too low | Run keyword search; show results as a list |
| No hotline for the city | Show province, then national numbers, labelled as such |
| Chat model slow or missing | Show the card without sentences |
| Embedding model missing | Quick buttons and keyword search still work |
| Map file missing | Places list with distances still works |
| Message outside all cards | Show the emergency hotline and "call this number" |

### 5.4 UI contract

The wireframes are the canvas "Hudyat Mobile Wireframes":
https://claude.ai/artifact/NqzVQkMr7zuMxSSJaLq26L. Build every screen
from the tokens, components and states below. If a screen needs something
that is not here, add it to the canvas and this section first.

**Tokens**

| Token | Value |
|---|---|
| Ground / surface / ink | `#F2F1EC` / `#FFFFFF` / `#1B1B19` |
| Muted text / rule | `#55534D` / `#CFCCC2` |
| Disabled fill / disabled text | `#CFCCC2` / `#3F3D39` |
| Call accent | `#B93A0B`, used only on Call buttons and the emergency link |
| Text face | Atkinson Hyperlegible, 400 and 700 |
| Data face | IBM Plex Mono, 400 and 500, for numbers, addresses, badges and footers |
| Text sizes | 28 screen title, 20 section heading, 16 body, 13 minimum |
| Shape | Radius 6; badges 3; pills fully round |
| Borders | 2px solid for primary surfaces, 1.5px solid for secondary |
| Dashed border | Optional, AI-written or locked content only |
| Touch targets | 44 minimum; Call 48; primary actions 52 to 60 |

Both fonts ship as asset files in the app, so nothing is fetched at run
time. Both are under the SIL Open Font License and belong in the
submission disclosures.

**Shared components**

| Component | Contents |
|---|---|
| `TopBar` | Back button with a semantic label, screen title |
| `HotlineRow` | Name, number, Call button |
| `PlaceRow` | Name, address, distance, chevron; opens the Map |
| `LevelBadge` | Outlined for the user's city; filled for a province or national fallback |
| `Notice` | The "!" box: a bold line and one sentence |
| `AiNote` | Dashed box labelled "AI-WRITTEN · MAY BE WRONG" |
| `PackFooter` | Hotline source, OpenStreetMap attribution, pack build date |
| Buttons | Primary (ink fill), secondary (outlined), call (accent fill) |

**States**

| Screen | State | Behaviour | Board |
|---|---|---|---|
| Setup | Pack not ready | Continue is locked | `Setup` (rule) |
| Setup | Pack ready, models still downloading | Continue is enabled | `Setup` |
| Home | Ready | Text box and quick buttons | `Main` |
| Home | Matching | "Find help" disabled, reads "Finding help…"; message stays visible | `HomeMatching` |
| Home | Embedding model missing | Notice; text box runs keyword search | `HomeNoModel` |
| Card | GPS fix | Hotlines, nearest places with distances | `Card`, `CardFirstAid` |
| Card | No GPS fix | "chosen manually"; distances hidden; "Try GPS again" | `CardNoGps`, `PickCity` |
| Card | No city hotline | Province or national numbers with a Notice and a filled badge | `HotlineProvince`, `HotlineFallback` |
| Card | Chat model missing or slow | No `AiNote`; nothing else changes | Rule only |
| Card | Map file missing | `PlaceRow` has no chevron and does not open the Map | Rule only |
| Map | Place has no phone number | No Call button; show "No phone number listed" | Rule only |
| Search | Results | Each row with a phone number has a Call button | `Results` |
| Search | No results | Emergency hotline and "Tap what you need instead" | `ResultsEmpty` |
| Search | Message outside all cards | Emergency hotline and "Call this number" | `NoMatch` |

**Copy rules**

- Labels are in English, with a short Filipino gloss on screen titles,
  section headings and main actions.
- Every number, address and first-aid step is pack data.
- Every card shows the pack build date and "Numbers may be out of date".
- The hotline level is always labelled.
- `AiNote` is always labelled, and never appears on a card that has a
  first-aid section.
- Distances always say "straight line".

## 6. Tools

| Purpose | Choice |
|---|---|
| App | Flutter |
| Models on device | `flutter_edge_ai`, backup `llamadart` |
| Storage | `sqlite3` with FTS5 |
| Map | `maplibre_gl` with PMTiles |
| Pack builder | Script on the laptop (Bun and TypeScript) |
| Models | Gemma 3 1B, EmbeddingGemma |

Models are about 0.5–1 GB, downloaded on first run. For the demo they
are copied to the phone over USB beforehand. The builder accepts the
Gemma terms on Hugging Face personally.

## 7. Testing

- **Pack builder:** unit tests for each source converter, plus checks
  that every record has a kind and a name, and that places have
  coordinates.
- **Resolver:** unit tests with a small fixture pack, covering the city,
  province and national fallback and nearest-place ordering.
- **IntentMatcher:** the 10 test messages from the hour-one test, kept as
  a regression list and extended to cover every intent.
- **On device:** a manual pass of every row in the error table with
  airplane mode on.

## 8. Night plan

1. Hour-one model test on the Infinix.
2. Offline map file test on the Infinix.
3. Pack builder and Metro Manila pack.
4. `PackStore`, `Resolver`, Card screen.
5. `IntentMatcher`, then `Explainer`.
6. Map screen.
7. First-aid cards.
8. Stretch items in order.

### Cut order if time runs short

iPad build, then bills, then the Google Maps handoff, then the road
path, then first-aid cards, then the map. Hotlines and nearest-facility
lists are cut last.

### Morning timeline

| Time | Milestone |
|---|---|
| 7:00 AM | Features stop |
| 8:00 AM | Demo video recorded |
| 9:00 AM | README and disclosures done |
| 9:30 AM | Submitted |

## 9. Disclosures for submission

- **Models:** Gemma 3 1B, EmbeddingGemma.
- **Frameworks and libraries:** Flutter, `flutter_edge_ai`, `sqlite3`,
  `maplibre_gl`.
- **Data:** BetterGov open data, OpenStreetMap.
- **Cloud use:** first-run download of models and packs only.
- **AI development tools:** Claude Code.
- **Existing code:** none; built during the hackathon.

## 10. Open risks

| Risk | Plan |
|---|---|
| Model too slow on the Infinix | Hour-one test; iPad fallback |
| Weak Tagalog in small models | Measured in hour one; fixed text carries the facts |
| PMTiles size and speed untested | Tested in hour two; fall back to list with distances |
| Hotlines repo has no licence | Credit the source; ask BetterGov; note in README |
| Name not checked against the trademark register or app stores | Builder checks before any public launch |
| Hotline numbers may be outdated | Show the pack build date on every card |
| First-aid text accuracy | Builder reviews each card against its cited source |
| GPS indoors at the venue | Manual city choice |

## 11. Parked

The demo script is deferred until the build works on the phone.
