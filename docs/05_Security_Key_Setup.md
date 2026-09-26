# Pawl — Security Key (USB-C / FIDO2) Setup

**Decision (2026-06-22):** the physical key is a **USB-C / FIDO2 security key** (e.g. YubiKey) used via Apple's WebAuthn APIs, replacing the NFC passive tag. Reason: NFC tap reliability was poor in testing; USB-C is reliable. (Trade-offs are recorded in the decision log; this doc is the how-to.)

## The one thing this requires from you: a domain + a hosted file

iOS only lets an app use a security key if the key is tied to a **domain you own**, declared as an **Associated Domain**. This is the "domain setup" step. It is **not a backend** — just one static JSON file on HTTPS. Hosting a static file is squarely in your Render wheelhouse.

You need three things to line up. They must all use the **same domain** (the doc assumes `getpawl.com` — change everywhere if you pick another).

### 1. Own the domain
- [ ] Register `getpawl.com` (or whatever you choose). Set `PawlConfig.relyingPartyID` in the app to exactly that host (no `https://`, no path). It's currently `"getpawl.com"`.

### 2. Host the apple-app-site-association (AASA) file
- [ ] Serve this exact JSON at **`https://getpawl.com/.well-known/apple-app-site-association`**:

```json
{
  "webcredentials": {
    "apps": ["8C4BM6A82T.io.github.jasonepage.Pawl"]
  }
}
```

(`8C4BM6A82T` is your Team ID; `io.github.jasonepage.Pawl` is your bundle ID — both pulled from your project.)

- [ ] Requirements Apple enforces: must be **HTTPS**, **no redirects**, served with `Content-Type: application/json`, and reachable at that exact path. A Render static site (or GitHub Pages, Cloudflare Pages, S3+CloudFront) all work. No `.json` extension on the file.
- [ ] Verify after deploy: opening that URL in a browser should return the JSON above.

### 3. Add the Associated Domains capability in Xcode
- [ ] Pawl target → **Signing & Capabilities** → **+ Capability** → **Associated Domains**.
- [ ] Add an entry: **`webcredentials:getpawl.com`**

> ⚠️ Until all three are done, tapping **Pair security key** will error (the message will mention the relying party / domain). That's expected — it's the missing Associated Domain, not a bug in the code.

## What you do NOT need anymore
- ❌ Near Field Communication Tag Reading capability (NFC removed).
- ❌ NTAG215 tags.
- You can delete `Pawl/Services/NFCService.swift` in Xcode (right-click → Delete → Move to Trash); I left it as an empty tombstone.

## Testing the flow (once the domain is live)
1. Plug your USB-C YubiKey into the iPhone (or use an NFC/Lightning one — the OS handles transport).
2. **Setup tab → Unlock → Pair security key.** iOS shows its system key sheet; complete it. The credential ID is stored as your "paired key."
3. **Lock the key away** (the whole point — give it to a sponsor / timebox).
4. **Insert / tap your security key to unlock** → starts the 15-minute cooling-off → shield lifts → auto-relock. Use **"Dev: skip the wait"** to test fast.

## Honest note on the model (HC-7)
We don't run a server in Phase 1, so we don't cryptographically verify the key's signature. We store the registered credential ID and require an assertion returning the **same** credential ID — proof the same physical key is present. That's a sound *possession* gate for this product; the real lock is still that you physically put the key out of reach (HC-4). Full signature verification can come with the Phase-2 backend.

## Heads-up on economics (for later, not now)
A FIDO2 key is ~$30–55 vs a ~$0.30 NFC tag. That changes the hardware story for the eventual product/business model (Phase 3 + pricing decision D4). It doesn't affect building Phase 1 — just flagging so it's on the record.
