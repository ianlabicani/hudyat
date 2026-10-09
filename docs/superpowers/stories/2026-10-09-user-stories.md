# Hudyat: practical user stories

- **Date:** 2026-10-09
- **Status:** reference; describes the app as built on `feat/mvp`
- **Goes with:** the [design spec](../specs/2026-10-09-hudyat-design.md)
  and the [current plan](../plans/2026-10-09-stabilization-and-classifier.md)

These stories say who Hudyat is for and what it realistically does for
them. The README, the demo script and the pitch must not claim more than
a story here shows. The people are invented; the behaviour is not.

## Rules every story follows

1. **Built behaviour only.** A story uses what the app does today. Each
   one names the spec sections and the screen states (spec 5.4) it
   relies on. If a feature is not built, it is not in a story.
2. **Pack data only.** Every phone number, address and first-aid step a
   person sees comes from the pack. The AI never supplies one.
3. **Never "safe".** The app never tells anyone a message is safe or
   real. "Walang nakitang problema" still means be careful.
4. **No promised alert time.** When live checking is on, an SMS warning
   can appear as the text arrives; messaging apps are checked from their
   visible notifications, which Android can withhold. The about-12-hour
   check is the recovery path and Android may delay it. A story never
   says an alert arrives by a set time.
5. **SMS and messaging apps, with consent.** Automatic SMS capture needs
   the SMS permissions the user grants. Messenger, WhatsApp, Viber and
   Telegram are checked from their visible notifications only after
   notification access is switched on and the app is picked. Anything
   else is checked only when someone shares or pastes it.
6. **Metro Manila for places.** Places and the map cover Metro Manila.
   Hotlines and lookups are nationwide.
7. **The classifier is not in a story** until it passes its release
   gate in the plan. Stories describe the phrasing check as it ships.
8. **Every story ends with where it falls short.**

When the app changes, change the story in the same commit.

## 1. Lola Nena: the app works without her doing anything

**Who.** Nena, 68, Valenzuela. A budget Android phone. She texts and
calls. Her apo set the phone up.

**Setup, done once by the apo on Wi-Fi.**

1. Installs Hudyat and gets the models and the pack onto the phone.
2. Turns on Automatic checking and allows SMS access.
3. Puts the widget on the home screen.
4. Shows her two things: the emergency buttons, and "if a text looks
   strange, open Hudyat".

**An ordinary week.**

1. A text arrives: "GCash: your account is locked, verify at
   gcash-verify. com".
2. Hudyat checks the text as it arrives, on the phone, with no model
   load and no network.
3. A notification appears. The title is the sender; the body is the
   reason: the link is not GCash's official website.
4. She taps "View result" and the saved result opens. It reads
   "Mukhang scam", with the reason in plain English and the real GCash
   contact with a Call button.
5. She calls the real number or shows her apo. She does not tap the
   link.

The widget is the quiet version: three counts for the last 7 days,
never a message or a sender. Home shows the same counts in its
"Message guard" panel, with a button to the Flagged list.

**Typhoon night.**

1. She opens Hudyat and taps the flood button. No typing.
2. The card shows the Valenzuela disaster office's numbers, each with
   a Call button, and the pack build date.

**Where it falls short.**

- She may still open the text before its warning appears (rule 4).
- She needs someone for the setup. She will not do it alone.
- A scam on Messenger is checked from its notification only if her apo
  also turned on notification access for that app; muted or hidden
  conversations stay unchecked.

**Relies on.** Spec 3.4 automatic path; states Alert, Flagged "Has
messages", Result "Mukhang scam", Widget "Counts", Card "GPS fix".

## 2. Marco: a message on Messenger, checked in two taps

**Who.** Marco, 41, a father in Quezon City. Comfortable with his
phone. He is the one his parents ask "totoo ba ito?".

**Flow.**

1. His mother forwards him a Messenger message: "BDO Advisory: your
   account will be closed today. Update here" with a short link.
2. He long-presses the text and picks Share, then Hudyat. Or he selects
   the text and taps "Check with Hudyat".
3. The Check screen opens with the text already in the box and the
   check runs at once.
4. The result shows "Mukhang scam", each reason on its own line, and
   BDO's real contact from the pack with a Call button. One reason says
   the BSP tells banks and e-wallets not to send links by text.
5. The Sender row reads "Not given / Hindi ibinigay", because a shared
   message carries no sender. The result says the sender check was
   skipped.
6. If the chat model is ready, a dashed box labelled as AI-written adds
   one or two sentences. If not, nothing else changes.

**Where it falls short.**

- Without notification access he does the sharing himself; with it,
  the message's notification is checked as it arrives.
- With no sender, one of the checks cannot run, so the verdict rests on
  the link and the wording.
- A short link hides where it goes. By itself that gives "Mag-ingat".
  It is "Mukhang scam" here only because the text claims to be a bank.
  The same link in a text that claims a telco or a shop stays
  "Mag-ingat".

**Relies on.** Spec 3.4 manual path, link and sender rules; states
Check "Opened from share or selection", Result "Mukhang scam" or
"Mag-ingat", Result "No sender given", Result "Chat model missing or
slow".

## 3. The Reyes family: typhoon night, indoors, no GPS

**Who.** A family of five in a ground-floor apartment in Pasig. Power
is out, mobile data is gone, voice calls still connect sometimes.

**Flow.**

1. Liza types "Binabaha na dito, hanggang tuhod na, may matanda kami"
   and taps "Find help".
2. The button reads "Finding help…" and her message stays on screen.
3. The phone has no GPS fix indoors, so Hudyat asks for a city from a
   list. She picks Pasig.
4. The card appears: rescue and disaster hotlines for Pasig with Call
   buttons. It says the city was chosen manually, distances are hidden,
   and there is a "Try GPS again" button.
5. If Pasig has no number in a category, the card shows the province or
   national number, with a filled badge and a notice saying which level
   it is.
6. Her father cuts his leg on debris. She types "nasugatan si tatay,
   dumudugo ang binti". The card now has a first-aid section with fixed
   numbered steps in Tagalog and its source named. No AI text appears
   on a first-aid card.

**Where it falls short.**

- Hudyat finds the number. It cannot make the call connect when the
  network is down or the hotline is busy.
- Numbers can be out of date. Every card shows the pack build date and
  says so.
- Without a GPS fix there are no distances, so "nearest" is by city
  only.
- First aid is eight fixed cards. Anything else gets the emergency
  hotline, not advice.

**Relies on.** Spec 3.1, 5.1 and 5.3; states Home "Matching", Card "No
GPS fix", Card "No city hotline", Card "Typed message matched a
first-aid card".

## 4. Kuya Dencio: outside Metro Manila

**Who.** Dencio, 55, a tricycle driver in Tuguegarao, Cagayan. He
installed Hudyat because his daughter in Manila told him to.

**Flow.**

1. During a flood he taps the flood button.
2. The pack has no hotlines listed for Tuguegarao, so the card shows
   the national numbers, with a filled badge and a notice saying so.
3. He needs the DSWD regional office. He types "DSWD" into the box on
   Home and gets the agency's contacts with a Call button.
4. The message check works for him exactly as it does in Manila.

**Where it falls short.**

- No nearby hospitals, pharmacies or shelters and no map. Places exist
  only for Metro Manila.
- How the places list reads for someone far outside Metro Manila has
  not been checked on the phone. Check it before showing this story.
- Only 61 cities have their own hotlines in the pack, and only 10 of
  Metro Manila's are among them. Marikina is not. Everyone else gets
  the national numbers.

**Relies on.** Spec 2 (scope notes), 5.3; states Card "No city
hotline", Search "Results".

## 5. Aling Tess: months of promo texts

**Who.** Tess, 49, runs a sari-sari store in Caloocan and takes GCash
payments all day. Her inbox is full of promos and "wrong send" texts.

**Flow.**

1. She opens "Check a message", then Scan, and picks "Last 3 months".
2. The screen says what is read and kept, and how many texts in that
   range are not yet checked. She taps Scan and allows SMS access.
3. The rules pass finishes in about a second for a few hundred texts. A
   progress line shows "Checking n of m".
4. The summary shows how many were read and the counts per verdict.
5. The Flagged list has one row per sender. A casino's or bingo
   site's row counts its promos as "Sugal promo"; opening the sender
   shows them in their own group with a count. The reason names the
   brand or the link's domain. It does not call the operator illegal.
6. She opens a promo. Under "Want fewer of these?" it says how many
   that sender has sent, and she taps "Block this sender in Messages" to
   block it herself in her SMS app. The same section gives a free line
   to talk to someone and says PAGCOR has an exclusion programme.
7. A fake "customer service" text with a broken-up link sits under
   "Mukhang scam".
8. She opens one and taps "Open in Messages" to delete the conversation
   herself in her SMS app.
9. A real payment text such as "Paki-GCash na lang yung bayad" is not
   flagged. Naming GCash is not the same as pretending to be GCash.

**Where it falls short.**

- Hudyat cannot delete or block a text. Android allows that only for
  the SMS app.
- The gambling list is hand-made. A brand not on it is caught only by
  the wording and link rules.
- The optional wording pass takes about a second per text. She can stop
  it and continue later.
- Only flagged texts are kept. Everything else is discarded after the
  check.

**Relies on.** Spec 3.4 scan path, gambling promos, "claiming is more
than mentioning"; states Scan "Ready", "Running", "Finished", Result
"Gambling promo", Result "Flagged, sender given", Flagged "Has
messages".

## 6. Ate Joy: an agency number with no data

**Who.** Joy, 34, a call-centre worker in Taguig. After the storm she
has no data and needs to ask about a calamity loan.

**Flow.**

1. On Home she types "SSS" into the box and taps "Find help". Hudyat
   says this did not look like an emergency and shows search results.
2. The results list the agency with its contact numbers. Each row with
   a number has a Call button.
3. She also searches for her barangay captain's office and finds the
   LGU contact.
4. A result for an online service is marked "needs internet" and is
   shown with the agency's phone number, which she can still call.

**Where it falls short.**

- Hudyat gives the contact, not the answer. Whether the loan is open is
  for the agency to say.
- Service entries are a title and a web link. They are no use until she
  is back online.
- Typing something no card or record matches gives the emergency
  hotline and the quick buttons, not a guess.

**Relies on.** Spec 2 (everyday lookup), 5.3; states Search "Results",
Search "No results", Search "Message outside all cards".

## 7. Ben: no helper, and the model is not there

**Who.** Ben, 62, a retired jeepney driver in Manila. Nobody set the
phone up for him. The app is installed, but the language model is not
on the phone.

**Flow.**

1. Home shows a notice that the language model is not on this phone and
   that typing uses keyword search until it is. All eight quick buttons
   show, not the usual four.
2. He taps the fire button. The card appears with the fire hotline and
   the nearest fire stations, the same as on any other phone.
3. He types "ospital". Keyword search lists hospitals with Call
   buttons.
4. He pastes a suspicious text into Check. The link, sender and
   gambling checks run. The Phrasing row reads "Not ready yet".
5. No AI-written sentences appear anywhere. The cards and verdicts are
   unchanged.

**Where it falls short.**

- Getting the models onto a phone is the weakest step. They are large,
  and the demo build has them copied over USB.
- Without the model, a full Taglish sentence is matched by keywords
  only, so a long message can miss. The buttons do not have this
  problem.
- The wording check does not run, so the message check is weaker.
- Automatic checking is off until someone turns it on. Home's guard
  panel says so and offers "Turn on", but he still has to allow SMS
  access himself.

**Relies on.** Spec 5.3 (embedding model missing, chat model missing);
states Home "Embedding model missing", Result "Scam phrases not ready",
Card "Chat model missing or slow".

## Who Hudyat is not for yet

Do not put these in a README, script or pitch.

- **iPhone users who want automatic checking.** iOS does not allow it.
- **Anyone who wants texts blocked or deleted.** Hudyat only reads.
- **Anyone who wants to be told a message is real.** It never says so.
- **People outside Metro Manila who need the nearest hospital.** There
  is no pack for their area.
- **Someone with a medical question beyond the eight cards.** They get
  the emergency hotline.
- **Someone with no one to set the phone up** and no Wi-Fi for the
  first run.
