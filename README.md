# Hudyat

An Android app for offline message checks and finding Philippine public-service
contacts. Metro Manila supplies the map and nearby places; the pack also includes
national agencies and hotlines. Calls, external sites and directions open the
phone's usual apps.

The current implementation and release checklist is
[the stabilization/classifier plan](docs/superpowers/plans/2026-10-09-stabilization-and-classifier.md).
See the [design spec](docs/superpowers/specs/2026-10-09-hudyat-design.md) and
[user stories](docs/superpowers/stories/2026-10-09-user-stories.md) for scope.

## Set up

Use Flutter with Dart 3.13.1 or later, an Android SDK/JDK compatible with this
project's Gradle wrapper, and Bun for pack tools. Keep the checked-in lockfiles.

```sh
flutter pub get
cd pack
bun run fetch
bun run build
bun run map
cd ..
flutter build apk
```

`fetch` downloads BetterGov directory/hotline data and OpenStreetMap places into
ignored `pack/raw/`; cached downloads are reused (`--force` refreshes them).
`build` combines those files with the curated lists in `pack/data/` into
`assets/pack/metro-manila.sqlite`. `map` requires the `pmtiles` command and internet
access; it cuts the Protomaps daily build to the Metro Manila bounding box at
maximum zoom 15. The approximately 53 MB PMTiles asset is ignored by Git and must
exist before a complete map build. Sources/licences and build dates are retained
in the pack. Inspect changed contacts and first-aid sources before a release.

## Models and sideloading

Rules and keyword search work without models. EmbeddingGemma adds intent and
wording matching; Gemma 3 adds optional labelled AI notes. Obtain the files after
personally accepting the model publishers' Gemma terms:

- `embeddinggemma-300M_seq256_mixed-precision.tflite`
- `sentencepiece.model`
- `Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm`

On a **user-chosen device/build**, copy them into
`/sdcard/Android/data/com.example.hudyat/files/models/`, then use Setup's file
check. Setup displays the actual folder. Sideloading avoids putting a private
Hugging Face token in an APK. The optional network-download build uses
`--dart-define=HUGGINGFACE_TOKEN=...`; do not commit or distribute private tokens.
Installing an APK, clearing data or replacing a device's models requires the
user's own initiation. This task does none of those actions.

## Supported flows

- Emergency buttons and typed help requests; city selection, keyword search,
  contact cards, phone calls and an offline local map.
- Paste a message, share text into Hudyat, or use Android text selection to check
  it. Link and sender rules run first. A loaded embedding model adds a wording
  check; labelled AI explanations are optional.
- Scan the SMS inbox by range, with an explicit wording switch and Stop action.
  Opening the app checks recent texts with fast rules, then processes pending
  wording checks asynchronously in foreground passes capped at 30 seconds.
  Clear and caution texts get AI checks; rules-scam texts keep their rule verdict.
  Backgrounding stops after the current message; foreground entry resumes.
- Flagged messages retain wording status and link counts. Legacy saved results
  explicitly say their wording-check status was not recorded.
- Automatic checking and the home-screen count widget use Kotlin rules only.
  Checks are scheduled about every 12 hours; Android may delay them. Opening
  Hudyat also checks recent texts. Debug builds retain the separate short interval.

The experimental five-label **suspicious-request** classifier is **disabled** in
the bundled pack. A missing, invalid, unapproved or model-incompatible artifact
uses the existing phrasing matcher. Several AI labels count as one evidence
group: AI alone is caution, while hard link findings and the existing two-group
rule retain their scam verdicts.

## Verify

```sh
flutter analyze
flutter test
cd pack && bun test
cd ../android && ./gradlew :app:testDebugUnitTest
```

If rules or source lists change, regenerate the shared Dart/Kotlin cases:

```sh
UPDATE_CASES=1 flutter test test/features/check/checker_cases_test.dart
```

Run that command from the project root, then rerun the Kotlin tests. The spike
exporter has a separate check: `cd spikes/model_test && flutter analyze`.
Classifier tooling, private data preparation, an explicit debug phone trial and release gates are documented in
[pack/classifier/README.md](pack/classifier/README.md).

## Measurements, limitations and disclosures

The existing phrasing threshold is 0.56. The earlier phone experiment reported
12/20 scam examples detected and a highest ordinary-message similarity of 0.546
on 25 ordinary examples. Those 20 scams are now **regression only**; this is not
an independent classifier result or a real-world accuracy estimate.

All 169 new training examples and 42 existing scam phrases are synthetic. Their
suspicious-request labels have been reviewed; ordinary OTP notices, routine
advisories and ambiguous payment requests are negatives. Synthetic data is never
eligible for classifier calibration or final testing. The available private
ordinary corpus contains 217 texts; prepared groups require campaign review.
The previous design note's 575-text claim is not supported by the available file.
Private texts and vectors remain in ignored storage and do not ship.

No production classifier has been fitted or measured: independent scam campaigns,
phone query vectors, a final set of at least 20 scams and 100 ordinary messages,
and a user-initiated phone pass remain pending. Laptop fixture tests establish
code behaviour and numerical agreement, not classifier effectiveness. Enabling
requires at least 13/20 regression detections, greater final scam detection than
phrasing, no extra final ordinary warnings, and verified offline operation,
responsiveness, resumption and fallback on the phone.

Hudyat cannot prove a message safe, authenticate a sender name, resolve shortened
links offline, delete/block SMS, or monitor Messenger automatically. Scheduled
checks can be delayed; the widget reports rules counts, not foreground AI counts.
Directory/map coverage and contact freshness depend on the pack. First-aid source
review, the first-aid matching threshold and release alarm behaviour still need
explicit content/device verification. Generated AI notes can be wrong; contacts,
reason rows and first-aid steps come from fixed pack data.

Feature stop: **October 10, 07:00**; submission target: **09:30**, Asia/Manila.
Learned corrections, semantic service matching and new emergency-picker screens
are deferred. No push or publication is part of this work.
