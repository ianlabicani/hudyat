# Phone pass, October 10

The user-initiated device checks the release gate requires. Run on the Infinix
with the sideloaded models and the shipped pack. Nothing here installs,
clears app data, or replaces models. Tick each line and note the result;
"expected" states what must happen for the gate to pass.

## A. Classifier gate checks (only if the classifier is being enabled)

1. **Offline scoring.** Airplane mode on. Paste a scam text from the 20-scam
   regression set into Check.
   - Expected: a verdict with reason rows appears; any AI label rows render;
     no network error and no hang.
2. **Foreground responsiveness.** Trigger a scan or reopen the app with
   pending AI checks. While the catch-up pass runs, scroll Home and open a
   card.
   - Expected: the UI stays responsive; the pass works one message at a time
     and never blocks a tap for more than a beat.
3. **Resumable catch-up.** Mid catch-up, background the app (home button).
   Reopen it.
   - Expected: the pass stopped after the message it was on, and resumes on
     reopen or on an explicit scan. The scan summary counts resumed AI work
     once, not twice.
4. **Model fallback.** With the embedding model unavailable (do NOT delete
   models; use the app's own path for this, e.g. before models finish
   loading), check a message.
   - Expected: rules still run; the result shows the AI check as skipped or
     unavailable, in words; no crash. The phrasing matcher behaves as before
     when the classifier artifact is absent.
5. **Vector export sanity** (pre-gate data work, not a gate check): export
   query-task vectors on the phone and confirm the model/tokenizer
   fingerprint and L2 normalization match what training used.

## B. Stabilization checks

6. **Reopened flagged results.** Open an old flagged result saved before the
   migration.
   - Expected: the message is intact and the wording row says the AI check
     was not recorded ("unknown"), not that it ran.
7. **Alert wording.** Open Automatic checking.
   - Expected: the text says checks are scheduled about every 12 hours and
     Android may delay them; no "up to 12 hours" promise. Debug interval
     still works separately.

## C. Standing release items (from the main spec)

8. **Release alarm behavior.** With the app built in release mode, let the
   timed check fire (or use the debug interval) with the app closed.
   - Expected: the check runs, the widget updates, and an alert appears for
     a flagged text.
9. **First-aid threshold.** Type 3-4 first-aid phrasings (e.g. "natusok ng
   pako", "napaso ang bata") and 3-4 near-misses that should NOT match.
   - Expected: cards appear for true matches and not for near-misses at the
     0.56 threshold. Record the scores if shown in debug; the threshold is
     still unmeasured on the phone.
10. **Airplane-mode core flow.** Airplane mode on: quick button -> card with
    hotlines -> tap a place -> offline map renders with markers and
    distance -> tap-to-call opens the dialer.
    - Expected: every step works with no network.

## Recording

Note pass/fail per line with a word on anything surprising. A failed line in
section A keeps the classifier disabled (ship the baseline); failures in B or
C are release blockers to triage against the 07:00 feature stop.
