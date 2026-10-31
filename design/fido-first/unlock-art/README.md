# Unlock-screen 2D art

Status: implemented on 2026-10-31 for the paired-and-locked Unlock state.

The shipping view adds two restrained, native SwiftUI sleep marks above the still
painting. They rise briefly, pause for several seconds between loops, do not respond to
touch, and are removed entirely when Reduce Motion is enabled. The painting and physical
key do not move.

`locked-v1.png` revives the warm 2D editorial style from
`design/pawl-cat-v3/references/pawl-direction-board.png` without reviving its cat-first
product hierarchy or antique key.

The illustration is designed as supporting art inside the Unlock tab:

- one fixed mature tabby, asleep on duty;
- one recognizable generic USB-C FIDO2 security key;
- transparent background;
- no pet interaction, customization, or implied companion feature;
- no text or UI baked into the asset.

## Generation prompt

Built-in image generation, `stylized-concept` use case:

> Match the warm hand-painted 2D editorial/storybook style of the approved Pawl board
> and the anatomy of the approved tabby model. Create a compact transparent horizontal
> illustration of the mature tabby curled asleep, one paw resting lightly over the
> forest-green generic USB-C security key from the approved icon direction. Keep the
> silver connector, ivory circular touch target with four-toe paw mark, and keyring hole
> visible. Use controlled outlines, simplified fur shapes, restrained gouache/pencil
> texture, and a clear small-size silhouette. No antique key, panel, scenery, text,
> phone, hand, accessories, pet UI, or extra symbols.

The shipping asset uses a dedicated dark hardware surface in both appearances. The
source remains transparent and is supplied at 1x, 2x, and 3x in
`Pawl/Assets.xcassets/PawlUnlockLocked.imageset`.

Do not reuse this painting for no-key, checking, cooling-off, or open states: the cat
guarding a key specifically communicates that a physical key is paired and access is
currently blocked.

## No-key / setup artwork

`no-key-v1.png` replaces the retired dashed antique cat-key silhouette in the unpaired
and registration states. It shows one generic modern USB-C/FIDO2 key, with no cat or
companion behavior. The source is a 1536 × 1024 transparent PNG; the asset catalog
contains 1x, 2x, and 3x versions in `PawlUnlockNoKey.imageset`.

Built-in image generation, `stylized-concept` use case:

> Create a compact transparent in-app illustration of one generic modern USB-C/FIDO2
> security key waiting to be paired. Match the warm hand-painted editorial style of the
> approved locked-state art. Preserve the forest-green body, visible silver USB-C plug,
> warm-ivory capacitive touch target with a subtle four-toe paw mark, and keyring hole.
> Use a calm three-quarter top view and a subtle broken ivory setup halo. No text, UI,
> cat, face, antique key, lock, shield, phone, hand, cable, logo, or extra object.

## Checking artwork

`reading-v1.png` shows the approved modern FIDO2 key approaching a generic phone. The
painting is still; `PawlReadingArtwork` supplies three restrained native SwiftUI signal
rings in the gap between devices. Reduce Motion removes the signal loop.

Built-in image generation, `stylized-concept` use case:

> Create a compact transparent illustration of a generic phone checking the approved
> forest-green USB-C/FIDO2 key. Keep the phone secondary and leave a clean gap for native
> animated read waves. Match the approved warm hand-painted editorial art. No cat, text,
> UI, antique key, hand, cable, baked-in waves, logo, or extra object.

## Apps-open artwork

`open-v1.png` and `open-blink-v1.png` are aligned frames for the unshielded state. Pawl
is awake beside the modern key and gives a rare natural blink. The key stays visible,
there is no tap response, and Reduce Motion holds the base frame.

Built-in image generation, `stylized-concept` plus `precise-object-edit`:

> Create a compact transparent horizontal illustration of the same mature tabby awake
> and calm beside the approved modern FIDO2 key. Keep the key prominent and both eyes
> open in the base frame. Then change only both eyes into a calm closed blink, preserving
> the exact canvas, pose, markings, key, lighting, and alignment.

## Home cameo

`home-cameo-v1.png` and `home-cameo-blink-v1.png` are a tiny protected-state cameo,
not a new hero. `PawlHomeCameo` places it in unused card space at 58 points and performs
one slow blink about every five seconds. It is hidden when protection is off or no key is
paired, and Reduce Motion holds the open-eye frame.

Built-in image generation, `stylized-concept` plus `precise-object-edit`:

> Create a near-square transparent head-and-paws cutout of the mature tabby quietly
> peeking over a card edge, both heavy-lidded olive eyes open, recognizable at 44–64
> points. Then change only both eyes into a natural closed blink while preserving exact
> alignment, anatomy, markings, whiskers, paws, color, and texture.
