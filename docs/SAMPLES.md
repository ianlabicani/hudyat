# Sample messages

Messages to try in the app, for a demo or to see what each part does.
Two kinds: texts to check, and requests for help.

## Check a message

Open **Check a message**, paste one of these and tap **Check**. You can
also share or select the text from another app and choose Hudyat.

The verdicts and reasons below are what the rules give. They come from
the project's recorded cases (`test/fixtures/checker_cases.json`), which
run the checker against the real data pack. None of them needs the AI
models.

### Mukhang scam

| Message | Reasons shown |
|---|---|
| `GCash: I-verify ang account mo sa https://gcash-verify.com` | The link imitates GCash. Banks and e-wallets do not send links by text |
| `Mula sa DSWD: kunin ang ayuda sa dswd-ayuda.net ngayon` | The link imitates DSWD |
| `Your BDO account is locked. Visit bdo-online.com to restore.` | The link imitates BDO. Banks do not send links by text |
| `BDO: Your card was used. Details at https://bit.ly/3abcXYZ` | The link is shortened. Banks do not send links by text |
| `Para sa refund, pumunta sa csraftersales. com at pakitanggal ang space` | The link is deliberately broken up to get past the network's filters |
| `Meralco Advisory: Bayaran ang bill sa http://meralco-bills.xyz/pay?id=1` | The link imitates Meralco |
| `Mula sa DSWD, kunin ang ayuda dito: ayuda-claim-ph.net/form` | It claims to be DSWD, but the link is not DSWD's website |
| `Sali na sa jackpot! Mag-deposit at kunin ang rebate: https://bit.ly/win` | The link is shortened, and it is an online gambling promo |

The GCash, DSWD, BDO and Meralco examples also show that organisation's
real contact, with a Call button.

### Mag-ingat

| Message | Reason shown |
|---|---|
| `Smart ka talaga! Check mo to: tinyurl.com/abc123` | The link is shortened, so its destination cannot be seen |
| `Congrats! Claim your 100% welcome bonus, free spins at cashback sa https://lucky-casino88.com` | An online gambling promo. It is listed under "Sugal promo" |
| `BingoPlus: Deposit now, get rebate and free bonus! bingoplus.com` | An online gambling promo, recognised by its brand |
| `Agent ng BPI ito. Ibigay ang OTP para ma-verify ang account mo.`, with the sender given as `09171234567` | It claims to be BPI but comes from an ordinary mobile number |

### Walang nakitang problema

These show the checker does not flag everything that names a company.

| Message | Why nothing is found |
|---|---|
| `GCash: I-verify ang account mo sa https://www.gcash.com/help` | The same words as the scam above, but the link is GCash's real website |
| `Your OTP is 123456. Do not share it with anyone.` | An ordinary OTP notice with no link |
| `Na-claim ko na yung bayad mo sa GCash, salamat` | It names GCash without pretending to be GCash |
| `Ma, nakauwi na ako. Anong ulam natin mamaya?` | An everyday message |

This verdict is not a guarantee. The result screen says so.

### What changes a result

- **The sender.** A message that claims an organisation and is given an
  ordinary mobile number as its sender gains the reason "It claims to be
  ... but comes from an ordinary mobile number". A pasted or shared
  message has no sender unless you type one, and the result then says
  the sender check was skipped.
- **A real text with a link may not arrive.** Philippine networks filter
  links in texts sent from one phone to another, which is why scammers
  break links up. To show a text arriving and raising an alert, send the
  `csraftersales. com` message from a second phone. Paste or share the
  others.
- **The wording check needs the model.** A message with no link, such as
  `Ang iyong GCash account ay na-lock. I-verify agad ang iyong account
  sa link na ito para hindi ma-suspend.`, gets nothing from the rules.
  Only the language model can flag it, as "The wording is close to known
  scam messages", and that gives "Mag-ingat" at most. In an early test
  on the phone it caught 12 of 20 such examples, so try a message on
  your phone before relying on it.

## Ask for help

On Home, type one of these under **What happened?**. With the language
model installed, a strip reading "Understood: ..." appears after a
pause; tap it or tap **Find help**. Pick a city if the phone has no GPS
fix.

These are the pack's own example phrases for each need, so they are the
closest matches the model can get.

| Type this | Understood as | The card shows |
|---|---|---|
| `binabaha na dito sa amin, may matanda na hindi makalabas` | Flood rescue | The city's rescue and disaster hotlines |
| `hanggang dibdib na ang tubig, nasa bubong na kami` | Flood rescue | The same |
| `may sunog sa kapitbahay namin` | Fire | The fire hotline and nearest fire stations |
| `hindi makahinga si lola, kailangan ng ambulansya` | Medical emergency | Emergency hotlines and nearest hospitals |
| `nasugatan ang kamay ko, ang daming dugo` | Injury | Hotlines, nearest hospitals and a first-aid card |
| `may magnanakaw sa bahay namin ngayon` | Police | The police hotline and nearest police stations |
| `saan may bukas na botika malapit dito` | Medicine | Nearest pharmacies |
| `saan ang pinakamalapit na health center` | Clinic | Nearest clinics |
| `saan ang evacuation center dito` | Shelter | Nearest shelters |
| `paano kumuha ng barangay clearance` | Look up | A search of agencies, officials and services |

### First aid

A first-aid card appears only when the message is understood as an
Injury. Each card has fixed steps in Tagalog and names its source.

| Type this | First-aid card |
|---|---|
| `nasugatan si tatay, ang daming dugo, ayaw tumigil` | Severe bleeding |
| `natusok ng pako ang paa ko habang baha` | Wound or nail puncture |
| `napaso ng kumukulong tubig ang bata` | Burn |
| `nabalian ng buto ang kapatid ko` | Broken bone |
| `nakagat ng aso ang anak ko` | Animal bite |
| `nakuryente ang kapitbahay namin` | Electric shock |
| `may tumama sa ulo niya, nagdudugo` | Head injury |

The threshold for matching a first-aid card has not been measured on the
phone, so check a message on your own phone before showing it. A message
about drowning is likely to be understood as Flood rescue or Medical
emergency, which carry no first-aid card.

### Without the models

Typing runs a keyword search instead, and the quick buttons under the
text box open the same cards. Try `baha`, `ospital` or `sunog`.

## Places and the map

Places and the map cover Metro Manila. Hotlines and the directory are
nationwide. Pasig and Valenzuela have their own city hotlines in the
pack; a city without one shows the province or national number, with a
badge saying which.
