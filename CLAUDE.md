# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Hudyat ("signal") is a Flutter app, Android first, for the AppBuildersPH Hackathon 2026 ("Local AI" theme). The user types what happened in Taglish; on-device AI picks an intent and the app shows a card with hotlines, nearest facilities and a fixed first-aid card. It must work in airplane mode.

The design spec is `docs/superpowers/specs/2026-10-09-hudyat-design.md`. Read it before any product work: it holds the scope, the cut order and the submission deadline (2026-10-10, 10:00 AM).

## Current state

The repo is still the unmodified `flutter create` scaffold: `lib/main.dart` is the counter demo and `test/widget_test.dart` tests that counter. Nothing in the spec is implemented yet, and none of the planned packages (`flutter_edge_ai`, `sqlite3`, `maplibre_gl`, `llamadart`) are in `pubspec.yaml`. Everything under "Planned architecture" below describes the target, not existing code.

## Commands

```sh
flutter pub get
flutter run                                   # on the attached device
flutter analyze                               # lints: flutter_lints via analysis_options.yaml
flutter test                                  # all tests
flutter test test/widget_test.dart            # one file
flutter test --plain-name "Counter increments smoke test"   # one test by name
flutter build apk
```

Dart SDK constraint is `^3.13.1` (Flutter 3.47). The code uses dot shorthands (e.g. `colorScheme: .fromSeed(...)`), so keep that style.

`analysis_options.yaml` adds seven rules on top of `flutter_lints`: `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, `prefer_final_locals`, `avoid_unnecessary_containers`, `sized_box_for_whitespace`, `use_colored_box` and `use_decorated_box`. It also excludes the platform folders and `build/` from analysis.

## Dart MCP server

`.mcp.json` registers the Dart and Flutter MCP server (`dart mcp-server`, shipped with the SDK). When it is connected, prefer its tools over shelling out: analysis, `dart fix`, formatting, running tests, pub.dev search, and for a running app hot reload, runtime errors, logs and the widget inspector.

## Working rules

These are carried over from the builder's other Flutter apps (`barya`'s `AGENTS.md` and `afteryou-mobile`'s `CLAUDE.md`), keeping only what applies here.

Device safety. The demo phone holds the models (0.5–1 GB, copied over USB) and the pack, and re-copying them costs time the deadline does not have.

- Do not run `flutter install`, `flutter run --uninstall-first`, `adb uninstall`, `adb shell pm clear`, or delete the app's data on the device.
- Do not change the application ID or signing settings to get a build passing.
- Building and installing on the device is user-initiated. `flutter pub get`, analyze, tests and `flutter build` are fine without asking.
- Use `flutter clean` only for a stale-build problem, and never together with a reinstall.
- No `git reset --hard`, `git clean`, or discarding uncommitted work.

Code layout.

- Group code by feature, each with `models/`, `services/`, `state/`, `screens/` and `widgets/` as needed; cross-cutting code goes in a shared core folder.
- Screen files own state, lifecycle, loading and navigation. Display sections go in widgets, and pack queries stay behind `PackStore`.
- Keep files cohesive, roughly 150–400 lines. Fixed datasets are an exception.
- Do not add a UI or state-management dependency for something Flutter's own primitives can do.
- Do not edit generated plugin registrants.

UI.

- Show loading, empty, error and disabled states explicitly.
- Keep earlier content visible while something refreshes or fails, rather than blanking the screen.
- Label primary actions in words. Icon-only controls get a tooltip and a semantic label.
- Layouts must hold up with large text on a narrow screen, and touch targets stay at minimum size.

Tests and checks.

- Database tests use an in-memory SQLite database or a small fixture pack, never the real pack on a device.
- Do not weaken or delete a test to make a change pass.
- Treat analyzer warnings and infos as failures. Format only the Dart files you touched.
- Dart tests do not prove on-device behaviour (models, GPS, offline map, tap-to-call). Say so when device verification is still needed.

Handoff. Summarise the behaviour changed, the tests run, and what still needs checking on the phone.

## Planned architecture

Two open models run on the phone, with separate jobs:

- **Decision step:** EmbeddingGemma embeds the message and compares it by cosine similarity to about 10 example phrases per intent. The output is an intent id and a score, never free text. Below the threshold, the message is treated as an everyday lookup and goes to keyword search.
- **Wording step:** Gemma 3 1B writes one or two Taglish sentences under the card from the card's facts. It is optional: if it is missing, slow or errors, the sentences are not shown and the card is unaffected.

Units and their dependencies:

| Unit | Responsibility | Depends on |
|---|---|---|
| `PackStore` | Open the SQLite pack; keyword, kind and city queries | `sqlite3` |
| `ModelManager` | Check models are present, download on first run | `flutter_edge_ai` |
| `IntentMatcher` | Message to intent id and score; first-aid card match | `ModelManager` |
| `LocationService` | GPS fix, last known position, manual city choice | Platform location |
| `Resolver` | Intent plus location to a `Card` | `PackStore` |
| `Explainer` | Stream the Taglish sentences for a `Card` | `ModelManager` |
| `MapView` | Offline map, markers, line and distance | `maplibre_gl` |

Flow: Home message → `IntentMatcher` → `LocationService` → `Resolver` builds the `Card` → Card screen shows immediately → `Explainer` streams sentences under it → tapping a place opens Map.

Data lives in a pack: one SQLite file per area (tables `meta`, `records`, `records_fts` (FTS5), `intents`, `first_aid_cards`), built on the laptop by a Bun and TypeScript script. The map is a separate PMTiles file for Metro Manila. Embeddings for intent and first-aid example phrases are computed on the phone at first launch and cached, not shipped in the pack.

## Rules the design depends on

- Every phone number, address and first-aid step shown comes from the pack. Never have a model generate them, and keep the chat prompt forbidding numbers, names or steps that are not in the card's facts.
- The card never waits for the chat model. AI-written sentences are labelled as such.
- Each missing piece degrades instead of blocking. The spec's error table (section 5.3) lists the behaviour per case, e.g. no GPS fix asks for a city and hides distances; a missing embedding model leaves quick buttons and keyword search working.
- Hotline lookup falls back from city to province to national, and the card labels which level it is showing.
- Show the pack build date on every card, since hotline numbers may be outdated.
- No server of our own, no accounts, no sync. The only network use is the first-run download of models and packs.
- OpenStreetMap data is ODbL and needs attribution; first-aid cards cite their source per card.
- The hour-one model test app stays outside the product code.
