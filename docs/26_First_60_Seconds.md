# 26. The first 60 seconds of Pawl (ground truth, 2026-11-02, updated after the paintings and multi-pick)

This is exactly what a new person sees and taps, screen by screen, from the first open to
blocks on. Paste this into any fresh session, with the prompt at the bottom, to get a new
perspective. Keep this file updated after every change so every reviewer sees the same thing.

The rules that do not bend: no account, no server, no data collected. The block cannot be
lifted from the phone alone. The wait is never skipped. Copy is plain and kind, never shaming.
No em dashes. The person reading is often having a hard time.

## Screen 1: Welcome (role picker)

- Art: a painting of a calm tabby cat sitting with a green USB-C security key at its paws.
- Title: "Welcome to Pawl"
- Subtitle: "What do you want to block?"
- Line: "Pick one or more. You can change this later." Tap to select, tap again to unselect.
  More than one can be picked; the first tap is the main focus.
- Seven cards in a two-column grid, each with an icon, a title and one line:
  - Social media: "Instagram, TikTok, X, Reddit, whatever keeps pulling you back."
  - Games: "The games you open without deciding to."
  - Shopping: "Shopping apps and sites you keep browsing."
  - News and doomscrolling: "News and feed apps you check too often."
  - Adult content: "Apple's adult-site filter, plus any apps you pick."
  - Gambling: "Sportsbook, casino, and crypto apps and sites."
  - Something else: "Any mix of apps and sites you choose."
- Button: "Continue" (dim until a card is picked).

## Screen 2: What it costs you (step 1 of 5, dots at the top)

- Art: the same sitting cat, smaller.
- Title: "What it costs you". Sub: "A quick, private look."
- Body (changes with the pick): "Pawl blocks the social apps and sites you choose, and makes
  unblocking deliberately hard. It takes your physical security key plus a 15-minute wait. No
  shortcuts in the moment."
- Card: "How many hours a day does this take?" Slider 0 to 8 in half hours, default 2.
  Under it: "2 hours a day is about 730 hours a year, or 30 full days."
  Small: "Stays on your phone. Pawl uses it to show you the time you keep."
- Button: "Get started".

## Screen 3: Allow Screen Time (step 2)

- Art: the cat holding up one paw.
- Title: "Allow Screen Time". Sub: "This is how Pawl blocks apps."
- Body: "Apple's Screen Time does the blocking. Pawl only ever sees anonymous tokens, never
  which apps you chose."
- Card: "Not allowed yet" with a dashed circle; becomes "Screen Time allowed" with a check.
- Button: "Allow Screen Time" (shows Apple's system prompt), then "Continue".

## Screen 4: Choose what to block (step 3)

- Art: the cat tapping one of three blank app tiles.
- Title: "Choose what to block" (or "What are you here to block?" for gambling and adult).
  Sub changes with the pick, e.g. "Add the social apps you keep opening. Website categories
  are optional."
- Two toggles: "Gambling sites" ("Sportsbook, casino, and crypto sites we keep a list of.")
  and "Adult sites" ("Turns on Apple's built-in adult-website filter."). Gambling is on by
  default for the gambling pick; adult is on for the adult pick.
- Card "Apps": a count and an "Add" button that opens Apple's app picker (a system sheet).
- Card "Websites": "Type a site to block it, like example.com." with a field and "Add".
- Button: "Continue" (dim until something is chosen; small line: "Pick a category, add an
  app, or type a site, so Pawl protects something.").

## Screen 5: How will you unlock? (step 4)

- Art: a key alone on the left, the cat asleep on a second key on the right.
- Title: "How will you unlock?". Sub: "Pick one. You can add the other later."
- Two cards side by side:
  - A security key: "A small USB-C key you keep out of reach."
  - An ally: "Someone you trust says yes from their phone. Pawl Pro."
- Pick the key: an explainer card (It's your only unlock / It plugs into your iPhone / Where
  you keep it is the trick), a "Pair security key" button, and a small "I don't have a key
  yet" link that swaps in a "No key yet? That's OK." card (Get a USB-C security key / Your
  blocks turn on now / Pair it anytime) plus a "Where to keep it" card with five places.
- Pick the ally: "Your blocks turn on now. Right after setup, Pawl opens the Ally page so you
  can invite them. Until they join, nothing can unlock." Then four rows: You send one link /
  They tap Approve / They see almost nothing / Needs iCloud on both phones.
- Button: "Continue" (dim until a key is paired, "I don't have a key yet" is on, or ally is
  picked).

## Screen 6: Lock it in (step 5)

- Art: the cat lying down with the key tucked under its chin.
- Title: "Lock it in". Sub: "Here's what you're turning on."
- A summary card: website categories, apps count, sites.
- Body: "From here, lifting the shield needs your key or a yes from your ally, plus the wait.
  Turning off Screen Time still removes protection. For a full lock, someone you trust can
  set a Screen Time passcode for you. That's Hard lock in Settings."
- Button: "Lock it in" (shows "Activating…" while it works).

## Then: Home

- Hero: "About 4 hr back, this week, with 2 of 7 days blocked" (or "0 of 7 days blocked
  this week" on day one), a row of plain stats when there are any, and a "Protected" pill.
- If no key and no ally: a nudge, "Pair your security key: Your blocks are on, but nothing
  can unlock them yet. Pair a key, or add an ally in Settings (Pro)."
- The week card with a day strip.
- "What's blocked" card.
- Screen Time card (needs the PawlReport target).
- "Log a slip or a note" link.
- Tabs: Home, Unlock, Settings (and Ally, if this phone is someone's ally).

If setup chose the ally, the app lands on Settings > Ally instead, ready to "Invite an ally".

## Counts

Taps to blocks on, shortest path (social, one app, no key): pick a card, Continue, Get
started, Allow Screen Time, system Allow, Continue, Add, pick an app, Done, Continue, A
security key, I don't have a key yet, Continue, Lock it in. About 14 taps and two system
sheets. Reading: roughly 330 words if they read everything.

## The prompt to paste into a fresh session

> You are reviewing the first 60 seconds of Pawl, an iPhone app that blocks apps with Apple's
> Screen Time and can only be unlocked with a physical security key or a yes from a trusted
> person, then a wait. Below is the exact current flow, screen by screen. Play the role of
> [a 24 year old who just deleted TikTok for the third time / a 50 year old father trying to
> stop sports betting / a product designer at a top app studio / a person who has never heard
> of a security key / an App Store reviewer]. Walk the flow in that role. Tell me: where you
> would bail and why, which words you did not understand, what you expected to happen that
> did not, and the three changes that would most improve the first minute. Be specific: quote
> the line and give the replacement. Do not suggest accounts, servers, data collection,
> analytics, or anything that lets the person unlock without the key or the ally. Keep the
> tone plain and kind. No em dashes.
