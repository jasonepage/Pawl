# App icon candidate 1

Status: visual direction approved on 2026-10-31. Not wired into the app asset catalog
until matching dark and tinted variants are approved.

Files:

- `app-icon-candidate-v1-source.png`: original 1254 px built-in image-generation output.
- `app-icon-candidate-v1.png`: 1024 px iOS app-icon candidate.

## Direction

The icon reads in this order:

1. a modern physical USB-C/FIDO2 security key;
2. a capacitive touch target;
3. a quiet Pawl signature inside that target.

The enclosure is generic and does not reproduce a commercial key or use a YubiKey
mark. There is no cat face, antique key, pet UI, text, lock, or shield.

## Generation prompt

Built-in image generation, `logo-brand` use case:

> Create a square opaque iOS app icon with no baked-in corner mask. Show one compact
> generic USB-C/NFC security key in a clean three-quarter top view on a deep pine-green
> background. Use a connector-silver plug, dark forest-green body, large circular warm-
> ivory capacitive touch target, and a small keyring hole. Inside the touch target only,
> place one simple cat-paw mark with four toe dots and a central pad. The device must
> read first as security hardware and only second as Pawl. Use a crisp premium
> flat-dimensional product-illustration style with restrained material shading. Keep
> the full device in the central safe area. No text, cat face, ears, eyes, whiskers,
> antique key, gold, lock, shield, phone, hand, cable, NFC waves, watermark, or copied
> commercial enclosure.

## Before shipping

- Test against real home-screen backgrounds and all required icon masks.
- Confirm the touch target and USB-C connector survive at 40–60 px.
- Produce intentional dark and tinted iOS 18 variants; do not derive them blindly.
- Run trademark/product-shape review before release.
