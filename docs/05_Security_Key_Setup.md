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
**2.0** stored only the registered credential ID and required an assertion returning the same credential ID. It did not verify the signature.

**2.1** verifies on the phone, with no server (`Pawl/Domain/WebAuthnVerifier.swift`, tested in `PawlTests/WebAuthnVerifierTests.swift`):

1. `clientDataJSON`: `type` is `webauthn.create` or `webauthn.get` as expected, and `challenge` is byte-equal to the fresh 32-byte challenge issued for that request (replay binding).
2. `authenticatorData`: `rpIdHash` equals SHA-256 of `PawlConfig.relyingPartyID`, the User Present flag is set, and the signature counter is strictly greater than the last one stored (skipped only when both are 0).
3. The ES256 signature over `authenticatorData || SHA-256(clientDataJSON)`, using CryptoKit P256 and the public key taken from the attestation object's authenticator data at pairing. The public key comes from `ASAuthorizationSecurityKeyPublicKeyCredentialRegistration.rawAttestationObject` (CBOR; its `authData` holds the COSE key). That property is optional in the SDK; if iOS returns no attestation object, pairing fails with an error instead of saving a key without a public key.

The paired key (credential ID, public key, counter) is stored in the Keychain with `AfterFirstUnlockThisDeviceOnly`. 2.0 values in UserDefaults (`pawl.key.uid`, `pawl.key.pending.*`) are migrated on first launch and then deleted.

**Residual gaps in 2.1:**
- No attestation check. The signature proves it is the same key that was paired, not that the key is genuine hardware from a particular maker.
- Keys paired on 2.0 have no stored public key, and a public key can't be recovered from an assertion. For them, check 3 is skipped until the key is re-paired (re-pairing is still gated by the cooling-off). Checks 1 and 2 still apply.
- Everything runs on the phone. On a jailbroken phone the owner controls the code and the Keychain, so no on-device check holds.
- The key is still only a possession gate. The real lock is that you physically put the key out of reach (HC-4), and iOS still lets the phone's owner turn Screen Time off.

## Heads-up on economics (for later, not now)
A FIDO2 key is ~$30–55 vs a ~$0.30 NFC tag. That changes the hardware story for the eventual product/business model (Phase 3 + pricing decision D4). It doesn't affect building Phase 1 — just flagging so it's on the record.
