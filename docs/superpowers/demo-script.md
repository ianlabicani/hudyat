# Hudyat: demo video script

- **Date:** 2026-10-10
- **Built from:** stories 2 (Marco) and 3 (the Reyes family) for the
  submission video; stories 1 (Lola Nena) and 3 for the long version, in
  [the user stories](stories/2026-10-09-user-stories.md)

Two versions. The **submission video** is about 1 minute, which is what
the hackathon's submission rules ask for. The **long version** below it
is the live demo for Demo Day, where finalists get 5 minutes of demo and
3 minutes of questions.

## Submission video (1 minute)

An animated video made in Remotion, kept outside this repository in
`~/Desktop/hudyat-video`. The app screens in it are **recreated**, not
recorded, and the end card says so. Every label on them is copied from the
Dart screens, and every number, reason and first-aid step from the pack
built 2026-10-09. Real screenshots go in the submission form separately.

Judging weights it is cut for: Problem & Usefulness 25%, Local AI
Implementation 25%, Technical Execution 20%, Innovation 15%, Product &
Demo Quality 15%.

| Time | Scene | On screen | Voice-over |
|---|---|---|---|
| 0:00–0:06 | Problem | Signal bars drop to none; fake "ayuda" texts pop in | "A typhoon takes the signal, just when you need to know who to call. Then the fake ayuda texts start." |
| 0:06–0:09 | Logo | The mark and "AI on the phone. Works in airplane mode" | "Hudyat keeps the AI on the phone." |
| 0:09–0:21 | Understand | Home with the airplane icon; "Binabaha na dito, hanggang tuhod na, may matanda kami" types in; the strip "Understood: Flood rescue · AI on this phone"; pick Pasig | "Airplane mode. Liza types in Taglish. A model on the phone understands: flood rescue." |
| 0:21–0:29 | Card | Pasig City DRRMO Emergency Hotline, 86430000, with Call and the pack build date | "The AI picks what she needs. The number is copied from data, never written by AI." |
| 0:29–0:38 | First aid | "nasugatan si tatay, ang daming dugo, ayaw tumigil"; the "Malakas na pagdurugo" steps; source British Red Cross | "Her father is bleeding. Fixed first-aid steps, source named. The AI chose the card, not the steps." |
| 0:38–0:50 | Scam | "BDO Advisory: your account will be closed today. Update here" with a short link, shared in; "Mukhang scam"; the short-link and BSP reasons; BDO's contact | "Then a fake bank text. Share it to Hudyat. Mukhang scam, with each reason listed. And the bank's real contact." |
| 0:50–0:56 | Why local | EmbeddingGemma, Gemma 3 1B, Infinix X6876 | "Two open models, on a budget phone. Nothing you type or receive leaves it." |
| 0:56–1:00 | End card | The mark; credits; `#AppBuildersPH`; "App screens recreated for this video" | "Hudyat. Help that works with no signal." |

What the video leaves out on purpose:

- **No timing figure.** The app's strip shows how long the model took;
  the video's strip does not, because no figure was measured for it.
- **No wording-check reason in the scam scene.** That verdict comes from
  the short-link and bank-link rules, so only those two reasons show.
- The closed-app alert, the widget, the offline map and tap-to-call.
  They are in the long version.

Not confirmed on the phone: that the bleeding message is understood as
"Injury" with the "Severe bleeding" card. Rehearsal step 6 below checks
it; if the phone says otherwise, change the strip in the video's
`src/scenes/Help.tsx` before posting.

To render: `./render-final.sh` in the video folder. For the voice-over,
run `ELEVENLABS_API_KEY=... node scripts/make-vo.mjs` first, then render
again; ElevenLabs then belongs in the AI-tools disclosure.

After rendering: post it on X or LinkedIn, tag Devin / Cognition, add
`#AppBuildersPH`, and paste the post's URL into the submission form.

## Long version (Demo Day, 5-minute live demo)

- **Status:** draft, not rehearsed on the phone
- **Length:** about 3 minutes, which leaves room inside the 5.

Everything shown is the Infinix itself. Nothing is mocked. The narration
never says more than the stories do.

### Before recording

Do these in order. Each one changes what the camera sees.

1. **Build on the phone.** A debug build, so the recovery check also
   fires every 2 minutes instead of about every 12 hours. Installing is
   yours to do; do not uninstall or clear data.
2. **Turn on Automatic checking first** and allow both SMS permissions.
   Texts already in the inbox when it is turned on are counted but not
   alerted. The scam text must arrive after the switch is on.
3. **Allow notifications** for Hudyat and put the widget on the home
   screen.
4. **Second phone ready**, with an ordinary mobile number, to send the
   scam text.
5. **Clear the Flagged list** so the demo text is the only new one.
6. **Rehearse both typed messages.** The first-aid threshold has not
   been measured on the phone, so confirm the bleeding message brings up
   the "Severe bleeding" card before recording. If it does not, try the
   pack's own wording: "ang daming dugo, ayaw tumigil".
7. **Decide GPS or no GPS for part 2.** Indoors with no fix, the city
   picker appears and distances are hidden, which is the story as
   written. Outdoors with a fix, distances show. Either is true to the
   app; pick one and say which.

The scam text to send from the second phone:

> GCash: Your account is locked. Verify now at gcash-verify. com

### Part 0: the problem (0:00 to 0:15)

| Screen | Narration |
|---|---|
| Title card: "Hudyat" and the product line | "When a typhoon takes the signal, two things happen. People cannot look up who to call. And the fake ayuda texts start arriving." |
| The phone's home screen with the widget | "So Hudyat keeps the official numbers and the AI on the phone itself. Not on a rescuer's laptop or an office server — on this phone, a ₱6,000 phone, because that is what is inside the flood zone." |

### Part 1: Lola Nena (0:15 to 1:20)

| # | Screen | Action | Narration |
|---|---|---|---|
| 1 | Home screen, widget showing counts | None | "This is Lola Nena's phone. Her apo set up Hudyat once. She does nothing after that." |
| 2 | SMS app, the scam text arriving | Send the text from the second phone | "A text says her GCash is locked, with a link to fix it." |
| 3 | Recent apps | Swipe Hudyat away, then turn airplane mode on | "Hudyat is closed. The phone is offline." |
| 4 | The notification arriving within seconds | None | "Nobody opened the app. Hudyat checks the text the moment it arrives, with rules kept on the phone. The warning names the sender and gives the reason." |
| 5 | The saved result | Tap "View result" | "Mukhang scam. The link is broken up to get past filters, and it is not GCash's website." |
| 6 | The contact section with the Call button | Scroll to it | "This is GCash's real contact, from data on the phone. Not from the AI." |
| 7 | Home screen widget, count gone up, then Hudyat's Home with the "Message guard" panel | Press Home, then open Hudyat | "The widget and the app show counts only. Never a message, never a sender." |

**If the alert does not come within about a minute:** open Hudyat.
Opening checks recent texts and the alert appears then; the recovery
check (every 2 minutes on the debug build) is the backstop. Change
line 5 to "Opening Hudyat checks her texts at once."

**Cut first if short on time:** step 7.

### Part 2: the Reyes family (1:20 to 2:35)

Airplane mode stays on and the icon stays in frame.

| # | Screen | Action | Narration |
|---|---|---|---|
| 1 | Hudyat Home | Show the airplane icon | "Typhoon night in Pasig. No data. Still in airplane mode." |
| 2 | Home, text box | Type "Binabaha na dito, hanggang tuhod na, may matanda kami" and stop. Wait for the strip "Understood: Flood rescue", then tap it | "Liza types what is happening, in Taglish. Before she presses anything, the phone has understood: flood rescue. That time is measured on this phone, offline." |
| 3 | City list | Pick Pasig | "No GPS indoors, so Hudyat asks for her city." |
| 4 | Card: Pasig City DRRMO Emergency Hotline with Call | Hold on the card | "The AI on the phone picked what she needs. The number is Pasig's disaster office, copied from the data, with the date it was built." |
| 5 | Home, text box | Type "nasugatan si tatay, ang daming dugo, ayaw tumigil", tap "Find help" | "Her father is bleeding." |
| 6 | Card with the first-aid section | Scroll through the steps | "Fixed first-aid steps in Tagalog, with the source named. The AI chose the card. It did not write the steps." |
| 7 | Hospitals list, then the Map | Tap a hospital | "The nearest hospitals, on a map that is stored on the phone." |
| 8 | Call button on a hotline | Tap Call, show the dialler, hang up | "One tap to call. Voice calls can still go through when data is down." |

**Cut first if short on time:** step 8, then step 7.

**If the strip takes more than about two seconds to appear:** tap "Find
help" instead and drop the sentence about the phone understanding before
she presses anything. The strip's speed has not been measured on the
Infinix.

**If the AI-written sentences appear on the flood card:** point at the
dashed box once and say "This part is AI-written and labelled. The card
did not wait for it." Do not read the sentences out.

### Part 3: why local, and what it does not do (2:35 to 3:00)

| Screen | Narration |
|---|---|
| Home screen with the pack line and "Ready offline" | "Two open models run on this budget phone: EmbeddingGemma decides, Gemma writes. Nothing Lola Nena receives and nothing Liza types leaves the device." |
| Result screen, "Walang nakitang problema" with the "This is not a guarantee" notice | "Hudyat never tells you a message is safe. It tells you what it found, and who to really call." |
| Credits: BetterGov open data, OpenStreetMap contributors, first-aid sources, Claude Code, Devin, Codex | "Built in one night on open data. Hudyat." |

## Lines that must not be said

- "Safe", "legit" or "verified" about any message.
- "Within 12 hours" or any promised alert time.
- "Blocks" or "deletes" scam texts.
- "Works anywhere in the Philippines" for places or the map. Hotlines
  and lookups are nationwide; places and the map are Metro Manila.
- "The AI found the number." The data has the number.
- Any accuracy figure that was not measured. The measured ones are in
  the spec and the plan.

## Known facts behind the script

- The Pasig hotline shown in part 2 is in the pack: Pasig City DRRMO
  Emergency Hotline.
- Only 10 Metro Manila cities have their own hotline rows in the pack.
  Pasig and Valenzuela do; Marikina does not. This is why the demo is
  set in Pasig.
- The unprompted alert with Hudyat swiped away was measured on the
  Infinix with the 2-minute debug alarm, which fired about 3½ minutes
  after it was set. The 12-hour interval was not observed.
- The scam text should give "Mukhang scam" from the hidden link and the
  look-alike domain. This was not run on the phone for this exact text.
