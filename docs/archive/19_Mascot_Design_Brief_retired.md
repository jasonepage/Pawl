# 19. Pawl mascot and icon: design brief

Paste this whole file into any design tool or model. It lists every place Pawl the mascot
shows up, every pose and animation that exists today, and what a new attempt must deliver.
Date: 2026-10-31. Current source of truth: `Pawl/Theme/PawlMascot.swift` (drawn in code),
`Pawl/Theme/PawlMascotArt.swift` (traced outline), `design/mascot-v2/` (SVGs, icon, reference).

## 1. Who Pawl is

Pawl is an old brass key with cat ears, heavy half-closed eyelids, and a white handlebar
mustache. He is tired, unbothered and loyal. He never scolds. He is the thing standing between
a person and the app they are trying not to open at 1am, and he is not impressed by the app.

Tone words: sleepy, steady, dry humor, kind. Not cute-baby, not angry, not a cop.

Current palette (sampled from the reference drawing):

| Use | Hex |
|---|---|
| Key body gold | `#CB9F24` |
| Key shadow gold | `#AF8320` |
| Eye whites and mustache (cream) | `#F0E0C0` |
| Eye ring (dark brown) | `#806010` |
| Eyelid | `#B18725` |
| Pupil and outlines (ink) | `#1A1714` |
| Brand green (icon background, app accent) | `#38661A` roughly; the icon uses a flat deep green |

Shape: a round key bow (the head) with two triangular ears, a straight shaft below, two teeth on
the right side near the bottom. No arms. When he needs to act, a separate floating cat paw
comes in from off screen.

## 2. Where he appears (screens)

| Screen | File | Pose today | Size | Notes |
|---|---|---|---|---|
| Home, over the streak ring | `Pawl/Features/HomeView.swift` | `idle`, with `halo` on milestone days | 132 pt | Tap him: the swipe plays once |
| Unlock tab, hero card | `Pawl/Features/UnlockView.swift` | follows unlock state: `noKey`, `locked`, `waiting`, `open` | 104 pt | The main place his pose changes |
| Urge screen ("I'm tempted"), while the 10 minute wait runs | `Pawl/Features/UrgeView.swift` | `waiting` | 84 pt | He waits with you |
| Urge screen, after "I resisted" | `UrgeView.swift` | `resisted` | 110 pt | The swipe on a loop |
| Settings tab header | `Pawl/Features/SettingsView.swift` | `idle` | 50 pt on a 64 pt green tile | Mirrors the app icon |
| Block screen (the shield iOS shows over a blocked app) | `PawlShield/` | none yet (a code drawn lock mark) | 44 pt icon | Static only. iOS shield extensions cannot animate and cannot load an asset catalog, so this needs a single flat PNG or code-drawn mark |
| Setup card, first launch | `Pawl/Features/OnboardingView.swift` | none yet | | Could use `noKey` or `locked` |
| Website getpawl.com hero | `site/index.html`, `site/img/mascot/pose-*.svg` | `pose-locked.svg`, wiggles on tap (CSS keyframes) | 112 to 128 px | SVG only |
| Website how-it-works steps | `site/index.html` | `pose-locked`, `pose-nokey`, `pose-open`, `pose-waiting` | 72 px | SVG |
| App icon | `Pawl/Assets.xcassets/AppIcon.appiconset/` | his face on green, dark and tinted variants | 1024 px | See section 5 |
| Favicon, Open Graph image, touch icons | `site/img/` | same face | | |
| GitHub README header | `README.md` | the icon PNG | 128 px | |

## 3. Poses that exist today (keep these six, no new ones)

| Pose | Used when | What he does |
|---|---|---|
| `locked` | Apps are blocked, a key is paired | Asleep on the job. Eyes shut, slow breathing (scale 1.0 to 1.015, 1.6 s, back and forth), a tiny sway (1.5 degrees). Two "z" letters drift up and fade (2.6 s each). A small padlock sits beside him. Every so often he wakes for a second, swipes an app away, and goes back to sleep |
| `waiting` | The cooling off wait is running; also the urge screen wait; also (2.5) while an ally request is open | Half-lidded. Blinks now and then (about 200 ms down and up). An hourglass beside him flips 180 degrees every third blink (0.5 s) |
| `open` | Apps are unlocked for the open time | Hands the key over. A paw rises from below holding a small key (spring, 0.7 s), he closes his eyes in a slow nod, the paw drops back out (0.5 s). Loops slowly |
| `noKey` | No security key paired yet | A dashed outline of his shape, no face, no color fill. Nothing moves |
| `resisted` | After "I resisted" on the urge screen | The swipe, on a loop. See section 4 |
| `idle` | Home and Settings | Half-lidded, one slow blink every few seconds. Optional halo: a ring floats 8 pt up and down above his head (2 s, back and forth) on streak milestone days |

Eye model used in code: lid value 1 = half-lidded resting face, 0.5 = wide open (surprise, only
during the bat), 2.1 = fully shut.

## 4. The signature move: the swipe

This is the one animation that carries the whole personality. Timing from the code:

1. An app tile slides in from the right toward him (0.55 s, ease out).
2. A cat paw floats in from the left (0.5 s).
3. Wind up: the paw pulls back and tilts minus 18 degrees (0.22 s).
4. The bat: the paw snaps forward and tilts plus 24 degrees; his eyes go wide for a beat (0.2 s).
5. The tile flies off up and to the right, spinning about 160 degrees, and fades (0.4 s).
6. The paw settles (0.4 s), his eyes relax back to half-lidded (0.5 s), the paw drifts off
   left (0.8 s).

Total about 3 seconds. Plays once on tap (Home), on a loop in `resisted`, and as the brief
wake-up inside `locked`.

## 5. The app icon

Current: his full face and a bit of shaft, centered on flat deep green. Three variants are
required by iOS 18:

| Variant | File | Rule |
|---|---|---|
| Light (default) | `AppIcon.png` | Full color on green |
| Dark | `AppIcon-Dark.png` | Same drawing, darker green or near black background, gold stays |
| Tinted | `AppIcon-Tinted.png` | Grayscale, white face on transparent or black; iOS tints it |

All three: 1024 x 1024 PNG, no transparency on light and dark, no rounded corners (iOS masks
them), nothing important in the outer 8 percent. The face must read at 60 px on a home screen,
so the mustache and the two eyes are the whole icon; the key teeth can be cropped.

Derived from the icon, same drawing: `site/img/favicon-32.png`, `apple-touch-icon.png`
(180 px), `icon-192.png`, `icon-512.png`, `og-image.png` (1200 x 630, face on the left,
wordmark on the right).

## 6. What a new attempt must deliver

1. One master drawing of Pawl, front facing, as SVG with clean closed paths. Six poses as
   separate SVGs named `pose-locked`, `pose-waiting`, `pose-open`, `pose-nokey`,
   `pose-resisted`, `pose-idle`, 512 x 512 art space.
2. Separate parts as their own SVG layers so the app can move them: left lid, right lid, left
   eye, right eye, the floating paw, the app tile, the hourglass, the padlock, the halo, a "z".
3. The three icon PNGs in section 5.
4. A single flat mark for the block screen: his face in one color (white) on transparent,
   readable at 44 pt.
5. Optional: a Lottie or short MP4 of the swipe for the website and the App Store preview.

## 7. Rules

- Plain and kind. Nothing that mocks the person. He is tired of the app, never of the user.
- No new poses beyond the six. Reduce Motion users get blinks only, so every pose must look
  right as a still.
- Keep the key shape. He is a key first and a cat second; the ears and mustache are the cat.
- No text in the drawings.
- Reference drawing: `design/mascot-v2/reference/gemini-kitty.png`. Earlier explorations A to D
  in `design/mascot-v2/explore/`. The chosen direction and its generator script in
  `design/mascot-v2/final/` and `design/mascot-v2/anim/`.
