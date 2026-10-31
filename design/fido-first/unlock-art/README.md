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
