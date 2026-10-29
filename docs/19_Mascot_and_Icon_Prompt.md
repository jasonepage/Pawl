# Prompt: redesign Pawl's mascot and app icon

Paste everything below the line into a new session. It is written for a fresh context with no
memory of earlier work.

---

You are redesigning the mascot and the app icon for **Pawl**, an iPhone and iPad app. Take your
time. Explore first, show options, and only finalize after Jason picks a direction. Quality
matters more than speed here.

## The app

Pawl is an app and website blocker you unlock with a physical security key (a small USB-C
FIDO2 key, like a YubiKey). You pick what to block, pair the key once, and then put the key
somewhere hard to reach: a friend's house, a time lock box, a desk at work. To unblock, you need
the key plus a wait. Many people use it to stop gambling, adult sites or apps that eat their
evenings. The physical key is the whole idea: the distance between you and your key is what
gets you through 1am.

- Repo: `~/Documents/GitHub/Pawl-iOS` (public at github.com/jasonepage/Pawl). Read `README.md`
  first, then `site/index.html` and `site/pawl.css` for the brand.
- Brand greens (from the app icon): `#4c7f1c`, `#3c6a14`, `#2c550d`, deepest `#16300a`, pale
  `#e6efdc`. The current mascot is gold or brass (`#c9a227` range).
- Website: getpawl.com. App Store name: "Pawl: App Blocker With a Key".

## The current mascot

"The Stooped Key": an old brass key with a bent back, two eyes and a small mustache. Files:

- `site/img/mascot/pose-locked.svg`, `pose-waiting.svg`, `pose-open.svg`, `pose-nokey.svg`
  (512 x 512 viewBox)
- The same four in `Pawl/Assets.xcassets/` as `MascotLocked`, `MascotWaiting`, `MascotOpen`,
  `MascotNoKey` image sets
- `Pawl/Theme/PawlMascot.swift` picks the pose from the unlock state. Tapping him makes him do
  a short dance, or a small nod when Reduce Motion is on.

What each pose means today: **locked** (standing guard while apps are blocked), **waiting** (eyes
closed, a small hourglass, during the wait before apps open), **open** (standing up straight and
looking away while apps are open), **no key** (a dashed outline before a key is paired).

## Jason's rules for the mascot (keep all of these)

1. It must clearly look like a **key**. A key with personality, not a person.
2. Very **simple**: it has to read at 29 points on a home screen and print cleanly on a 4 x 6
   inch card.
3. **Scalable vector** (SVG), flat shapes, no photos and no raster-only effects.
4. It's an **old-man key** character. Keep that idea, and make it far better.

## What "better" means

Jason wants this mascot to be the brand, the way Duolingo's owl is Duolingo: one character
people recognize instantly and feel something about. He also likes the look of Kurzgesagt's
videos: bold flat shapes, rich color, soft glows and gradients, a little cosmic and dreamy.

Borrow the **qualities**, never the specifics:
- From Duolingo's owl: one strong silhouette, big readable expressions, a personality that
  shows up in every state of the app.
- From Kurzgesagt: flat vector shapes without outlines, layered color with soft gradients and
  glow, a warm, slightly cosmic world.
- **Do not** copy either one. No owl, no bird shapes, nothing traceable to Duo or to
  Kurzgesagt's characters, palettes or scenes. The result has to be clearly Pawl's own.

"Gamify it" means the mascot reacts to what the person does, like a game character. But follow
Pawl's rule: **reward only riding out an urge, and never score or shame a slip.** A slip is
normal. The mascot can be quietly supportive after one, never disappointed or sad at the person.
Copy and tone are plain and respectful, never punishing and never babyish.

## Poses to draw

Keep the four existing poses with the same meanings, so the app works unchanged:
1. `locked`: on guard, calm and steady.
2. `waiting`: patient, with an hourglass or similar.
3. `open`: relaxed, at ease, but still clearly the same key.
4. `nokey`: a dashed or ghosted outline, meaning "no key paired yet".

Then propose these new ones (they need app work later, so design them, but don't wire them in):
5. `resisted`: the person rode out an urge. A small, earned celebration.
6. `streak`: a milestone (for example 7, 30 or 100 days). Proud, a bit of sparkle.
7. `slip`: supportive after a slip. Steady, kind, "we keep going". No sad face.

## The app icon

Make a new 1024 x 1024 app icon built around the new mascot:
- **Light:** `Pawl/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- **Dark:** `AppIcon-Dark.png`
- **Tinted:** `AppIcon-Tinted.png` (grayscale, for iOS tinted home screens)

Check Apple's current Human Interface Guidelines for iOS 18 app icons before you make the dark
and tinted versions. The rules for those changed recently, so don't go from memory. No text in
the icon. One clear shape that still reads at small sizes. Keep it recognizably Pawl green, or
explain why it should change.

## How to work

1. **Explore first.** Make 3 or 4 clearly different directions for the new mascot, each shown in
   2 poses plus a small icon mockup. Put them on one HTML page Jason can open on his phone, with
   each direction at real home screen size (60 x 60 points) next to the current icon. Stop and
   ask Jason to pick.
2. **Then finalize** the chosen direction: all 7 poses and the 3 icon versions.
3. **Work in a new folder,** `design/mascot-v2/`. Do not overwrite the live files until Jason
   approves the final set.
4. **When approved,** replace the files below, keeping the same file names so the app code
   doesn't change.

## Every place to update after approval

- `Pawl/Assets.xcassets/AppIcon.appiconset/` (the 3 icon PNGs)
- `Pawl/Assets.xcassets/Mascot*.imageset/` (the 4 existing poses)
- `site/img/mascot/pose-*.svg` (the same 4)
- `site/img/pawl-mark.svg` (the small logo in the site's top bar and footer)
- `site/favicon.ico`, `site/img/favicon-32.png`, `site/img/apple-touch-icon.png`,
  `site/img/icon-192.png`, `site/img/icon-512.png`
- `site/img/og-image.png` (the 1200 x 630 link preview image)
- The README's top image points at `AppIcon.png`. GitHub caches images, so the first time use a
  new file name or add `?v=2` to the image address so the new one shows right away.
- The printed setup card: run `python3 kit/build_setup_card.py` to rebuild
  `kit/Pawl-Setup-Card.pdf` from the new images.
- The App Store only shows the new icon after the next app version is submitted and approved.

## Rules for any text you write

- No em dashes or en dashes anywhere. Use periods, commas or colons.
- Follow Jason's saved writing preferences in memory, including his banned words.
- Plain words, short sentences.

## Git

Jason does not run git commits himself. Make one commit for the finished work, on `main`, with
everything included. Jason pushes with GitHub Desktop. Don't create branches.
