# 26. The first 60 seconds of Pawl (v2, branch onboarding-v2, 2026-11-02)

Ground truth for the redesigned first run. Four screens, then the payoff. Paste into any
fresh session with the prompt at the bottom to get a new perspective.

Rules that do not bend: no account, no server, no data collected. The block cannot be lifted
from the phone alone. The wait is never skipped. Blocks turn on only once a working unlock
exists (a paired key or a joined ally). Copy is plain and kind. No em dashes.

One iOS fact that shapes screen 3: Pawl cannot block an app by name. Apple only hands an app
over through its own picker. Websites can be blocked by name, instantly. So the chips are
sites, and the picker is the only way to add an app.

## Screen 1: Welcome

- Painting: the tabby sitting with the green key.
- Title: "Pawl locks apps until you tap a small key."
- Body: "Pick the apps and sites. Pawl blocks them with Apple's Screen Time. To open one again
  you tap a security key you keep somewhere else, then wait 15 minutes."
- Card, three rows: "The key is about $30" (Any USB-C security key works. You buy it once.) /
  "Or an ally, with Pawl Pro" (Someone you trust says yes from their phone instead.) /
  "No account, nothing collected" (Your choices stay on this iPhone.)
- Button: "Block my first app".

## Screen 2: One permission (dot 1 of 3)

- Painting: the cat with one paw up.
- Title: "One permission". Sub: "Pawl needs Screen Time to do the blocking."
- Body: "It never sees which apps you pick. Your choices stay on this iPhone."
- Status card: "Not allowed yet" / "Screen Time allowed".
- Button: "Allow Screen Time" (Apple's sheet). The flow moves on by itself once allowed.
  If permission was already given, screen 1 goes straight to screen 3.

## Screen 3: What should Pawl block? (dot 2 of 3)

- Painting: the cat tapping a tile.
- Title: "What should Pawl block?". Sub: "Tap a site to block it right now."
- "Social" chips: tiktok.com, instagram.com, x.com, youtube.com, reddit.com, facebook.com,
  snapchat.com. Tap one: it disappears from the row and "Added. It's blocked right away."
- Apps card: "The TikTok app, the Instagram app, any app." with an "Add apps" button, and one
  line: "Apple's list shows every app on your phone. Search for the one you want, tap the
  circle next to it, then tap Done in the top right."
- Toggle "Gambling sites": "Pawl's list of sportsbook and casino sites. Off unless you turn it
  on." When on, an "Also block" row of chips: draftkings.com, fanduel.com, kalshi.com,
  polymarket.com.
- Toggle "Adult sites": "Apple's adult website filter. Off unless you turn it on."
- "Any website" card: a field and Add, plus "More sites: games, shopping, news" which opens
  three more chip rows.
- Running line at the bottom: "Blocking: tiktok.com, Gambling sites, 1 app".
- Button: "Continue" (dim with "Tap a site or add an app to continue." until something is on).

## Screen 4: Lock it with your key (dot 3 of 3)

- Painting: key alone on the left, cat asleep on a key on the right.
- Title: "Lock it with your key". Sub: "Or with an ally. One has to be ready before blocks
  turn on."
- Two cards: "Security key" (Plug it in and touch it. About 3 taps.) and "Ally (Pro)" (They
  say yes from their phone. You send one link.)
- Key picked: "Plug in your USB-C security key and tap Pair. When your iPhone asks, touch the
  key. To open a blocked app later you tap the key again, then wait 15 minutes." Button
  "Pair security key". After: a card "Key paired" with one line about where to keep it.
- Ally picked: one paragraph (send one link; they cannot see which apps or sites you block;
  needs iCloud on both phones and Pro for you only). Button "Invite my ally" (paywall first
  if no Pro), then "Send the invite" and "Check if they joined". After: "Karen is your ally".
  During setup the ally is active at once; nothing is blocked yet, so nothing is loosened.
- Button: "Turn on blocks", dim until a key is paired or the ally has joined, with "Blocks
  turn on once your key is paired." under it.

## Screen 5: Blocks are on (the payoff)

- Painting: the cat with the key under its chin.
- Title: "Blocks are on". Sub: "Blocking tiktok.com, 1 app."
- Body: "Open one of them and watch it bounce. To get back in: tap your key, then wait
  15 minutes." (or "ask Karen").
- Card: "How many hours a day did this take?" slider, optional. "That's about 2 hours a day
  back. Home will count it."
- Small: "Turning off Screen Time for Pawl removes the blocks. For a firmer lock, someone you
  trust can set a Screen Time passcode. That is in Settings."
- Button: "Go to Home".

## Taps to blocks on, shortest path (a site plus a key)

Block my first app, Allow Screen Time, Apple's Allow, tap tiktok.com, Continue, Security key,
Pair security key, touch the key, Turn on blocks. Nine taps, one system sheet, no picker.
With the app too: add Add apps, search, tap, Done. The parent test: after screen 1 they can say
"it locks apps until I tap a key I keep somewhere else."

## Not done in this flow

"Where to keep it" (five places) and "What's a security key" live in Settings now. The old
focus cards (social, games, gambling...) are gone; their site suggestions are the chips.

## The prompt to paste into a fresh session

> You are reviewing the first 60 seconds of Pawl, an iPhone app that blocks apps with Apple's
> Screen Time and can only be unlocked with a physical security key or a yes from a trusted
> person, then a wait. Below is the exact current flow, screen by screen. Play the role of
> [a 24 year old who just deleted TikTok for the third time / a 50 year old father trying to
> stop sports betting / a parent who has never heard of a security key / a product designer /
> an App Store reviewer]. Walk the flow in that role. Where would you bail and why, which
> words did you not understand, what did you expect that did not happen, and the three
> changes that would most improve the first minute. Quote the line and give the replacement.
> Hard rules: no accounts, no servers, no data collection, nothing that unlocks without the
> key or the ally, the wait is never skipped, Pawl cannot block an app by name (only through
> Apple's picker), tone plain and kind, no em dashes.
