# Unlock-screen 2D art

Status: visual candidate, not wired into the app.

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

Before implementation, validate the asset on both light and dark card surfaces and crop
transparent padding without clipping whiskers.
