# Pawl — Xcode Setup Checklist

**What this is:** the handful of steps I (Claude) can't do from code — they live in Xcode's GUI or on Apple's website. Everything else (the Swift) is already written. Work top to bottom; each step says *why* it matters so it's not just button-mashing.

**Mental model if you're coming from Render:** there's no server here. "Deploying" = building the app onto a real iPhone with Xcode. Apple's "capabilities" are like toggling add-ons in a dashboard; some (Screen Time) also need Apple to approve your use case, like requesting a quota increase.

**Your project facts:**
- Bundle ID: `io.github.jasonepage.Pawl`
- A development team is already set (`8C4BM6A82T`) — so you likely already have an Apple Developer account. ✅

---

## 0. Prerequisites

- [ ] **Mac with Xcode 16+** (you have it — the project uses Xcode 16 synced groups).
- [ ] **A real iPhone** on iOS 18+ and a USB cable. ⚠️ **Screen Time blocking does NOT work in the Simulator.** You must run on a physical device.
- [ ] **Apple Developer Program membership ($99/year).** Family Controls + CloudKit + running on a device for more than 7 days all need this. If you only have a free Apple ID, the app will run for 7 days at a time but you can't get the Family Controls Distribution entitlement. Check at developer.apple.com — if your team ID shows up there, you're enrolled.

---

## 1. Add the new Swift files to the project (usually automatic)

I created these folders under `Pawl/`:
- `Pawl/Domain/` — models, unlock state machine, repository (pure logic)
- `Pawl/Services/` — AuthorizationService, ShieldService, SelectionStore
- `Pawl/Features/` — ShieldSetupView

- [ ] Open `Pawl.xcodeproj`, confirm these files appear in the left sidebar. Your project uses **synchronized groups**, so files on disk are included automatically — if you see them, you're done. If not, drag the folders into the Pawl group (check "Create groups").

---

## 2. Add the Family Controls capability  ← **the important one (HC-3)**

This is what unlocks the entire blocking ability. Without it, the app compiles but `requestAuthorization` fails at runtime.

- [ ] Select the **Pawl** project in the sidebar → select the **Pawl target** → **Signing & Capabilities** tab.
- [ ] Make sure **"Automatically manage signing"** is checked and your Team is selected.
- [ ] Click **"+ Capability"** (top-left of that tab) → search **"Family Controls"** → double-click to add it.

That's the **development** entitlement — enough to test on your own device right now.

### 2b. Request the DISTRIBUTION entitlement from Apple (do this early — it can take days/weeks)

You only need this to ship on TestFlight/App Store, but the approval is a real waiting period, so start it now.

- [ ] Go to: https://developer.apple.com/contact/request/family-controls-distribution
- [ ] Fill in the form. Describe Pawl honestly: a personal self-control / gambling-recovery tool that uses Screen Time shielding on the user's own device. (Approval is for *your* use case — this is why honest framing in the app matters, NFR-COMP-001/002.)
- [ ] **Tell me once it's submitted** so I can note it on the timeline. Nothing downstream of shipping can proceed until it's granted.

---

## 3. Run the vertical slice on your iPhone

- [ ] Plug in the iPhone, select it as the run destination (top bar, where the simulator name is).
- [ ] Press **▶ Run**. First time: on the phone, go to **Settings → General → VPN & Device Management** and trust your developer certificate if prompted.
- [ ] In the app: tap **"Grant Screen Time access"** → approve the system prompt → tap **"Open app & website picker"** → select a couple of apps/sites → **"Apply shield."**
- [ ] Open a blocked app — you should see it shielded. Tap **"Lift shield (dev only)"** to clear it.

If that works, the core iOS integration is proven. 🎉 (The dev "Lift" button is temporary — in the real product, lifting is gated by the NFC tap + cooling-off timer.)

---

## 3c. Set up the security key (USB-C / FIDO2) — see `05_Security_Key_Setup.md`

NFC was **replaced** by a USB-C / FIDO2 security key (your call, 2026-06-22). This path needs a domain + Associated Domains + a hosted file — all detailed in **`05_Security_Key_Setup.md`**. Short version:

- [ ] Own a domain (e.g. `getpawl.com`) and host the AASA file at `/.well-known/apple-app-site-association` (a static file — Render/GitHub Pages works).
- [ ] Pawl target → **Signing & Capabilities** → **+ Capability** → **Associated Domains** → add `webcredentials:getpawl.com`.
- [ ] You do **not** need the NFC capability or NTAG215 tags anymore.
- [ ] Then: **Unlock → Pair security key** → lock the key away → **Insert / tap your security key to unlock**. The 15-min wait has a **"Dev: skip the wait"** button for testing.

> Like Screen Time, this needs a real device, not the Simulator.

---

## 4. Add a test target (so the unit tests run)

I wrote `PawlTests/UnlockMachineTests.swift` (the executable spec for the unlock loop), but it needs a target to run in.

- [ ] **File → New → Target… → Unit Testing Bundle.** Name it **PawlTests**. Set "Target to be Tested" = Pawl.
- [ ] If Xcode created a sample test file, you can delete it; keep my `UnlockMachineTests.swift`.
- [ ] Press **⌘U** to run tests. They should all pass (they test pure logic — no device needed).

---

## 5. (Optional now) Lower the deployment target to iOS 18.0

The project currently targets iOS 26.5; our spec floor is **18.0** for a broader install base.

- [ ] Pawl target → **General** → **Minimum Deployments** → set to **18.0**. (Skip if you'd rather stay on the latest for now — not blocking.)

---

## What's coming later (so nothing surprises you)

| When | What you'll set up | Notes |
|------|--------------------|-------|
| Next (Phase 1 cont.) | **App Group** capability (`group.io.github.jasonepage.Pawl`) + two **extension targets** (DeviceActivityMonitor, ShieldConfiguration) | I'll give a checklist like this one. Needed for the cooling-off timer + custom block screen. |
| Phase 1 cont. | **CloudKit** capability (iCloud) | For reinstall-proofing. No server, no cost beyond the dev account. |
| Phase 1 cont. | **Near Field Communication Tag Reading** capability + buy a few **NTAG215** tags (~$0.30 each) | For the NFC key. |
| **Phase 2 (months away)** | **Supabase** account + APNs | ⚠️ This is the only "BaaS" step, and it's far off. **I'll tell you clearly when we get here.** You won't need Render. |

**Bottom line for now:** do steps 0–4. The one with a real lead time is **2b** (the Apple entitlement request) — kick that off and let me know.
