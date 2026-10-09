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

It also checks messages for scams on the phone. Fake relief and "ayuda"
texts follow disasters, and Hudyat already holds the official agencies,
numbers and websites to compare them with.

Product line:

> Hudyat is the official information you can trust when you can't get
> online: who to call, where to go, and whether a message is real.

It is the offline counterpart to Kuya J (chat.bettergov.ph), which needs
an internet connection. Hudyat is independent of BetterGov and claims no
affiliation.

### Required submission answer: why local?

> A typhoon takes the signal at the exact moment people need help. Hudyat
> keeps the data and the AI on a budget phone, so it still works, and
> nothing you type or receive, from your emergency to your private
> messages, leaves the device.

### Success criteria

1. With airplane mode on, a Taglish message produces a correct card on
   the Infinix X6876 (Dimensity 7400, 8 GB RAM).
2. The card appears without waiting for the chat model.
3. Every phone number, address and first-aid step shown is copied from
   the pack, never generated.
4. Submitted by 9:30 AM with a demo video, public repo and disclosures.
5. With airplane mode on, a scam message arriving on the Infinix raises
   a Hudyat alert with reasons taken from pack data.
6. No message text leaves the phone, and only flagged messages are kept.

## 2. Scope

### In scope

| Area | What it covers |
|---|---|
| Emergency flow | Taglish message to a card with hotlines and nearest facilities |
| First aid | About 8 fixed cards for flood and typhoon cases |
| Everyday lookup | National agencies, LGU officials and contacts, hotlines, services list |
| Map | Offline map of Metro Manila with a line and distance to a place |
| Packs | One downloadable data file per area; Metro Manila is the first |
| Message check | Scam check by paste, share or text selection, plus automatic checking of incoming messages with alerts |

- Lookup data (hotlines, agencies, LGU contacts) is nationwide.
- Places and the map are Metro Manila only.
- Service entries are a title and a web link, so each is shown with its
  agency's contact details and marked "needs internet".

### Stretch, in build order

1. Button that hands off to Google Maps when installed.
2. Rescue report: the chat model turns the user's message into a short
   structured report (who, where with coordinates, how many people,
   injuries, what is needed) that the user edits and sends by SMS.
3. Road path drawn on the map (own shortest path over OpenStreetMap roads).
4. Bills in Congress, search by title or topic only.
5. iPad Air M3 build, without automatic message checking.

### Out of scope

- Automatic message checking on iOS, which the platform does not allow.
- Telling the user a message is safe or legitimate.
- Blocking, deleting or replying to messages.
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

### 3.4 Message check (scam)

One checker serves both the manual and the automatic path.

**Stage 1: instant check.** Runs on every message, without the chat
model.

| Check | Method | Needs a model |
|---|---|---|
| Links | Each link's domain is compared with the official domains in the pack | No |
| Claimed sender | Agency or company names in the text are matched to the pack; the sender is checked for being an ordinary mobile number | No |
| Phrasing | The text is embedded and compared with scam example phrases | EmbeddingGemma |

- **Output:** a verdict and a list of reason ids. No free text.
- **Verdicts:** "Mukhang scam", "Mag-ingat", "Walang nakitang problema".
  The app never says a message is safe or legitimate.
- **Reasons:** fixed text per reason id, filled with pack data, e.g.
  "Ang link ay hindi opisyal na website ng GCash" or "Nagpapakilalang
  DSWD pero galing sa ordinaryong mobile number".

**Link rules.**

- A `.gov.ph` domain is always treated as official.
- **Look-alike:** the domain contains an organisation's name or acronym
  (`gcash-verify.com`, `dswd-ayuda.net`) but is not that organisation's
  listed domain or a subdomain of it.
- **Not theirs:** the text names an organisation and has a link that is
  not on that organisation's domain.
- **Shortener:** the link goes through `bit.ly` or a similar service, so
  the destination cannot be seen.
- A link to an ordinary site that is not in the pack gives no reason
  when the text names no organisation.

**Sender rules.**

- Real messages from agencies, banks and e-wallets arrive under a sender
  name, not the landline in the pack, so the sending number is never
  compared with the official number.
- The one sender reason: the text names a listed organisation and the
  sender is an ordinary mobile number (`09…` or `+639…`).
- A sender name such as "GCash" gives no reason either way, because
  sender names can be faked.
- With no sender given (paste without the optional field, share, text
  selection) the sender check is skipped and the result says so.

**Name matching.** Full name or a listed alias, as a whole word,
ignoring case. Acronyms need three or more letters. Acronyms that are
also ordinary words are left out. Smart, Globe, Maya and DITO count only
when capitalised or next to a word such as "account", "load" or "SIM".

**From reasons to a verdict.**

| Finding | Verdict |
|---|---|
| A look-alike link | Mukhang scam |
| An organisation is named and a link is not theirs | Mukhang scam |
| Any two different reasons | Mukhang scam |
| Exactly one of: organisation named from a mobile number, phrasing match, shortener link | Mag-ingat |
| Nothing found | Walang nakitang problema |

The phrasing check alone never gives "Mukhang scam".

**Phrasing threshold.** Set from vectors exported on the Infinix for
about 40 scam phrases and 25 ordinary messages (real one-time codes,
delivery notices, family texts, promos). It is the lowest score at which
no ordinary message is flagged. The check stays in as a second signal
even if it then catches under half of the scam phrases.

**Preparation.** Scam phrases are embedded after the intent phrases, as
a separate step, so "Find help" is not delayed. Until they are ready the
checker runs the link and sender checks, and the result says the
phrasing check is not ready.

**If the embedding model cannot run in the background:** the automatic
path uses the link and sender checks only, and the phrasing check runs
when the user opens the message.

**Stage 2: explanation.** Runs only when the user opens a result.

- **Model:** Gemma 3 1B.
- **Job:** one or two Tagalog sentences explaining the verdict, written
  from the reasons and the pack facts.
- **Rules and failure handling:** as in 3.2. The verdict and reasons do
  not depend on it.
- **Cut rule:** the prompt gets 30 minutes of work. If the Tagalog is
  still poor on the phone, results show no `AiNote`; the fixed reasons
  already explain the verdict.

**Manual path.** Three ways in:

1. Paste into the Check screen.
2. The Android share sheet.
3. "Check with Hudyat" in the text selection menu.

**Automatic path.**

- **Mechanism:** Android notification access.
- **Apps watched:** SMS apps, Messenger, Viber, WhatsApp and Telegram.
  Every other notification is ignored.
- **Opt-in:** off by default. A setup screen explains what is read and
  that nothing leaves the phone before the user turns it on.
- **Alerts:** Hudyat posts its own notification only for "Mukhang scam".
  It is a standard Android notification: the title names the sender, the
  body is the first reason, and one action, "Tingnan", opens the result.
  "Mag-ingat" results are listed quietly in the app.
- **Storage:** only "Mukhang scam" and "Mag-ingat" messages are kept, on
  the phone, in a list the user can clear. This holds for the manual
  path too, with no Save button. Everything else is discarded after the
  check.
- **Limit:** long messages can be cut short in a notification, so the
  check sees only what the notification shows.

**What a result shows:** the verdict, the reasons, the real contact
details of whoever the message claims to be with a Call button, and the
explanation in an `AiNote`.

**Before building the automatic path:** a 20-minute throwaway test of
notification access on the Infinix, since Android adds an "Allow
restricted settings" step for sideloaded apps. If the test fails, the
automatic path is dropped: Watcher setup and the alert are hidden, and
the Flagged list holds manually checked messages only.

## 4. Data

### 4.1 Sources

| Source | Used for | Licence |
|---|---|---|
| `bettergovph/bettergov` | Agencies, LGU officials and contacts, services | CC0 |
| `bettergovph/hotlines` | Emergency hotlines by city and category | None listed |
| OpenStreetMap | Hospitals, clinics, pharmacies, police, fire, shelters, roads, map tiles | ODbL, attribution required |
| DOH, Red Cross, WHO guidance | Text of first-aid cards | Cited per card |
| `bettergovph/bettergov` websites list | Official websites, emails and contacts of 723 agencies, for the message check | CC0 |
| Hand-made company list | About 15 commonly impersonated companies (e-wallets, banks, couriers, telcos) with official websites, each verified when added | Own work |
| Hand-written scam examples | About 40 Taglish scam phrasings (locked e-wallet, fake ayuda, parcel fees, job offers, loans, prizes) | Own work |

BetterGov's own ScamCheck is an online service calling a cloud-hosted
model, so nothing from it is reused.

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
| `official_senders` | Name, aliases, kind (agency or company), official domains, contact numbers to show, source URL |
| `scam_examples` | Example phrasing, scam type |
| `scam_reasons` | Reason id, fixed Tagalog text with placeholders |

Flagged messages are stored in a separate SQLite file in app storage,
never in the pack.

`records` columns: `id`, `kind`, `name`, `category`, `region`,
`province`, `city`, `phones`, `address`, `lat`, `lon`, `url`, `source`.

The map is a separate PMTiles file for Metro Manila.

### 4.3 Where embeddings are computed

Only intent, first-aid and scam example phrases are embedded, a few
hundred vectors. They are computed on the phone at first launch and cached, so
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
| `MessageChecker` | Text and optional sender to a verdict and reason ids | `PackStore`, `IntentMatcher`'s embedder |
| `ShareEntry` | Receive text from the share sheet and the selection menu | Android intents |
| `MessageWatcher` | Read notifications from watched apps, run the checker, post alerts | Notification access |
| `FlaggedStore` | Keep and clear flagged messages | `sqlite3` |
| UI screens | Home, Card, Map, Setup, Check, Result, Flagged list, Watcher setup | All above |

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

Message check flow:

1. Text arrives from paste, `ShareEntry`, or `MessageWatcher`.
2. `MessageChecker` returns a verdict and reason ids.
3. Manual path: the Result screen shows at once.
4. Automatic path: "Mukhang scam" posts an alert and is saved;
   "Mag-ingat" is saved quietly; anything else is discarded.
5. Opening a result runs `Explainer` for the Tagalog explanation.

### 5.2 Screens

- **Setup:** first run. Downloads models and the pack while online.
- **Home:** text box, quick buttons for the main emergencies, pack status.
- **Card:** hotlines with tap-to-call, places list, first-aid card, AI
  sentences, source credits.
- **Map:** offline map, user position, place markers, line and distance.
- **Check:** paste box and a Check button.
- **Result:** verdict, reasons, official contact with Call, AI
  explanation.
- **Flagged list:** saved "Mukhang scam" and "Mag-ingat" messages, with
  Clear all.
- **Watcher setup:** what is read, what is kept, and the switch that
  opens Android's notification access setting.

These screens are on the wireframe canvas in the "Message check" row:
`Check`, `CheckResultScam`, `CheckResultCaution`, `CheckResultClear`,
`ScamAlert`, `Flagged` and `WatcherSetup`. Home has a "Check a message"
button beside "Look up". The share sheet and the text selection menu are
Android's own UI and have no board.

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
| Notification access not granted | Manual check still works; Watcher setup shows how to grant it |
| Embedding model unavailable in the background | Link and sender checks only; phrasing check on open |
| Message cut short in the notification | Check what is visible; the result says the message may be incomplete |
| No official sender matched | Verdict from links and phrasing only; no contact shown |
| Shared content has no text | Check screen opens empty with a short notice |

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
| `VerdictBadge` | Ink fill for "Mukhang scam"; outlined for "Mag-ingat"; dashed and muted for "Walang nakitang problema". No new colour |
| `ReasonRow` | One fixed-text reason and the pack fact behind it |
| `MessageQuote` | The checked message in the data face, with sender and source app; says so when it may be cut short |
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
| Check | Empty | Paste box, optional sender, Check button; links to Flagged and Watcher setup | `Check` |
| Check | Checking | Check is disabled and reads "Checking…"; the message stays visible | Rule only |
| Check | Opened from share or selection | Paste box is prefilled; the check runs at once | Rule only |
| Check | Shared content has no text | Empty paste box with a Notice | Rule only |
| Result | Mukhang scam | Filled verdict, reasons, real contact with Call, `AiNote` | `CheckResultScam` |
| Result | Mag-ingat | Outlined verdict, reasons, real contact with Call, `AiNote` | `CheckResultCaution` |
| Result | Walang nakitang problema | Dashed verdict, "Hindi ito garantiya" Notice, list of checks run | `CheckResultClear` |
| Result | No official sender matched | No contact section; one line says why | `CheckResultClear` |
| Result | No sender given | The Sender row reads "Not given / Hindi ibinigay" | Rule only |
| Result | Scam phrases not ready | The Phrasing row reads "Not ready yet"; the verdict comes from links and sender | Rule only |
| Result | Message read from a notification | `MessageQuote` says it may be cut short | `CheckResultCaution` |
| Result | Chat model missing or slow | No `AiNote`; nothing else changes | Rule only |
| Alert | Mukhang scam on an incoming message | Standard Android notification: sender in the title, first reason in the body, one "Tingnan" action that opens the result | `ScamAlert` |
| Flagged | Has messages | Grouped by verdict; each row opens its result; Clear all | `Flagged` |
| Flagged | Empty | "No flagged messages" and a link to Watcher setup | Rule only |
| Watcher setup | Off, access not granted | What is read, kept and sent; Notice about Android settings; Turn on | `WatcherSetup` |
| Watcher setup | On | Badge reads ON; the button reads "Turn off"; no Notice | Rule only |
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
- Verdict words are fixed Tagalog: "Mukhang scam", "Mag-ingat", "Walang
  nakitang problema". The app never says "safe" or "legit".
- A "Walang nakitang problema" result always carries the "Hindi ito
  garantiya" Notice.
- Reasons and the advice under a verdict are fixed text filled with pack
  data. Only the `AiNote` is generated.
- The call accent is not used for verdicts.

## 6. Tools

| Purpose | Choice |
|---|---|
| App | Flutter |
| Models on device | `flutter_edge_ai`, backup `llamadart` |
| Storage | `sqlite3` with FTS5 |
| Map | `maplibre_gl` with PMTiles |
| Pack builder | Script on the laptop (Bun and TypeScript) |
| Models | Gemma 3 1B, EmbeddingGemma |
| Reading notifications | `notification_listener_service` |
| Posting alerts | `flutter_local_notifications` |
| Share sheet and selection menu | `receive_sharing_intent`, plus an Android `PROCESS_TEXT` intent filter |

The three message-check packages are untested on the Infinix and on
Android 16.

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
- **MessageChecker:** unit tests with a fixture pack and a written list
  of scam and ordinary messages, covering each check, each verdict and
  the no-model fallback. Ordinary messages from real agencies must not
  come out as "Mukhang scam".
- **Automatic path on device:** send test messages to the Infinix by SMS
  and Messenger with airplane mode off for delivery, then confirm the
  check itself makes no network request.

## 8. Night plan

Done or in progress as of 5:10 PM on 2026-10-09: the hour-one test app,
the pack builder and the Metro Manila pack.

Build order from here:

1. Finish the emergency card flow (`PackStore`, `Resolver`, Card screen,
   `IntentMatcher`, `Explainer`).
2. Scam checker with paste, share and select.
3. Automatic reading with alerts, after the notification access test.
4. Map screen.
5. First-aid cards.
6. Google Maps handoff.
7. Rescue report.
8. Road path.
9. Bills search.
10. iPad build.

### If time runs short

Everything above stays on the list. Cuts are taken from the bottom of
the build order, and the builder decides when. There is no fixed
checkpoint.

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
  `maplibre_gl`, `notification_listener_service`,
  `flutter_local_notifications`, `receive_sharing_intent`.
- **Data:** BetterGov open data, OpenStreetMap, own lists of company
  websites and scam examples.
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
| Notification access blocked or awkward on Android 16 | 20-minute test first; if it fails the automatic path is dropped and the manual check stands alone |
| Embedding model killed in the background | Link and sender checks need no model |
| A real message flagged as a scam | Tests include real agency messages; verdict wording stays cautious |
| A scam not flagged | The app never says "safe"; say so in the pitch |
| Scope is larger than one night | Fixed build order; cuts come from the bottom |

## 11. Parked

The demo script is deferred until the build works on the phone.
