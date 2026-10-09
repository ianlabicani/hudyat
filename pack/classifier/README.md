# Classifier experiment

This is an optional, disabled experiment. `score_fixture.json` and pipeline
unit tests contain toy vectors/weights, **not production models or accuracy
measurements**. Private corpus, sender fields, vectors and interim artifacts go
in ignored `pack/raw/classifier/` only.

Use Python 3.11+ and an isolated environment:

```sh
python3 -m venv /tmp/hudyat-classifier
/tmp/hudyat-classifier/bin/pip install -r pack/classifier/requirements.txt
/tmp/hudyat-classifier/bin/python -m unittest discover -s pack/classifier -p 'test_*.py'
python3 pack/classifier/prepare.py --ordinary pack/raw/inbox-texts.json --out pack/raw/classifier/corpus.json
```

The preparer groups normalized templates and near-duplicates (connected
components, seed 42); it does not claim semantic campaign review. Review every
ordinary group, merge same-campaign groups, retain the reviewed regression labels, then mark
`reviewed: true`. Add independently sourced **complete** scam examples with
`source: "official"`, `source_url`, `complete: true`, `scam: true`, five-label
annotations, a stable `group`, and a frozen `split` of `train`, `calibration` or
`final`. Reserve distinct campaigns for calibration and final. Keep duplicate
texts/variants together. Inspect `official_samples.json` for leads; its excerpts
are incomplete and is excluded. Do not move examples after inspecting scores.

Rows contain `id`, `text`, optional `sender`, `labels`, `source`, `split`, `group`,
`reviewed`, and `scam`. Synthetic rows must be training only. Existing 20 scams
use `source/split: "regression"`; they are a reused development benchmark, not
independent final data. The preparer excludes synthetic ordinary benchmark rows.
The currently available inbox file is 217 texts: 54 train/55 calibration/108 final
candidate rows. All real campaign reviews remain pending. If existing inbox texts
were used to select baseline settings, disclose that and obtain fresh ordinary
campaigns where needed for independence.

From the repo root, after review, prepare rule evidence and export inputs:

```sh
dart run tool/classifier_rules.dart pack/raw/classifier/corpus.json assets/pack/metro-manila.sqlite pack/raw/classifier/rules.json
```

The command also writes private `classifier-inputs.json`. It hashes a canonical
corpus and emits only ids/reason ids in `rules.json`. Keep **the same pack** for
final verdict comparisons and phone verification.

The user must initiate phone setup/export. The spike package is
`ph.hudyat.spike.model_test`. Copy `classifier-inputs.json` to its external files
folder, beside `models/`, then tap **6. Export classifier inputs**. That action
uses the installed EmbeddingGemma query task for every input and L2 normalization.
It hashes the actual installed TFLite and SentencePiece files. The baseline
uses document examples and query messages, threshold 0.56. Pull the generated
`classifier-vectors.json` into ignored storage. It contains ids/vectors/scores
and fingerprints, not text. Do not reuse the earlier document-task export for
classifier training. Do not install an APK, clear data or replace phone models
without the user's initiation.

Fit and calibrate, freeze, then evaluate in separate commands:

```sh
/tmp/hudyat-classifier/bin/python pack/classifier/train.py fit --corpus pack/raw/classifier/corpus.json --vectors pack/raw/classifier/classifier-vectors.json --out pack/raw/classifier/frozen.json
/tmp/hudyat-classifier/bin/python pack/classifier/train.py evaluate --corpus pack/raw/classifier/corpus.json --vectors pack/raw/classifier/classifier-vectors.json --artifact pack/raw/classifier/frozen.json --rules pack/raw/classifier/rules.json --out pack/raw/classifier/report.json
```

Fitting uses five L2 logistic regressions, C=1, balanced weights, seed 42,
liblinear, 2,000 iterations. Thresholds are 0.000001 above the highest ordinary calibration score, protecting against Python/Dart rounding differences. Fitting fails without real calibration scams, reviewed groups,
matching query metadata or two classes per label. Do not overwrite/refit a frozen
artifact after final testing. Publish only aggregate `report.json`, artifact and
input fingerprints; never publish the corpus/vectors. Label-level performance
and complete-checker verdicts are reported separately.

Evaluation needs >=20 final scams, >=100 final ordinary messages, >=13/20
regression detections, greater final scam detection than baseline, and zero
additional ordinary AI warnings **and** complete-checker warnings/escalations.
Any missing/failed evidence keeps the classifier disabled.

After a **user-initiated** pass with the candidate artifact, record a private
phone receipt containing `artifact_version`, `user_initiated: true`, `tested_at`
and `checks` with `offline`, `responsive`, `resumable`, `fallback` all true. Test
airplane-mode scoring; navigating/typing during catch-up; background/foreground
and Stop resumption; fallback without the model/with an incompatible artifact.
Record observations, device/build and timings in that receipt, rather than
pre-filling successful outcomes. Use the explicit debug phone trial below; do not attest a phone pass from laptop tests.

```sh
/tmp/hudyat-classifier/bin/python pack/classifier/train.py release --artifact pack/raw/classifier/frozen.json --report pack/raw/classifier/report.json --phone pack/raw/classifier/phone.json --out pack/data/suspicious-classifier.json
cd pack && bun run build && bun test
```

The optional pack entry is `meta.suspicious_classifier`. Its envelope holds an
exact JSON `payload`, its SHA-256 `version`, and version-bound `release` evidence.
The payload contains schema 1, `query-l2-v1`, dimension, model/tokenizer fingerprint
and the five linear heads. A missing entry keeps baseline phrasing active.
The builder refuses incomplete approval; runtime also requires compatible model
identity/dimension. All five reason rows must exist. `score_fixture.json` is shared
by Python and Dart tests for numerical agreement; it is never included in the bundled pack.

Current result: **no fitted artifact, no final accuracy result, disabled**.
Official complete campaigns and phone query exports/verification remain pending.

### Debug phone trial before approval

To test before approval without enabling an unapproved production pack, the app
has an **explicit debug-only** trial flag:

```sh
flutter build apk --debug --dart-define=HUDYAT_CLASSIFIER_PHONE_TEST=true
```

The user chooses installation and copies `frozen.json` to the product's external
files folder as `classifier-candidate.json`. The trial loads that local numerical
payload only if its hash, preprocessing, actual model fingerprint and dimension
match. The normal app UI exercises real checks and foreground catch-up; nothing
is downloaded or copied by the trial flag. Withhold the trial file or use an
incompatible candidate to check fallback, without replacing models or clearing
data. Record the exact `version` shown in `frozen.json` in the phone receipt.

Default builds do not read this file. Release builds ignore the flag entirely and
require an approved pack artifact. The debug trial is a user-initiated experiment,
not a distributable release or successful phone attestation.
