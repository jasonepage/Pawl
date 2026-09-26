# Pawl — domain & hosting (`site/`)

This folder is a small static site that (1) serves the file Apple needs for security-key
(WebAuthn) auth — `/.well-known/apple-app-site-association` (AASA) — and (2) is a real
landing page (`index.html`). The `_headers` file pins the AASA content-type so there's
no guessing. Background: `docs/05_Security_Key_Setup.md`.

## Recommended professional setup: Porkbun (registrar) + Cloudflare (DNS + Pages)

Cloudflare is the production-grade choice (global CDN, automatic HTTPS, header control,
DDoS protection). Its hosting tier is free because static hosting is a solved problem —
the budget is better spent on domains and, later, the Apple Developer Program + Phase-2
backend. Total domain spend below ≈ $33/yr.

### 1. Buy the domains (Porkbun)
- [ ] `getpawl.com` (primary). WHOIS privacy is free — keep it on.
- [ ] Defensive (recommended so nobody squats the brand): `trypawl.com`, `pawlapp.com`.
- [ ] Optional: `getpawl.app` (the `.app` TLD forces HTTPS — fitting for a security app).
- If you choose a primary other than `getpawl.com`, it must match in three places:
  `PawlConfig.relyingPartyID`, the `webcredentials:` entry in Xcode, and the AASA `apps` value.

### 2. Put the domain on Cloudflare (free, pro-grade DNS)
1. Create a Cloudflare account → **Add a site** → enter `getpawl.com`.
2. Cloudflare gives you **two nameservers**.
3. Porkbun → your domain → **Authoritative Nameservers** → replace Porkbun's with Cloudflare's.
4. Wait for Cloudflare to show the domain as **Active** (minutes to a couple hours).

### 3. Deploy this `site/` folder (Cloudflare Pages)
1. Cloudflare dashboard → **Workers & Pages → Create → Pages → Connect to Git** → pick this repo.
2. Build settings: **Framework preset = None**, **Build command = (blank)**,
   **Build output directory = `site`**.
3. Deploy. You get a `*.pages.dev` URL with HTTPS automatically.
4. Pages project → **Custom domains → Set up a domain** → `getpawl.com` (and `www`).
   Cloudflare creates the DNS records and certificate for you.

The `_headers` file in this folder makes Cloudflare serve the AASA as `application/json` — done right, no caveats.

### 4. Verify (must be exact, HTTPS, no redirect, no login)
```
https://getpawl.com/.well-known/apple-app-site-association
```
should return:
```json
{ "webcredentials": { "apps": ["8C4BM6A82T.io.github.jasonepage.Pawl"] } }
```

### 5. Tell Xcode about the domain
1. Pawl target → **Signing & Capabilities → + Capability → Associated Domains**.
2. Add: `webcredentials:getpawl.com`
3. `PawlConfig.relyingPartyID` is already `getpawl.com`.

### 6. Test on the iPhone
Plug in the USB-C YubiKey → **Setup → Unlock → Pair security key** → iOS shows its key sheet.
Success = domain + AASA + capability are all correct.

## If you'd rather pay to consolidate on Render (Phase-2 continuity)
Legitimate choice since Phase 2's backend (Supabase/APNs work) can live near it. A Render
**Web Service** (~$7/mo) can serve this folder and host the backend later. Set a header rule
for `/.well-known/apple-app-site-association` → `Content-Type: application/json`. For a
static-only file, though, Cloudflare Pages is the cleaner, faster option.

## The spend that actually matters next
- **Apple Developer Program — $99/yr.** Required to ship and to request the Family Controls
  (Distribution) entitlement. This is the real money item; you likely already have it
  (a team is configured in the project).
