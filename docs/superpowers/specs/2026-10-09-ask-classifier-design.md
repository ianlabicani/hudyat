# Suspicious-request classifier: bounded experiment

Date: 2026-10-09. Status: implementation/tooling built; **disabled** pending real
query exports, independent evaluation and user-initiated phone verification.
The accepted [implementation plan](../plans/2026-10-09-stabilization-and-classifier.md)
supersedes the earlier proposal and its weaker 20-example-only gate.

## Definition

Classify **suspicious requests**, using the message's context. Do not classify
all literal requests. Genuine OTP notices, ordinary payment requests, routine
advisories, appointments and legitimate forms are negatives. Unknown identity
alone cannot make an ordinary request suspicious. An unfamiliar link alone
is insufficient training evidence; rules check domains separately.

| Label | Suspicious context |
|---|---|
| credentials | Requests to disclose secrets/codes, or sensitive details under a deceptive pretext |
| money | Upfront release fees, implausible investment transfers, impersonated payment demands |
| action | Deceptive verification links, disguised support downloads or related unsafe steps |
| pressure | Threats or coercive deadlines tied to a suspicious demand |
| bait | Implausible rewards, effortless earnings, unsolicited prize/benefit lures |

All labels form **one AI evidence group**, although each is rendered as a fixed
reason row. AI alone means caution. AI plus another existing reason group uses
the existing two-reason policy. Hard link findings remain scam. The pack supplies
identity/contact facts; the classifier cannot authenticate a sender.

## Data and evaluation discipline

- All 169 `ask_examples.json` rows and 42 existing `scam_examples.json` phrases
  have been reviewed against this definition. Ambiguous literal payments, routine
  fees, forms and advisories were relabelled negative. New examples retain review
  decisions; existing phrases now have `ask_labels`. Texts used by the baseline
  matcher remain unchanged. All 211 are synthetic training data only.
- The available ignored inbox file contains **217** ordinary texts. The earlier
  575-text claim is unsupported by that file. Candidate template/campaign groups
  were partitioned before fitting: 54 training, 55 calibration, 108 final rows.
  Near-duplicates remain together; semantic campaign and ordinary-label review
  must be completed before the training validator accepts the corpus.
- The existing 20-scam benchmark remains regression only. It was already used
  in development and cannot establish independent final performance. The
  preparer excludes its synthetic ordinary examples from final testing.
- `pack/classifier/official_samples.json` records official BSP, DSWD and DFPI
  excerpts and further official screenshot leads, with reserved campaign splits.
  Short excerpts and untranscribed images **do not count** toward final sample
  requirements. Obtain complete usable samples, label them and group their
  campaigns separately from training and calibration.
- Final testing needs at least **20 scams and 100 ordinary texts**. Never pad it
  with variants of a single campaign or synthetic examples. Never retune after
  final testing. Existing ordinary data was available during baseline development;
  disclose that history and collect fresh final ordinary campaigns if independence
  cannot be substantiated.

## Reproducible implementation

The explicitly invoked spike exporter uses `TaskType.retrievalQuery` for every
classifier input, including training examples. It emits L2-normalized vectors,
actual installed model/tokenizer SHA-256 fingerprints, dimension and corpus hash
into ignored storage. Baseline comparison alone retains document embeddings for
its existing examples and its 0.56 threshold.

`pack/classifier/train.py fit` fits five separate L2 logistic regressions using
C=1, balanced class weights, seed 42, liblinear and at most 2,000 iterations.
Convergence warnings fail fitting. Each threshold is a 0.000001 numerical margin above that label's highest ordinary calibration score.
Calibration requires distinct real scam campaigns too; final examples never
select weights or thresholds. Frozen artifact output is not overwritten.

A separate `evaluate` invocation checks the frozen corpus/model/vector hashes,
reports per-label confusion counts and full-checker verdicts, and compares the
baseline on exactly the same final inputs. A separate `release` invocation needs
an artifact-bound user-initiated phone receipt. Only validated approved artifacts
can be included by the pack builder. Runtime rejects malformed artifacts, missing
approval, preprocessing/model/tokenizer/dimension mismatches and falls back to
phrasing. A transient inference failure leaves AI completion pending.

## Runtime and gate

The classifier reuses one query embedding for all five heads. The optional pack
entry contains versioned weights, biases, thresholds, dimension, preprocessing
version, model fingerprint and release evidence. Artifact version is the SHA-256
of its exact payload. No private messages or vectors ship.

Foreground inbox checking finishes fast rules first, then checks pending clear
and caution messages one at a time. Automatic passes stop at 30 seconds before
starting another message, stop after the current message when backgrounded,
and resume on foreground entry/model readiness. An explicit scan can be stopped
and resumed. Rules completion and AI artifact version are tracked separately;
updating weights does not repeat unchanged rules. Kotlin scheduled checks stay
rules only.

Enable only when all gates pass: at least **13/20 regression scams**, better AI
detection than phrasing on final scams, no additional final ordinary warnings
(at label-group and complete-checker levels), and verified offline scoring,
foreground responsiveness, resumable catch-up and fallback on the phone.
Otherwise the baseline ships. First-aid source review and release alarm behaviour
are separate pending checks. Learned corrections, semantic service matching and
new emergency chooser screens remain deferred.
