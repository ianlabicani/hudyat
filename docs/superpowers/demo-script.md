# Hudyat: demo video script

- **Date:** 2026-10-09
- **Status:** draft, not rehearsed on the phone
- **Built from:** stories 1 (Lola Nena) and 3 (the Reyes family) in
  [the user stories](stories/2026-10-09-user-stories.md)
- **Length:** about 3 minutes. The time limit was not checked; confirm
  it in the submission rules and cut from the marked lines if needed.

Everything shown is a screen recording of the Infinix. Nothing is
mocked. The narration never says more than the stories do.

## Before recording

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

## Part 0: the problem (0:00 to 0:15)

| Screen | Narration |
|---|---|
| Title card: "Hudyat" and the product line | "When a typhoon takes the signal, two things happen. People cannot look up who to call. And the fake ayuda texts start arriving." |
| The phone's home screen with the widget | "So Hudyat keeps the official numbers and the AI on the phone itself. Not on a rescuer's laptop or an office server — on this phone, a ₱6,000 phone, because that is what is inside the flood zone." |

## Part 1: Lola Nena (0:15 to 1:20)

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

## Part 2: the Reyes family (1:20 to 2:35)

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

## Part 3: why local, and what it does not do (2:35 to 3:00)

| Screen | Narration |
|---|---|
| Home screen with the pack line and "Ready offline" | "Two open models run on this budget phone: EmbeddingGemma decides, Gemma writes. Nothing Lola Nena receives and nothing Liza types leaves the device." |
| Result screen, "Walang nakitang problema" with the "This is not a guarantee" notice | "Hudyat never tells you a message is safe. It tells you what it found, and who to really call." |
| Credits: BetterGov open data, OpenStreetMap contributors, first-aid sources, Claude Code | "Built in one night on open data. Hudyat." |

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
