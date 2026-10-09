# Stabilize Hudyat and evaluate a suspicious-request classifier

Accepted 2026-10-09. This is the current implementation plan; older Claude
session plans are historical proposals, not the project's execution status.

## Decisions

- Stabilize saved results and alert wording first, then build a bounded experiment.
- Labels mean **suspicious requests**, not every literal request. Ordinary payment
  requests, genuine OTP notices and routine advisories remain negative examples.
- Five labels: credentials, money, action, pressure and bait. All labels together
  count as one AI reason. Existing hard-link and two-independent-reason verdicts stay.
- AI works for paste/share/selection and explicit scans. Catch-up runs its fast
  rules first, then short resumable AI passes while the app is foregrounded.
  Kotlin's scheduled check stays rules only.
- The classifier replaces phrasing only after independent evaluation and a
  user-initiated phone pass. Missing evidence means the existing matcher ships.

## Completed

- Saved results retain phrasing state and link count. Additive migration preserves
  old messages and marks their unrecorded AI status as unknown.
- Reopened results explain skipped, unavailable and unknown AI checks.
- Alert wording acknowledges Android delays, including the debug interval.

- Classifier interface, versioned optional pack artifact, validated weights and
  embedding identity, with baseline fallback.
- Shared query embeddings; five fixed reason rows count as one evidence group.
- Separate rules and AI completion; pending clear/caution texts; 30-second
  foreground passes, stop/resume, model-ready retries and correct summaries.
- Reviewed synthetic training examples and labels for existing scam examples.
- Deterministic duplicate/template-grouped ordinary-message split candidates;
  official-warning provenance records; query-mode vector exporter and private
  experiment files. Real-message label and campaign review remain pending.
- Training/evaluation tooling for five L2 logistic regressions, C=1, balanced
  classes, fixed seed and 2,000 iterations. Calibration-only thresholds, frozen
  artifacts and release gates are tested with fixtures; production fitting is pending.
- README, main spec, project guidance and synthetic-data disclosures.

## Pending release evidence

The shipped classifier is disabled. No production weights or measured classifier
accuracy are claimed. The baseline phrasing matcher remains active.

- Review real ordinary-message labels and campaign grouping; collect enough
  complete official scam messages for distinct calibration and final campaigns.

- Query vectors from the Infinix, with model/tokenizer hashes and L2 normalization.
- Separate final test with at least 20 independently sourced scam messages and
  100 ordinary messages, with no duplicate/campaign leakage. Synthetic examples
  are training only. Existing 20-scam benchmark is regression, not final testing.
- At least 13/20 regression scams detected; greater detection than phrasing on
  final scams; no additional warnings on final ordinary texts. Report per-label
  results separately from full-checker verdicts. Do not retune on final results.
- User-initiated phone verification of airplane-mode scoring, responsive foreground
  use, catch-up resumption and model fallback. Never install, clear app data or
  replace phone models autonomously.
- First-aid source review and release alarm behavior remain separate phone/content
  verification items, not proven by laptop tests.

## Deferred and rejected

- Deferred: learned corrections, semantic service matching, emergency chooser UI,
  government-advisory recognition and the existing stretch feature list.
- Rejected: treating every payment request as suspicious; calibrating and claiming
  final performance on the same examples; enabling unmeasured classifier weights;
  promising a maximum 12-hour alert delay.

## Verification and limits

- Final checks: analysis clean; 220 Flutter tests, 57 pack tests, eight classifier
  pipeline tests and two Kotlin parity tests pass. These cover migration, metadata,
  artifacts, numerical parity, verdict grouping, interruption, version invalidation
  and scan counts. Fixture tests do not establish real-world model accuracy.
- Classifier implementation budget: two hours after stabilization (started
  2026-10-09 22:04 Asia/Manila). Data collection and phone verification are separate.
- Features stop October 10 at 07:00, submission target 09:30 Asia/Manila.
- No push or publication in this task. Keep private inbox text and vectors ignored.
