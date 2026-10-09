# Live ScamShield protection for Hudyat

Accepted 2026-10-09. Implementation complete on `feat/mvp`; device
verification on the Infinix is still required before claiming behavior.

## Status

Built and covered by laptop tests:

- Live SMS capture (`LiveSmsReceiver`, `RECEIVE_SMS`, multipart) and a
  notification listener (`ScamNotificationListener`) for Messages,
  Messenger, WhatsApp, Viber and Telegram, with per-app controls.
- One serial native pipeline (`ProtectionEngine`) running the Kotlin
  rules off the main thread: no Flutter engine, no models, no GPS, no
  network. The recovery alarm now rides the same worker.
- `flagged.sqlite` shared by native and Dart with additive migrations,
  transactional writes and stable ids; source key, type/package, arrival
  time and rules version stored per result. Native saves before alerting.
- `ProtectionPlatform`/`ProtectionController` on the Dart side; alerts
  carry the result id and open that saved result, including cold start,
  with an explicit unavailable state when cleared.
- "Automatic checking" shows live-protection controls, per-source
  readiness, listener connection, alert permission and last run.
- Foreground AI passes recheck saved notification findings; SMS catch-up
  reconciles with live capture without repeating alerts.
- Widget counts labelled "7-day SMS". Message text is kept only for
  flagged findings; backup rules exclude it.
- The classifier stays gated as before; live capture uses rules only.

Verification so far: `flutter analyze` clean, 231 Flutter tests, 57 pack
tests and three Kotlin test classes pass, `flutter build apk` builds.

Still required on the phone (see `docs/superpowers/2026-10-10-phone-pass.md`
section C and the list below): live timing under two seconds, behavior
foregrounded/backgrounded/swiped/locked/after reboot, permission denials,
and real-SMS vs notification-only capture.

## The plan (as accepted)

Make Hudyat check incoming SMS and messaging-app notifications as they
arrive, then immediately warn about strong scam findings. Keep processing
on the phone and avoid loading AI models for each background event.

First release: hackathon APK, scams first, messaging apps by default,
notifications only for "Mukhang scam." Emergency and advisory detection
follow in a separate stage.

### Incoming messages and efficiency

- Add an Android SMS receiver using `RECEIVE_SMS`; combine multipart
  messages before checking. Add a notification listener for installed
  SMS, Messenger, WhatsApp, Viber and Telegram apps, with user controls
  to change coverage. These are supported Android entry points.
- Route both sources through one native processing pipeline using the
  existing Kotlin scam rules and pack data. Keep Dart as the rule source
  of truth and retain parity tests.
- Extract individual incoming messages from messaging-style
  notifications; fall back to expanded notification text. Ignore Hudyat's
  notifications, outgoing messages, group summaries and empty content.
  Keep app names and conversation titles separate from message text.
- Process off the main thread through one serial executor. Cache rules
  until the installed pack changes; do not start Flutter, load models,
  access GPS or make network requests.
- Prefer direct SMS capture when its permission is granted; otherwise
  use the SMS app's notification. Deduplicate notification updates and
  reconcile SMS arrival records with later inbox scans.
- Keep the existing 12-hour schedule as SMS recovery. Check new or
  changed messages incrementally; rebuild the seven-day counts when
  rules change. Initial enablement counts existing messages without
  issuing historical alerts.

### Results, alerts and interfaces

- Save every flagged result before posting its alert. Use the existing
  `flagged.sqlite` database with compatible native and Dart migrations,
  transactional writes and stable result IDs.
- Extend saved results with source identity, source type/package,
  arrival time and rules version. Preserve existing results and their
  AI-check status; update matching findings without replacing their IDs.
- Add a `ProtectionPlatform` interface for status, source settings,
  notification-access settings and result-change events. Extend
  incoming navigation to carry a result ID.
- An alert opens that exact saved result, including after a cold start.
  If the result was cleared, show an explicit unavailable state.
- Notify once for strong findings, showing fixed pack-backed reasons and
  a "View result" action. Save caution findings quietly. Notification
  updates and catch-up scans must not repeat alerts.
- Run existing AI checks while Hudyat is foregrounded: retain SMS
  catch-up and add checks for saved notification findings. Do not retain
  unflagged notification text for later AI processing. Background AI
  remains deferred.
- Preserve the existing verdict policy and classifier release gates.
  Faster capture does not justify enabling unvalidated classifier
  weights.

### Protection controls and privacy

- Update "Automatic checking" to explain live protection and provide
  separate SMS and app-notification controls. Existing enabled SMS
  checking stays enabled; notification access requires explicit setup.
- Show source-specific readiness, listener connection, alert
  permission/channel status, last processing time and actionable
  failures. Notification access and permission to show Hudyat alerts
  are separate.
- Permission denial disables only the affected capability. Turning
  protection off stops capture and recovery alerts; retained findings
  remain reviewable.
- Store message text only for flagged findings. Retain bounded
  deduplication metadata for seven days, exclude message storage from
  Android backup, and keep message bodies out of logs.
- Explain incomplete coverage: hidden previews, muted apps and
  Android-redacted content may be unavailable. Missing text must never
  produce a "clear" finding. Android 15 restricts notification access
  to some OTP content.
- Keep widget counts explicitly labelled as seven-day SMS counts.
  Update product stories and demo claims to match verified behavior.

### Verification and release defaults

- Test multipart SMS, notification extraction, outgoing-message
  exclusion, repeated updates, identical but distinct messages, SMS
  catch-up reconciliation and Hudyat-alert loop prevention.
- Test storage migration, concurrent native/Dart writes, stable IDs,
  cold-start navigation, clearing results, permission denial/revocation
  and rules-version invalidation.
- Preserve scam-rule parity and ordinary-message regression cases. Run
  Flutter analysis/tests, Kotlin tests, relevant pack checks and an APK
  build.
- After a user-initiated installation, verify the release build on the
  Infinix while foregrounded, backgrounded, swiped away, screen-locked
  and after reboot. Test notification access and alert-channel denial
  independently.
- Target under two seconds from Android callback to alert for fast-rule
  findings; measure phone-arrival delay separately. Check burst
  handling, UI responsiveness and idle battery use before making
  reliability claims.
- Verify offline processing using locally generated test notifications;
  test real SMS reception with cellular service available. Preserve
  installed models and app data.
- Preserve current uncommitted work. No installation, publication or
  application-ID change is part of implementation.
- This plan targets the hackathon APK. Google Play distribution requires
  a separate SMS-permission review.
