# Pawl art direction: the physical key is the product

Status: security-key-first correction, 2026-10-31. The initial real-cat exploration
drifted too close to a customizable pet product. Pawl does not promise a pet feature.
The first production pass now replaces the app icon and the paired-and-locked Unlock
artwork. Other state artwork remains unchanged until each state has an approved asset.

Approved security-key-first icon direction:
`design/fido-first/icon/app-icon-candidate-v1.png`. Light, dark, and tinted variants are
connected to `Pawl/Assets.xcassets/AppIcon.appiconset`.

The original 2D cat art style remains approved for restrained in-app illustration. The
first corrected Unlock asset is `design/fido-first/unlock-art/locked-v1.png`: the cat is
supporting art and guards the modern generic FIDO2 key rather than an antique key. It
ships only in the paired-and-locked state; no-key, checking, cooling-off, and open keep
their existing state-specific presentation.

`design/pawl-cat-v3/character/model-sheet-v1.png` remains an approved character
reference, not a production gate. Do not derive a six-pose pet system from it unless an
interactive companion feature is separately defined and committed to the roadmap.

## North star

Pawl is an app and website blocker controlled by a physical FIDO2 security key. The
key creates distance, accountability, and time at the moment willpower is least
available. That product truth must be clear before the brand character appears.

> Put the key somewhere else. Even with it, you wait.

The experience should feel:

- calm, never alarming;
- characterful, never childish;
- supportive, never congratulatory or judgmental;
- tactile in its illustration, precise in its interface;
- dark and restful, but never murky or difficult to read.

This is not a cute-cat productivity game or a virtual-pet promise. It is a serious
physical-key blocker with a dry, affectionate brand character.

## Product hierarchy

Every surface should communicate in this order:

1. **Physical security key:** a real, generic USB-C/NFC FIDO2 device is the mechanism.
2. **Current protection state:** blocked, checking the key, cooling off, or open.
3. **Time and consequence:** how long the wait lasts and when apps re-lock.
4. **Pawl the cat:** a fixed brand mnemonic that adds warmth after the mechanism is
   understood.

The security key is the product hero. Pawl is not the product mechanic.

## No implied pet feature

The brand must not suggest capabilities that do not exist. Until a companion feature
is explicitly scoped, do not add:

- character naming or renaming;
- customization, outfits, rooms, accessories, or unlockable expressions;
- feeding, care, mood, growth, streak-based character progression, or collections;
- a pet home screen, tap-to-play loop, or persistent character relationship;
- copy such as `your companion` that implies ongoing pet interaction.

Pawl is one fixed character. A blink or brief state illustration is brand motion, not a
pet system.

## Product architecture comes before illustration

The character does not change where actions live.

### Home

Home is a progress and support dashboard. It contains:

- protection status;
- days on track and milestones;
- the `I'm tempted` entry point;
- the current week;
- a summary of what is blocked.

Home never contains an unlock action. It may link to the blocked-items configuration,
but it does not begin or advance the unlock flow.

### Unlock

Unlock owns the complete access state machine:

1. apps blocked / key required;
2. key being checked;
3. cooling off;
4. apps open;
5. lock now.

The active tab remains Unlock in every one of these states.

### Settings

Settings contains configuration, durations, keys, schedules, purchases, privacy, and
supporting information. It does not become a status dashboard.

## Brand character role

The approved cat model may be used for an app icon exploration, editorial marketing
art, and occasional small in-app cameos. It should not drive the product structure.

- Adult gray-brown domestic shorthair tabby; never kitten proportions.
- Broad, substantial body and mature face.
- Dark forehead `M`, consistent cheek and body stripes, slightly warm gray coat.
- Olive/chartreuse eyes with heavy lids. His default expression is observant and
  unimpressed, not angry.
- Muted pink-brown nose, pale muzzle, long light whiskers.
- When hardware appears, it is a recognizably modern generic FIDO2 security key: compact
  body, USB-C plug, touch target, and keyring hole. Do not substitute an antique key.
- Soft editorial/storybook rendering: tactile fur, controlled brush texture, readable
  silhouette, restrained outlines.
- Pawl is protective of the person and tired of the distraction. He is never tired of
  the person.

Character consistency matters more than pose novelty. Facial proportions, eye shape,
markings, and coat value must remain stable across every asset.

## Mascot density

Pawl supports hierarchy; he does not replace it.

- Home: optional small header mark, at most about 3% of the visible screen.
- Unlock: security-key hardware and state information come first. A cat cameo is
  optional and should normally remain under 12% of screen height.
- Urge flow: do not turn Pawl into a companion mechanic. A small fixed illustration may
  soften the page, but copy, timer, and support actions dominate.
- Settings: icon-sized only.
- Block shield: a reduced flat mark designed specifically for 44-point display.
- Marketing: larger narrative illustration is allowed only when the headline or
  adjacent frame already makes the physical-key mechanism unmistakable.

At least 85% of an operational screen should remain functional interface, hardware
explanation, and breathing room. Avoid placing the cat inside progress rings or making
him the background of text.

## Security-key depiction

Pawl works with real FIDO2 security keys. Illustrations must reinforce that fact.

- Use a generic device, not a YubiKey trademark or a copied commercial enclosure.
- Show the defining hardware cues: USB-C connector, compact body, touch target, and
  keyring hole.
- Use `site/img/security-key.svg` and the reusable key in `site/img/key-steps.svg` as the
  current shape references.
- Use the antique brass key only in archived concept work; it is not the production
  hardware symbol.
- Do not use the device silhouette as decorative button chrome or repeat it through
  every card.
- Pairing/setup art should show the device, phone, and physical-distance story before
  showing the cat.

Buttons say what happens: `Tap to unlock`, `Cancel: keep apps locked`, and `Lock now`.
Simple text is clearer than a decorative key glyph.

## Visual system

### Color

| Role | Target | Use |
|---|---:|---|
| Pine black | `#0D160D` | Primary dark canvas |
| Deep forest | `#162719` | Cards and inset surfaces |
| Moss | `#3E6B24` | Subtle selected surfaces |
| Fresh moss | `#9BCB63` | Protected state, progress, primary action |
| Warm ivory | `#F4EBCF` | Primary text |
| Sage gray | `#AEB99A` | Secondary text |
| Waiting amber | `#A76816` | Cooling-off state, used sparingly |
| Hardware green | `#3C6A14` | Generic FIDO2 key body and hardware diagrams |
| Connector silver | `#C9DDB4` | USB-C connector and technical detail |
| Quiet danger | `#D77867` | Protection failure only, never relapse history |

These are visual targets, not final implementation values. Every foreground/background
pair must be measured for accessibility in both appearance modes before shipping.

### Type

- Functional UI uses the system sans-serif family.
- Large timers use monospaced system numerals.
- Rounded system numerals may be used for a streak count.
- Hand-drawn display lettering belongs to marketing and rare celebratory art, not core
  controls or explanatory text.
- Prefer sentence case. Uppercase is limited to short state eyebrows such as
  `PROTECTED`, `COOLING OFF`, and `OPEN`.

### Surfaces and spacing

- Use a near-black full-screen canvas and slightly lighter forest cards.
- Cards have restrained one-pixel borders rather than strong shadows.
- Use 20-point page margins and an eight-point spacing grid.
- Large cards use approximately 24–28-point continuous corners.
- Buttons are conventional full-width rounded rectangles with clear text labels.
- Texture belongs inside illustration areas. Text and controls sit on quiet, solid
  surfaces.

### Iconography

Use simple system icons for navigation and common actions. The illustration is already
expressive; interface icons should not compete with it. Avoid mixed icon families,
novelty paw icons, and decorative symbols that do not communicate an action.

## State direction

### Home

The streak or current progress is the visual hero. Pawl is optional, not a persistent
pet. `I'm tempted` is warm and easy to find without reading as a destructive or
emergency action. No unlock action appears here.

Home ships without character art. A corner cameo read as a pasted-on sticker, while a
centered cat competed with the progress number. The ring remains the sole visual hero.

The first cat-heavy style frame is archived at
`design/pawl-cat-v3/styleframes/home.png`; it is not a production reference.

### Apps blocked

The screen communicates protection first, the physical security-key requirement second,
consequences third, and action fourth. If Pawl appears, he is a small supporting mark.
The unlock action lives only in this tab and should use the shipping label
`Tap to unlock`.

The first cat-heavy frame at `design/pawl-cat-v3/styleframes/unlock-locked.png` is an
archived composition study, not a production reference.

When no key is paired, use `design/fido-first/unlock-art/no-key-v1.png`: one modern
generic USB-C/FIDO2 key on its own. Do not fall back to the antique cat-key outline or
introduce a mascot before the hardware mechanism is understood.

### Cooling off

The timer is the hero. The verified-key step and the remaining wait should be
unmistakable without character art. The only action keeps the apps locked. Amber changes
the emotional temperature without turning the state into an alert.

The first cat-heavy frame at `design/pawl-cat-v3/styleframes/unlock-waiting.png` is an
archived composition study, not a production reference.

### Apps open

The timer remains the hero. The green returns, but the screen is controlled rather than
celebratory. `Lock now` is the sole primary action. Character art is optional.

The approved optional art is `design/fido-first/unlock-art/open-v1.png`, paired with the
aligned blink frame. The blink is rare and decorative; the modern FIDO2 key remains visible.

The first cat-heavy frame at `design/pawl-cat-v3/styleframes/unlock-open.png` is an
archived composition study, not a production reference.

## Motion

Motion explains the mechanism and state, not a pet relationship.

- Pairing: one restrained plug/tap cue for the generic FIDO2 key.
- Checking: a short hardware-response indicator, never a playful character loop.
- Waiting: the countdown and progress indicator supply the motion.
- Open: one clear state transition, then stillness.
- Pawl artwork is static by default. A rare blink may remain in the existing code mascot
  during transition, but it is not a promised feature.
- Paired-and-locked artwork may use a brief, infrequent `zz` overlay. Keep the painted
  cat and physical key still, provide no tap response, and disable the loop with Reduce
  Motion.
- Reduce Motion: every state works fully as a still.

Do not animate the character as a reward loop or imply that tapping, caring for, or
customizing Pawl produces a response.

## Voice

Copy is plain, kind, and concrete. State what is happening, when it changes, and what a
button does. Avoid motivational slogans in operational screens. Never imply that a
relapse is a moral failure.

## What to avoid

- An oversized mascot occupying most of an operational screen.
- Any suggestion that Pawl is customizable, collectible, or needs care.
- An antique key used as a substitute for the real FIDO2 security key.
- A security key used as a recurring button shape or decorative pattern.
- Cat illustrations behind timers or body copy.
- Cartoon-kitten proportions, exaggerated anime expressions, or glossy 3D rendering.
- Neon green, heavy glow, glassmorphism, noisy gradients, or game-like badges.
- Paw-print wallpaper and repeated brand ornaments.
- Confetti or triumph language when apps open.
- Mixing Home dashboard actions with the Unlock state machine.
- Treating AI-generated lettering or UI geometry as production-ready specifications.

## Status of the style frames

The four files in `design/pawl-cat-v3/styleframes/` document the rejected cat-heavy
exploration. They are useful for understanding tone, but they are not implementation
targets. Shipping copy, safe areas, Dynamic Type, contrast, localization, and component
behavior must come from the app's real product requirements.

The art direction was explored with the built-in image-generation workflow using the
three source boards in `design/pawl-cat-v3/references/`. Before implementation, the next
design pass should produce:

1. a security-key-first brand bridge showing hardware, state, and character hierarchy;
2. a generic FIDO2 hardware illustration system for pairing, unlocking, and distance;
3. app-icon directions that read as physical-key security before they read as pet;
4. deterministic SwiftUI component specifications derived from the real product flow;
5. light/dark, accessibility, and device-size proofs before replacing shipping art;
6. only then, a decision on whether any additional cat poses are actually needed.
