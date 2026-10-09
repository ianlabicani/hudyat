# Hudyat

**Hudyat** ("signal") is an Android app that runs AI on a budget phone to
do two things with no internet: tell you who to call and where to go in an
emergency, and warn you when a message looks like a scam.

> Hudyat is the official information you can trust when you can't get
> online: who to call, where to go, and whether a message is real.

- **Event:** AppBuildersPH Hackathon 2026, theme "Local AI"
- **Team:** Ian Labicani (solo)
- **Test phone:** Infinix X6876 (Dimensity 7400, 8 GB RAM), Android 16
- **Demo video:** to be linked here before submission

## What it does

- **Find help.** Type what happened in Taglish, such as "Binabaha na dito,
  may matanda kami". The phone works out what you need and shows a card:
  the hotline for your city, the nearest hospitals, clinics, pharmacies,
  police or fire stations, and a fixed first-aid card when one applies.
- **Offline map.** Places are shown on a Metro Manila map stored on the
  phone, with the straight-line distance.
- **Check a message.** Paste a message, share it to Hudyat, or select the
  text and tap "Check with Hudyat". The result gives a verdict, the
  reasons, and the real contact details of whoever the message claims to
  be.
- **Automatic checking.** Once switched on, Hudyat checks incoming SMS
  and message notifications and alerts you about a likely scam.
- **Everyday lookup.** Search national agencies, local officials,
  hotlines and government services.

## Try it in two minutes

You need an Android phone running Android 11 or later.

1. **Install the app.** Use the APK on this repository's Releases page if
   one is attached. Otherwise build it with the steps under
   [Build and run](#build-and-run).
2. **Open Hudyat and continue past Setup.** The data pack and the map are
   inside the app, so there is nothing to download.
3. **Turn on airplane mode.** Everything below works without a
   connection.

### Check a message

On Home, tap **Check a message**, paste one of these, and tap **Check**.
These results come from the rules and the data on the phone, so they work
even before the AI models are installed.

| Paste this | Expected verdict | Why |
|---|---|---|
| `GCash: I-verify ang account mo sa https://gcash-verify.com` | Mukhang scam | The link imitates GCash but is not its website |
| `Mula sa DSWD: kunin ang ayuda sa dswd-ayuda.net ngayon` | Mukhang scam | The link imitates DSWD |
| `Para sa refund, pumunta sa csraftersales. com at pakitanggal ang space` | Mukhang scam | The link is broken up to get past filters |
| `Congrats! Claim your 100% welcome bonus, free spins at cashback sa https://lucky-casino88.com` | Mag-ingat | An online gambling promo |
| `Ma, nakauwi na ako. Anong ulam natin mamaya?` | Walang nakitang problema | Nothing found, with a note that this is not a guarantee |

A "Mukhang scam" result also shows the real contact details of the
organisation the message pretends to be, with a Call button.

You can also select text in any app and choose **Check with Hudyat**, or
share a message to Hudyat.

### Ask for help

On Home, type one of these under **What happened?** and tap **Find
help**. Pick a city if the phone has no GPS fix.

| Type this | Expected card |
|---|---|
| `Tumataas ang tubig, nasa bubong na kami ng pamilya ko` | Flood rescue, with the city's disaster hotline |
| `May sunog dito sa compound namin, mabilis kumalat` | Fire, with the fire hotline and nearest fire stations |
| `Nabagsakan ng kahoy ang paa ni tatay, namamaga at hindi maigalaw` | Injury, with nearest hospitals and a first-aid card when one matches |
| `Ubos na ang gamot sa high blood ni mama, saan may botika` | Medicine, with nearest pharmacies |

Tap a place on a card to see it on the offline map.

- **With the AI models installed**, Hudyat understands these sentences
  and shows "Understood: Flood rescue" as you type.
- **Without the models**, typing runs a keyword search instead. The quick
  buttons on Home open the most common cards directly.

### To see the AI parts

The two models are not inside the APK. Copy them to the phone as
described under [Models](#models), then tap **Check again** in Setup. The
[demo video](#hudyat) shows the app with both models running.

## Why the AI runs on the phone

> A typhoon takes the signal at the exact moment people need help. Hudyat
> keeps the data and the AI on a budget phone, so it still works, and
> nothing you type or receive, from your emergency to your private
> messages, leaves the device.

Two reasons, and they hold separately:

- **No signal.** The emergency flow has to work in airplane mode.
- **Privacy.** A scam checker reads your messages. That is only
  acceptable if they never leave the phone, even when you are online.

## What runs on the phone, and what needs internet

| Runs on the phone, offline | Needs internet |
|---|---|
| Both AI models | Opening a government service's website |
| Understanding a typed request | Directions in another maps app |
| Hotline, agency and official lookup | Downloading the models, if they are not copied over by cable |
| Nearest places and the offline map | Rebuilding the data pack on a laptop |
| First-aid cards | |
| Every message check, alert and saved result | |

Hudyat has no server of its own and calls no cloud AI service. Phone
calls use the mobile network, which often still works when data does not.

## How the AI is used

Two open models run on the phone. Neither was trained by us.

| Model | Job |
|---|---|
| EmbeddingGemma (about 300M) | Matches a typed request to one of a fixed list of needs, picks a first-aid card, and compares a message's wording with known scam wording |
| Gemma 3 1B | Writes one or two sentences under a card or result, labelled "AI-written" |

The design assumes a small model will sometimes be wrong:

- **The data is the knowledge.** Every phone number, address, website and
  first-aid step is copied from the data pack. The AI never writes them.
- **The AI is the interface.** It understands the question; it does not
  supply the answer.
- **Rules come first in the message check.** Links, claimed senders and
  gambling promos are checked against official data by rules. The wording
  check is a second signal and cannot mark a message "Mukhang scam" on
  its own.
- **Everything degrades.** If a model is missing or slow, the quick
  buttons, keyword search, rules and cards still work.

Verdicts are "Mukhang scam", "Mag-ingat" and "Walang nakitang problema".
Hudyat never says a message is safe.

## Automatic checking

- **As messages arrive.** With permission, Hudyat checks incoming SMS and
  notifications from Messages, Messenger, WhatsApp, Viber and Telegram.
  This path uses the rules only, so it does not load a model in the
  background.
- **Recovery.** A scheduled check of the SMS inbox runs about every 12
  hours, and again whenever Hudyat is opened.
- **Wording check.** The AI wording check runs while the app is open.
- **Alerts.** Only "Mukhang scam" raises a notification. A home screen
  widget shows counts and never shows a message or a sender.
- **Storage.** Only flagged messages are kept, on the phone, in a list
  you can clear.

Phones that restrict background apps can delay an arrival-time alert
until the recovery check runs or Hudyat is opened.

## What is in the data pack

Built on 2026-10-09.

| Kind | Count | Coverage |
|---|---|---|
| Hotlines | 469 | Nationwide |
| National agencies | 295 | Nationwide |
| Local officials | 2,460 | Nationwide |
| Government services | 194 | Nationwide |
| Places (hospitals, clinics, pharmacies, police, fire, shelters) | 3,206 | Metro Manila |
| Official senders for the message check | 263 | Agencies and companies |
| First-aid cards | 8 | Flood and typhoon cases |

## Disclosures

Where every piece of data comes from, what we wrote ourselves and what is
incomplete is set out in full in [docs/DATA.md](docs/DATA.md).

**Models**

- EmbeddingGemma: `embeddinggemma-300M_seq256_mixed-precision.tflite`
- Gemma 3 1B: `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`

**Technologies and frameworks**

- Flutter and Dart; Kotlin for the background message checks and widget
- `flutter_edge_ai`, `flutter_edge_ai_litertlm`,
  `flutter_edge_ai_embeddings` (on-device models)
- `sqlite3` with FTS5, `maplibre_gl` with PMTiles, `geolocator`,
  `url_launcher`, `path_provider`, `crypto`
- Bun and TypeScript for the data pack builder

**APIs and cloud services**

- None at run time.
- At build time only: GitHub for BetterGov data, the OpenStreetMap
  Overpass API for places, the Protomaps daily build for the base map,
  and Hugging Face for the model files.

**Data**

| Source | Used for | Licence |
|---|---|---|
| `bettergovph/bettergov` | Agencies, officials, services, national hotlines, official websites | CC0-1.0 |
| `bettergovph/hotlines` | City hotlines | None listed |
| OpenStreetMap contributors | Places and the map | ODbL |
| Protomaps | Base map tiles, cut to Metro Manila | Built from OpenStreetMap data |
| Company websites | Official company websites and hotlines | Facts, cited per company |
| British Red Cross, MedlinePlus, World Health Organization | First-aid cards, reworded in Tagalog | Cited per card |
| Own lists | Gambling brands, sender rules, scam wording | Own work |

**Synthetic data.** The 42 scam phrases used by the wording check and
the 169 labelled examples in `pack/data/ask_examples.json` were written
for this project, most of them by an AI assistant. They are not collected
from real victims and are never used as test data.

**Fonts.** Atkinson Hyperlegible and IBM Plex Mono, both under the SIL
Open Font License. The licence texts are in `assets/fonts/`.

**Existing code and assets.** The app was built during the hackathon.
The scheduled-alarm approach and the coding conventions follow the
builder's earlier apps, Barya and AfterYou.

**AI development tools.** Claude Code, Devin and Codex.

**Affiliation.** Hudyat is independent. It uses BetterGov's open data
with credit and is not endorsed by BetterGov or any agency.

## Limitations

- **It cannot prove a message is safe**, confirm a sender name, or see
  where a shortened link goes while offline.
- **It does not block or delete messages.**
- **Messenger, WhatsApp, Viber and Telegram** are seen only through their
  notifications, which can cut a long message short. Their message
  history cannot be read.
- **The map and places cover Metro Manila only.** Hotlines and the
  directory are nationwide.
- **Contacts can go out of date.** Every card shows the pack's build
  date.
- **AI-written sentences can be wrong.** They are labelled, and no card
  depends on them.
- **The wording check is modest.** In an early test on the phone it
  caught 12 of 20 synthetic scam examples at a threshold that flagged
  none of 25 ordinary messages. This is not a real-world accuracy figure.
- **A trained five-label classifier is included but switched off.** It
  has not been measured on independent real messages, so the app ships
  with the simpler wording check. The details are in
  [pack/classifier/README.md](pack/classifier/README.md).
- **First-aid cards** are reworded from the cited sources and are not a
  substitute for emergency care.

## Build and run

Requirements: Flutter with Dart 3.13.1 or later, an Android SDK and JDK
that match the project's Gradle wrapper, and Bun for the pack tools.

```sh
flutter pub get
cd pack
bun run fetch
bun run build
bun run map
cd ..
flutter build apk
```

- `fetch` downloads BetterGov data and OpenStreetMap places into the
  ignored `pack/raw/` folder. Cached downloads are reused; `--force`
  refreshes them.
- `build` combines those files with the lists in `pack/data/` into
  `assets/pack/metro-manila.sqlite`.
- `map` needs the `pmtiles` command and internet access. It cuts the
  Protomaps daily build to Metro Manila at a maximum zoom of 15. The
  result is about 53 MB and is not stored in Git, so run it before
  building the app.

### Models

Accept the Gemma terms on Hugging Face, download these three files, and
copy them to `/sdcard/Android/data/com.example.hudyat/files/models/` on
the phone:

- `embeddinggemma-300M_seq256_mixed-precision.tflite`
- `sentencepiece.model`
- `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`

Then open Setup in the app and tap "Check again". Setup shows the exact
folder. Rules and keyword search work before the models are in place.

A build can also download the models itself when given
`--dart-define=HUGGINGFACE_TOKEN=...`. Never commit or share a build that
contains a private token.

### Tests

```sh
flutter analyze
flutter test
cd pack && bun test
cd ../android && ./gradlew :app:testDebugUnitTest
```

The message rules exist in Dart and in Kotlin. If a rule or a source list
changes, regenerate the shared cases from the project root, then rerun
the Kotlin tests:

```sh
UPDATE_CASES=1 flutter test test/features/check/checker_cases_test.dart
```

## Licence

The code is under the [MIT License](LICENSE). The data, map, models and
fonts keep their own licences, listed under Disclosures.

## More detail

- [Design spec](docs/superpowers/specs/2026-10-09-hudyat-design.md)
- [User stories](docs/superpowers/stories/2026-10-09-user-stories.md)
- [Classifier tooling](pack/classifier/README.md)
