# Ask classifier: design note

- **Date:** 2026-10-09, 9:45 PM
- **Status:** agreed with the builder; not built
- **Adds to:** section 3.4 of `2026-10-09-hudyat-design.md`. This note
  does not change that file.

## Why

The message check decides mostly by rules. Its one AI signal, the
phrasing match, catches 12 of 20 held-out scam messages. The classifier
makes the AI's job explicit: say what a message asks the reader to do.
The pack still answers who the message claims to be.

## Decisions

1. **Kept as built:** the rules, the emergency flow, the timed check.
2. **What the AI classifies:** what the message asks for. Several labels
   can apply to one message.
3. **Identity stays with the rules and the pack.**
4. **Verdict:** all AI labels on a message count together as one reason.
   AI labels plus a data mismatch give "Mukhang scam". AI labels alone
   give "Mag-ingat". Each label is still shown as its own line.
5. **Where it runs:** wherever the app is awake: paste, share, text
   selection, the scan, and the catch-up when Hudyat opens. The 12-hour
   Kotlin check stays rules only.
6. **Keep rule:** the classifier replaces the `phrasing` reason only if
   it beats 12 of 20 on held-out messages with no false alarm on
   ordinary ones. Otherwise the phrasing check stays as it is.
7. **Pitch:** leads with the message guard and reports the rules and the
   classifier as two separate measured numbers.

## Labels and fixed reason text

| Label | Means | Reason text (Tagalog, to be reviewed by the builder) |
|---|---|---|
| `credentials` | OTP, PIN, password or personal details | Humihingi ito ng OTP, PIN, password o personal na detalye. |
| `money` | Send money or pay a fee | Humihingi ito ng pera o bayad. |
| `action` | Click a link or install an app | Pinapapindot ka nito ng link o pinapa-install ng app. |
| `pressure` | A deadline or a threat | Minamadali o tinatakot ka nito. |
| `bait` | A prize, a job or easy money | Nag-aalok ito ng premyo, trabaho o madaling pera. |

## How it is built

1. **Vectors:** export EmbeddingGemma vectors on the Infinix for every
   training and test text, using the existing export path.
2. **Training:** a script on the laptop fits one small linear classifier
   per label on those vectors (logistic regression).
3. **Thresholds:** per label, the lowest score at which no held-out
   ordinary message gets that label.
4. **Shipping:** weights, bias and threshold per label go in the pack.
5. **On the phone:** the message is already embedded for the phrasing
   check, so scoring five labels is five dot products.

## Data

| Set | Source | Use |
|---|---|---|
| `pack/data/ask_examples.json` | 169 texts written for training: 137 with labels, 32 ordinary | Training only |
| `pack/data/scam_examples.json` | 42 existing scam phrases, to be given ask labels | Training, except the 20 held out |
| Builder's inbox, ordinary texts | 575 real texts, kept outside the repo | Part for training negatives, the rest for testing |
| Held-out scam messages | The 20 used for the 12-of-20 figure | Testing only |

Label counts in `ask_examples.json`: action 59, pressure 65, credentials
44, money 59, bait 61.

The examples in `ask_examples.json` were written by an AI assistant, not
collected. They may not match real scams, so they are never used for
testing, and they belong in the submission disclosures as synthetic
training data. Only trained weights ship; no inbox text does.

## Risks

| Risk | Plan |
|---|---|
| It does not beat 12 of 20 | Keep the current phrasing check (decision 6) |
| Real OTP and bank texts get a label | Real ones are in the training negatives and the test set |
| Ordinary requests for money between family | Hard negatives are in the examples; AI alone never gives "Mukhang scam" |
| Written examples skew the model | Test on real and held-out messages only |

## For the build session

- Give the 42 existing scam phrases ask labels.
- Add the vector export for the new texts and the training script.
- Add the weights table to the pack and the five reasons to
  `scam_reasons.json`.
- Score labels in the Dart checker; leave the Kotlin check untouched.
- Fold this note into the main spec once it is built and measured.

## Stretch

Recognise a genuine government advisory and mark it as important.
