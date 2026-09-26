# Software Requirements Specification — Pawl

**Style:** IEEE-830
**Document status:** Draft v0.1
**Date:** 2026-06-22
**Product name:** Pawl (selected — see Name Sprint, `03_Name_Sprint_Shortlist.md`). Formal USPTO Class 9/42 clearance still pending.
**Scope of this revision:** Phase 1 in full detail; Phases 2–3 as lower-fidelity stubs.

> **Reading convention.** Functional requirements are uniquely numbered and written as testable "shall" statements. Where a requirement meets a Hard Technical Constraint, the constraint (**HC-1 … HC-7**, defined in §2.5) is cited inline rather than designed around. Requirements are tagged with a phase: **[P1] / [P2] / [P3]**.

---

## 1. Introduction

### 1.1 Purpose
This SRS specifies the requirements for Pawl, a native iOS commitment-device application that helps people quit gambling by combining Apple Screen Time app/website shielding with a physical NFC key and a mandatory cooling-off timer. It is written for the implementing developer and serves as the contract against which Phase 1 is built and tested.

### 1.2 Scope
Pawl shields gambling-related apps and websites (sportsbook/casino apps, betting/casino web domains, crypto-exchange apps and sites) and makes lifting the shield deliberately difficult. Phase 1 is a **solo, backend-free** application: shield management, NFC-gated unlock with cooling-off, clean-day streak and relapse logging, an urge/panic flow, and CloudKit-backed reinstall-proofing. Accountability (sponsors, tamper alerts) and the hard passcode tier are later phases.

Phase 1 explicitly does **not** include: any server backend, sponsor/remote approval, financial stakes, hardware fulfillment, or Android.

### 1.3 Definitions, acronyms, abbreviations
- **Shield** — an active block applied by `ManagedSettings` to selected apps, categories, and/or web domains. The user cannot remove a shield from iOS Settings; only Pawl can (**HC-4**).
- **Pawl / Key** — the physical passive NFC tag (NTAG215) whose unique hardware UID Pawl verifies on a foreground tap to authorize an unshield (**HC-5, HC-7**).
- **Escrow / self-escrow** — the act of placing the physical key out of the user's easy reach (mailed to a sponsor, locked in a timed container). The friction is the placement, enforced socially/physically, not by software.
- **Sponsor** — a trusted human who (P2) approves unlock requests and (P3) sets the device Screen Time passcode. Optional in the solo-first model.
- **Cooling-off** — a mandatory waiting period that begins *after* a valid key tap and must elapse before the shield actually lifts. Default 15 minutes (configurable upward).
- **Relapse** — a user-recorded event indicating a return to gambling; resets the clean-day streak.
- **Clean-day streak** — consecutive days since the last relapse (or since commitment start).
- **Tamper** — removal of protection via an escape hatch: deleting the app or revoking Family Controls authorization. Detection is delayed by design (**HC-6**).
- **Block set / selection** — the user's chosen apps/categories/domains, held only as **opaque tokens** (`FamilyActivitySelection`); Pawl never learns the underlying app identities (**HC-1**).

### 1.4 References
- Project Brief & Decision Log (`00_Project_Brief_and_Decision_Log.md`).
- Software Design Specification (`02_SDS_Pawl.md`).
- Apple: `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `ManagedSettingsUI`, `CoreNFC`, CloudKit documentation.

### 1.5 Overview
§2 gives the overall description and constraints. §3 specifies Phase 1 functional requirements by feature. §4 covers external interfaces. §5 covers non-functional requirements. §6 stubs Phases 2–3. §7 is the requirements-to-phase traceability matrix.

---

## 2. Overall description

### 2.1 Product perspective
Pawl is a standalone, self-contained iOS application plus two app extensions, sharing state through an **App Group**. In Phase 1 there is no server; the only off-device dependency is the user's private **CloudKit** container, used for resilience against reinstall. The product depends on Apple's Screen Time frameworks for all blocking (**HC-1**) and therefore on Apple granting the Family Controls (Distribution) entitlement (**HC-3**).

### 2.2 Product functions (Phase 1 summary)
- Authorize Family Controls and select apps/categories/domains to shield.
- Apply and maintain a shield that the user cannot lift from Settings.
- Pair a physical NFC key (store its UID).
- Gate every unshield behind a valid key tap **and** a cooling-off timer, then auto-relock.
- Maintain a clean-day streak and a relapse log.
- Provide an urge/panic flow that never offers an immediate unblock.
- Persist commitment state to CloudKit so a reinstall restores the shield.

### 2.3 User classes and characteristics
- **Solo user (primary, P1).** A person trying to quit gambling, motivated but expecting to experience acute urges (notably late at night) during which they will actively try to defeat their own safeguards. Assumed to own one iPhone and to be willing to physically place the key out of reach.
- **Sponsor (secondary, P2+).** A trusted person who approves unlocks and, in P3, sets the Screen Time passcode. Out of scope for P1 functionality.

### 2.4 Operating environment
- iPhone running **iOS 18.0 or later** (Decision D2).
- NFC-capable iPhone with Core NFC tag reading (iPhone 7 and later) — required for the key (**HC-5**).
- An iCloud account signed in on the device (for CloudKit persistence). Behavior when iCloud is unavailable is specified in §3.7.
- No network connection required for core blocking/unlock operation (CloudKit sync is best-effort).

### 2.5 Design and implementation constraints
The Hard Technical Constraints below are binding. Requirements cite them inline.

- **HC-1** Blocking is only via Screen Time API; the app receives opaque tokens, never app identities.
- **HC-2** Native Swift/SwiftUI only; extensions are Swift-only.
- **HC-3** Family Controls (Distribution) entitlement required from Apple; real timeline dependency.
- **HC-4** App shield is Settings-proof and app-removable only; delete/revoke escape hatches are closable only by a Screen Time passcode the app cannot set.
- **HC-5** NFC reads only on user-initiated foreground taps; no background polling.
- **HC-6** No OS event on delete/revoke; tamper detection is delayed (heartbeat, P2+); `authorizationStatus` checkable on launch; shields persist while app not running.
- **HC-7** Hardware is a passive NTAG215; the key is a verified UID, not a cryptographic security key.

### 2.6 Assumptions and dependencies
- **A-1** Apple approves the Family Controls (Distribution) entitlement for this use case (**HC-3**). *All shipping requirements depend on this; if denied, the product is not shippable as specified.*
- **A-2** The user will genuinely place the key out of reach. Software cannot enforce placement (**HC-4, HC-5**); it can only instruct and remind.
- **A-3** The user is signed into iCloud for reinstall-proofing to function.
- **A-4** NTAG215 tags expose a stable, readable UID sufficient to distinguish one key from another for this threat model (**HC-7**).
- **A-5** App Store Review will accept a Family Controls app in the addiction/self-control category; messaging and metadata are crafted to support this.

---

## 3. System features (Phase 1 — functional requirements)

Each feature lists testable "shall" statements. IDs are stable; do not renumber.

### 3.1 Family Controls authorization

- **FR-AUTH-001 [P1]** The system shall request Family Controls authorization via `AuthorizationCenter.requestAuthorization(for: .individual)` before any shield can be configured (**HC-1**).
- **FR-AUTH-002 [P1]** The system shall not present shield configuration UI until `authorizationStatus == .approved`.
- **FR-AUTH-003 [P1]** On every app launch the system shall read `AuthorizationCenter.shared.authorizationStatus` and, if it is not `.approved` while an active commitment exists, shall treat this as a suspected tamper/lapse and enter the Authorization-Lost state (see SDS §6, EDGE-AUTH) (**HC-6**).
- **FR-AUTH-004 [P1]** If authorization is denied, the system shall display an explanation of why blocking cannot function without it and provide a path to re-request, and shall not silently appear functional.
- **FR-AUTH-005 [P1]** The system shall function on a single device with `.individual` authorization and shall not require an MDM/organization configuration.

### 3.2 Shield setup (block-target selection)

- **FR-SHIELD-001 [P1]** The system shall present the Apple `FamilyActivityPicker` for the user to select apps and categories to shield (**HC-1**).
- **FR-SHIELD-002 [P1]** The system shall persist the user's selection only as opaque tokens (`FamilyActivitySelection`) and shall never attempt to derive, store, or display the underlying app or developer identities (**HC-1**).
- **FR-SHIELD-003 [P1]** The system shall allow the user to maintain a web-domain blocklist targeting betting/casino and crypto-exchange domains, applied via `ManagedSettings` web-content shielding.
- **FR-SHIELD-004 [P1]** The system shall ship with a curated default seed list of common sportsbook, casino, and crypto-exchange web domains that the user may accept, edit, or extend.
- **FR-SHIELD-005 [P1]** Upon commitment activation, the system shall apply the shield by setting the appropriate `ManagedSettingsStore` properties (`shield.applications`, `shield.applicationCategories`, `shield.webDomains`) for the selected tokens and domains.
- **FR-SHIELD-006 [P1]** Once a shield is active, the system shall keep it applied across app termination, device restart, and periods when the app is not running (**HC-6**); shield state shall not depend on the app process being alive.
- **FR-SHIELD-007 [P1]** The system shall present a custom block screen for shielded targets via a `ShieldConfiguration` extension, stating that the target is shielded by Pawl and that unlocking requires the physical key plus a cooling-off period (**HC-4**).
- **FR-SHIELD-008 [P1]** The custom block screen shall not provide any control that lifts the shield directly; the only unlock path is the in-app NFC + cooling-off flow (§3.4).
- **FR-SHIELD-009 [P1]** The system shall allow the user to *add* targets to an active shield at any time without a key tap (tightening is always free).
- **FR-SHIELD-010 [P1]** The system shall treat *removing* a target from, or fully deactivating, an active shield as an unlock action subject to the full NFC + cooling-off gate (§3.4) (**HC-4**).

### 3.3 NFC key pairing

- **FR-NFC-001 [P1]** The system shall allow the user to pair a physical NFC key by initiating a foreground `NFCTagReaderSession` and reading the tag's unique hardware UID (**HC-5, HC-7**).
- **FR-NFC-002 [P1]** The system shall store the paired key's UID in the App Group container and (subject to §3.7) in CloudKit, so the same physical key is required for future unlocks.
- **FR-NFC-003 [P1]** The system shall support pairing exactly one active key per commitment in Phase 1, and shall reject an unlock tap whose UID does not match the paired key.
- **FR-NFC-004 [P1]** Re-pairing or replacing the key (e.g., lost key) shall itself be an unlock-class action subject to the cooling-off gate and shall be clearly logged (see SDS §6, EDGE-LOSTKEY), so that swapping in an easy-to-reach key cannot bypass friction (**HC-4**).
- **FR-NFC-005 [P1]** The system shall, during pairing, instruct the user to place the key out of reach (mail to a sponsor / lock in a time-box) and shall record that the placement instruction was shown. The system shall **not** claim to verify that the key was actually placed out of reach (**A-2, HC-5**).
- **FR-NFC-006 [P1]** The system shall handle a pairing tap that reads no tag, an unsupported tag, or a session error by reporting failure and leaving any existing pairing unchanged.

### 3.4 Unlock flow with cooling-off

This is the core loop and the feature that wins the 1am fight. The state machine is: **Locked → (valid tap) → Cooling-off → Unshielded (grace window) → Auto-relock → Locked.**

- **FR-UNLOCK-001 [P1]** To begin an unlock, the system shall require the user to tap the paired physical key in a foreground `NFCTagReaderSession` (**HC-5**); no unlock shall be possible without a successful read.
- **FR-UNLOCK-002 [P1]** The system shall verify the tapped tag's UID against the paired key UID and shall reject the unlock if they do not match (FR-NFC-003).
- **FR-UNLOCK-003 [P1]** Upon a valid tap, the system shall **not** immediately lift the shield; it shall start a cooling-off timer of the configured duration (default 15 minutes) before any shield is lifted.
- **FR-UNLOCK-004 [P1]** The cooling-off duration shall be user-configurable with a minimum enforced floor (default floor 15 minutes); the system shall allow increasing it but shall treat any *decrease* of the cooling-off duration as an unlock-class action subject to the current cooling-off gate, so a user mid-urge cannot shorten their own wait.
- **FR-UNLOCK-005 [P1]** During cooling-off the system shall display remaining time and shall offer the user the option to **cancel** the unlock (cancelling keeps the shield fully active).
- **FR-UNLOCK-006 [P1]** The cooling-off timer shall be persisted (App Group + scheduled via `DeviceActivity`) such that it continues to elapse correctly across app backgrounding, termination, and device restart, and cannot be reset by killing the app (**HC-6**).
- **FR-UNLOCK-007 [P1]** Only after the full cooling-off period has elapsed shall the system lift the shield, by clearing the relevant `ManagedSettingsStore` shield properties.
- **FR-UNLOCK-008 [P1]** When the shield is lifted, the system shall grant a bounded **grace window** (default 30 minutes, configurable) after which it shall automatically re-apply the shield without requiring any user action (auto-relock).
- **FR-UNLOCK-009 [P1]** The auto-relock shall be scheduled via `DeviceActivity`/`DeviceActivityMonitor` so that it fires even if the app is not in the foreground at the end of the grace window (**HC-6**).
- **FR-UNLOCK-010 [P1]** The system shall require a fresh valid key tap and a fresh cooling-off period for each unlock; a single tap shall never authorize more than one grace window.
- **FR-UNLOCK-011 [P1]** The system shall log every unlock attempt (tap accepted/rejected, cooling-off started, cancelled, completed, grace expiry) with timestamps for the relapse/insight history.
- **FR-UNLOCK-012 [P1]** The system shall present, at the moment a key tap is requested, the truth that the user must physically possess the key now — reinforcing that if the key is correctly escrowed, this action is intentionally hard (**HC-4, A-2**).

### 3.5 Clean-day streak & relapse log

- **FR-STREAK-001 [P1]** The system shall compute and display a clean-day streak as the number of whole days since the later of: commitment start, or the most recent relapse event.
- **FR-STREAK-002 [P1]** The system shall allow the user to record a relapse event at any time, capturing a timestamp and optional free-text note and optional amount.
- **FR-STREAK-003 [P1]** Recording a relapse shall reset the clean-day streak to zero and shall be reflected in the relapse log immediately.
- **FR-STREAK-004 [P1]** The system shall display the relapse history as a chronological log and shall persist it to CloudKit (§3.7).
- **FR-STREAK-005 [P1]** The system shall never frame a relapse with shaming language; copy shall be supportive and oriented to continuing the commitment (see NFR usability, §5.4).
- **FR-STREAK-006 [P1]** Recording a relapse shall **not** lift or weaken the shield; honesty in logging must never be coupled to reduced protection.

### 3.6 Urge / panic button

- **FR-URGE-001 [P1]** The system shall provide a prominent, always-available urge/panic action reachable within one tap from the main screen and from notifications.
- **FR-URGE-002 [P1]** The urge flow shall offer at least: a guided breathing exercise, the option to log the urge (timestamp, intensity, optional note/trigger), and supportive content; and shall surface the user's current streak as motivation.
- **FR-URGE-003 [P1]** The urge flow shall **never** present "unblock now" or any control that lifts the shield as a response to an urge (**HC-4** philosophy: the only path is never just "unblock").
- **FR-URGE-004 [P1]** Logged urge events shall be persisted (§3.7) and shall feed the user's insight history (e.g., time-of-day patterns).
- **FR-URGE-005 [P1]** The urge flow shall optionally let the user reach out for help (e.g., a configurable contact or a national problem-gambling helpline link) without lifting the shield.

### 3.7 Reinstall-proofing & persistence (CloudKit only)

- **FR-PERSIST-001 [P1]** The system shall persist commitment state — active selection tokens, web-domain blocklist, paired key UID, cooling-off/grace configuration, streak, relapse log, urge log — to the user's private CloudKit database, and mirror operationally-required state in the App Group local store.
- **FR-PERSIST-002 [P1]** On a fresh install or reinstall, after Family Controls authorization is granted, the system shall fetch existing commitment state from CloudKit and, if an active commitment exists, shall **re-apply the shield automatically** (**HC-4** escape-hatch mitigation within app capability).
- **FR-PERSIST-003 [P1]** The system shall make deleting-and-reinstalling produce **no reduction in friction**: the restored commitment shall require the same physical key and cooling-off as before; reinstalling shall not create an unlocked state.
- **FR-PERSIST-004 [P1]** The system shall use **CloudKit only** for off-device persistence in Phase 1 and shall not introduce Supabase or any custom backend (Decision: BaaS deferred to P2).
- **FR-PERSIST-005 [P1]** If iCloud is unavailable at first run, the system shall still allow a local-only commitment to function, shall warn the user that reinstall-proofing is degraded, and shall sync to CloudKit when it becomes available.
- **FR-PERSIST-006 [P1]** The system shall acknowledge, in honest onboarding copy, that deleting the app or revoking authorization *can* remove protection until reinstall/re-grant, and that the only fix that fully closes this hatch is a sponsor-set Screen Time passcode (Phase 3) (**HC-4, HC-6**). The app shall not overstate its lock strength.

### 3.8 Onboarding

- **FR-ONBOARD-001 [P1]** The system shall, on first run, explain the model honestly: what the shield can and cannot do, the escrow truth (**HC-4**), and the role of the physical key.
- **FR-ONBOARD-002 [P1]** Onboarding shall sequence: explanation → Family Controls authorization (§3.1) → target selection (§3.2) → key pairing + placement instruction (§3.3) → commitment activation (shield applied).
- **FR-ONBOARD-003 [P1]** The system shall require explicit user confirmation to activate the commitment, after which the shield is applied (FR-SHIELD-005).

---

## 4. External interface requirements

### 4.1 User interfaces
- **EI-UI-001 [P1]** The app shall be SwiftUI, iOS 18.0+, supporting Dynamic Type and VoiceOver for core flows (**HC-2**).
- **EI-UI-002 [P1]** The main screen shall show: current streak, shield status (active/cooling-off/grace), the urge/panic action, and entry points to unlock, relapse log, and settings.
- **EI-UI-003 [P1]** The custom block screen (`ShieldConfiguration`) shall be legible, on-brand, and free of any shield-lifting control (FR-SHIELD-007/008).
- **EI-UI-004 [P1]** Moment-of-urge surfaces shall be reachable in one tap and shall not bury the supportive options behind menus (see §5.4).

### 4.2 Hardware interfaces
- **EI-HW-001 [P1]** The app shall read passive NFC tags (NTAG215 target) via `CoreNFC` `NFCTagReaderSession`, using only the tag UID for identity (**HC-5, HC-7**).
- **EI-HW-002 [P1]** The app shall require NFC reads to be foreground and user-initiated and shall not attempt background or ambient tag detection (**HC-5**).

### 4.3 Software interfaces
- **EI-SW-001 [P1]** The app shall integrate `FamilyControls`, `ManagedSettings`, `DeviceActivity`, `ManagedSettingsUI`, and `CoreNFC` (**HC-1, HC-2**).
- **EI-SW-002 [P1]** The app and its `DeviceActivityMonitor` and `ShieldConfiguration` extensions shall share state via a common **App Group**.
- **EI-SW-003 [P1]** The app shall use the user's private CloudKit container for persistence (§3.7).
- **EI-SW-004 [P1]** The app shall declare the Family Controls entitlement and ship under the Distribution entitlement once granted (**HC-3**).

### 4.4 Communications interfaces
- **EI-COMM-001 [P1]** Phase 1 shall require **no** custom server communication. The only network I/O is CloudKit sync and, optionally, opening a helpline URL. (Server comms and APNs are introduced in P2.)

---

## 5. Non-functional requirements

### 5.1 Reliability of shields (highest priority)
- **NFR-REL-001 [P1]** An active shield shall remain enforced across app termination, device reboot, and OS-initiated app suspension (**HC-6**); loss of the app process shall never silently disable a shield.
- **NFR-REL-002 [P1]** The cooling-off timer and auto-relock shall fire reliably via `DeviceActivity` scheduling even when the app is not foregrounded (FR-UNLOCK-006/009).
- **NFR-REL-003 [P1]** After reinstall with an existing CloudKit commitment, the shield shall be re-applied within one app launch (FR-PERSIST-002).
- **NFR-REL-004 [P1]** A failure in non-critical features (streak UI, urge content) shall never cause a shield to drop.

### 5.2 Privacy
- **NFR-PRIV-001 [P1]** The app shall never store, transmit, or display the identities of shielded apps; only opaque tokens shall be handled (**HC-1**).
- **NFR-PRIV-002 [P1]** All Phase 1 personal data (streak, relapse notes, urge logs, key UID) shall reside only on-device and in the user's **private** CloudKit database; none shall be sent to any third party or app-operator server in P1.
- **NFR-PRIV-003 [P1]** The app shall request only the entitlements and permissions it needs (Family Controls, NFC, CloudKit) and shall explain each at the point of request.

### 5.3 Security
- **NFR-SEC-001 [P1]** The app shall recognize and honestly represent the limits of its lock: the shield is strong, but delete/revoke escape hatches exist and are only closed by a Screen Time passcode the app cannot set (**HC-4**). Security copy shall not overstate protection.
- **NFR-SEC-002 [P1]** The key-UID match is the authorization factor for unlocks; the app shall treat a missing/mismatched UID as a hard failure (FR-UNLOCK-002). The threat model accepts that UID is not cryptographically unforgeable (**HC-7**); the real security is physical placement of the key (**A-2**).
- **NFR-SEC-003 [P1]** App Group and CloudKit data shall rely on iOS data protection and the user's iCloud account security; the app shall not weaken these defaults.

### 5.4 Usability at the moment of urge
- **NFR-USE-001 [P1]** From a cold start, the urge/panic flow shall be reachable in ≤ 2 taps and shall render in ≤ 1 second on supported hardware.
- **NFR-USE-002 [P1]** Unlock friction shall be *felt but legible*: the user shall always understand why they are waiting and how long remains (FR-UNLOCK-005), so friction reads as protection, not as a bug.
- **NFR-USE-003 [P1]** Copy throughout relapse/urge flows shall be non-judgmental and recovery-oriented (FR-STREAK-005).

### 5.5 Performance
- **NFR-PERF-001 [P1]** Applying or lifting a shield and reading an NFC tag shall each complete within 2 seconds of the triggering action under normal conditions.
- **NFR-PERF-002 [P1]** App cold launch to main screen shall be ≤ 2 seconds on supported hardware.

### 5.6 App Store review compliance
- **NFR-COMP-001 [P1]** The app shall use Family Controls only for the user's own device self-control use case consistent with the granted entitlement (**HC-3**).
- **NFR-COMP-002 [P1]** The app shall present clear, non-deceptive descriptions of blocking behavior and the escrow truth to support review approval (**HC-4**).
- **NFR-COMP-003 [P1]** The app shall handle gambling-related content responsibly and include appropriate help-resource references (FR-URGE-005).

### 5.7 Maintainability / portability
- **NFR-MAINT-001 [P1]** Phase 1 persistence shall be abstracted behind a repository interface so that adding the Supabase-backed P2 layer does not require rewriting feature code.

---

## 6. Phase 2–3 requirements (stubs)

> Lower fidelity by design. To be expanded when the phase is scheduled and Decision D4 (pricing) is settled.

### 6.1 Phase 2 — Accountability (Supabase + APNs)

> **Status:** promoted from stub to full requirements on 2026-06-22 after the open decisions were confirmed with the owner. IDs are stable; the original umbrella IDs (`FR-P2-ACCT/SPON/HEART/AUTH/NOTIF-001`) are retained and expanded with granular siblings. Design in SDS §3.3, §4.6–4.8; roadmap in `08_Phase2_Plan.md`; owner setup in `09_Supabase_APNs_Setup.md`.

**Confirmed Phase-2 decisions (this drives the requirements below):**

| # | Decision | Choice |
|---|----------|--------|
| D-P2-1 | Source of truth | **Supabase-first**: Supabase is the canonical cloud store and single source of truth for account/commitment/accountability data. The **App Group stays runtime-authoritative** for the live shield/timer (extensions take no network on the hot path); **iCloud KVS is retained as an offline + reinstall cache**. Locked-wins reconcile preserved. |
| D-P2-2 | Auth + sponsor link | **Sign in with Apple**; sponsor linked by redeeming a user-generated, single-use, expiring **invite code / deep link**. |
| D-P2-3 | Approval semantics | **Stacked**: a valid key tap requests sponsor approval; the 15-min cooling-off begins **only after** the sponsor approves. Deny or no-response **timeout → stays locked**. |
| D-P2-4 | Heartbeat | **Opportunistic** (BGTaskScheduler + launch/foreground); tamper alert after **~24h** of silence. |

#### 6.1.1 Accounts & authentication
- **FR-P2-AUTH-001 [P2]** The system shall provide user accounts (Supabase Auth) and enforce Row-Level Security so a user's data and a sponsor's view are correctly scoped.
- **FR-P2-AUTH-002 [P2]** The system shall authenticate users via **Sign in with Apple**, exchanging the Apple identity token for a Supabase session; the app shall store no user passwords (**HC-2**).
- **FR-P2-AUTH-003 [P2]** On first sign-in the system shall create/maintain a `profiles` row keyed to the Supabase auth user id.
- **FR-P2-AUTH-004 [P2]** The system shall enforce Postgres RLS such that a client can read/write only rows it owns and a sponsor can read only rows for commitments explicitly linked to them (FR-P2-LINK-*); a leaked anon key shall not grant access to another user's rows.
- **FR-P2-AUTH-005 [P2]** The core blocking and the solo unlock loop shall continue to function while signed out or offline; shield enforcement shall never depend on a Supabase session (**HC-4, HC-6**, NFR-REL-001).
- **FR-P2-AUTH-006 [P2]** Signing out shall not lift or weaken an active shield.

#### 6.1.2 Sponsor linking
- **FR-P2-LINK-001 [P2]** The system shall let a user generate a single-use, expiring **invite code** (and a shareable deep link) to invite a sponsor.
- **FR-P2-LINK-002 [P2]** A sponsor shall link by signing in and redeeming a valid, unexpired invite code; redemption shall execute **server-side (RPC)** so a sponsor never needs write access to the user's rows (**HC-4** spirit; least privilege).
- **FR-P2-LINK-003 [P2]** The system shall support at most one active sponsor per commitment in Phase 2; replacing a sponsor shall be logged.
- **FR-P2-LINK-004 [P2]** Either party shall be able to revoke a sponsor link; revocation shall downgrade the commitment to solo mode (cooling-off only), shall be disclosed honestly as a reduction in accountability, and shall **not** lift the shield.
- **FR-P2-LINK-005 [P2]** A commitment shall be in sponsor mode **only while** an active sponsor link exists; otherwise the unlock flow uses the solo cooling-off path (FR-UNLOCK-003). This keeps the product shippable for users with nobody to ask yet (Decision D1 solo-first is preserved as the fallback).

#### 6.1.3 Sponsor-gated unlock (stacked approval)
- **FR-P2-SPON-001 [P2]** The system shall support a sponsor-mode commitment in which each unlock request is pushed (APNs) to the sponsor who approves or denies before the shield lifts.
- **FR-P2-SPON-002 [P2]** In sponsor mode, upon a valid key tap (FR-UNLOCK-002) the system shall create an `unlock_request`, notify the sponsor (FR-P2-NOTIF-*), and enter **Awaiting-Approval**; it shall **not** start the cooling-off or lift the shield at this point (**HC-4**).
- **FR-P2-SPON-003 [P2]** The system shall start the cooling-off timer (FR-UNLOCK-003) **only after** the sponsor approves — approval **stacks before** the wait (Decision D-P2-3).
- **FR-P2-SPON-004 [P2]** On a sponsor **denial** the system shall keep the shield fully applied and return to Locked.
- **FR-P2-SPON-005 [P2]** If the sponsor does not respond within a configurable approval window (**default 60 min**) the request shall expire and the system shall remain Locked (fail-safe, **HC-4**).
- **FR-P2-SPON-006 [P2]** The user shall be able to cancel a pending request; cancellation shall resolve the request server-side and keep the shield applied.
- **FR-P2-SPON-007 [P2]** A single approval shall authorise exactly one cooling-off → grace cycle (consistent with FR-UNLOCK-010); a fresh tap **and** fresh approval shall be required for the next unlock.
- **FR-P2-SPON-008 [P2]** The sponsor shall be shown enough context to decide (requesting user, time, current streak) **without** exposing private journal content (urge/relapse free-text notes) (NFR-PRIV).
- **FR-P2-SPON-009 [P2]** If the device is offline at tap time in sponsor mode, the system shall **not** lift the shield; it shall report that approval cannot be requested and remain Locked (**HC-4**).

#### 6.1.4 Heartbeat & tamper detection
- **FR-P2-HEART-001 [P2]** The app shall send a periodic heartbeat to the backend; the backend shall detect a silent client (revoked authorization or deleted app) and notify the sponsor of suspected tamper (**HC-6** — the only viable mechanism; there is no OS event for delete/revoke).
- **FR-P2-HEART-002 [P2]** The app shall send an authenticated heartbeat (device id + timestamp + authorization status) on launch, on foreground, and opportunistically via **BGTaskScheduler** (DeviceActivity is for shielding, not networking).
- **FR-P2-HEART-003 [P2]** The backend shall record the last heartbeat per device and, via a scheduled Edge Function, flag any **sponsor-mode** device silent longer than the silence threshold (**default 24h**) as suspected tamper (**HC-6**).
- **FR-P2-HEART-004 [P2]** On detected silence the backend shall raise a `tamper_alert` and notify the linked sponsor via APNs (FR-P2-NOTIF-*).
- **FR-P2-HEART-005 [P2]** On launch the app shall read `AuthorizationCenter.shared.authorizationStatus`; if it is not approved while an active commitment exists, the app shall send an authorization-lost tamper signal in addition to the launch heartbeat (extends FR-AUTH-003, **HC-6**).
- **FR-P2-HEART-006 [P2]** Because BGTaskScheduler delivery is best-effort and throttled, the silence threshold shall be tolerant enough to avoid false tamper alerts (Decision D-P2-4).
- **FR-P2-HEART-007 [P2]** The system shall not represent the heartbeat as *preventing* tampering; it detects and alerts after the fact only (**HC-4, HC-6**), and copy shall say so.

#### 6.1.5 Notifications (APNs)
- **FR-P2-NOTIF-001 [P2]** The system shall use APNs for unlock-request, approval/denial, and tamper notifications.
- **FR-P2-NOTIF-002 [P2]** The app shall register for remote notifications and store the APNs device token in `devices`, scoped to the signed-in user.
- **FR-P2-NOTIF-003 [P2]** The backend shall send pushes for: unlock-request (→ sponsor), approval/denial (→ user), and tamper alert (→ sponsor).
- **FR-P2-NOTIF-004 [P2]** Approve/Deny shall be actionable from the notification where possible, with the decision applied server-side via RPC (FR-P2-LINK-002 least-privilege pattern).

#### 6.1.6 Server-side WebAuthn verification (optional — closes the P1 simplification)
- **FR-P2-WAUTH-001 [P2]** The system *may* verify security-key assertions server-side (relying-party verification of signature, challenge, and sign-count), replacing the P1 "same credential ID returned" possession proxy (closes the gap noted in HANDOFF §2).
- **FR-P2-WAUTH-002 [P2]** Registration shall persist the credential public key server-side; assertions shall be verified against it using a **server-issued challenge** (anti-replay).
- **FR-P2-WAUTH-003 [P2]** When server-side verification is enabled, a sponsor-mode unlock shall require a server-verified assertion **before** the sponsor is notified.

#### 6.1.7 Source of truth, sync & privacy
- **FR-P2-SYNC-001 [P2]** Supabase shall be the canonical source of truth for account, commitment-definition, sponsor-link, unlock-request, approval, heartbeat, and tamper data (Decision D-P2-1).
- **FR-P2-SYNC-002 [P2]** The App Group store shall remain runtime-authoritative for the live shield/timer state that extensions read on the hot path; extensions shall take **no** network dependency (SDS §1.3, **HC-6**, NFR-REL-002).
- **FR-P2-SYNC-003 [P2]** iCloud KVS shall be retained as an offline + reinstall cache so reinstall-proofing (FR-PERSIST-002/003) keeps working without network.
- **FR-P2-SYNC-004 [P2]** Reconciliation between Supabase and the local caches shall preserve the **locked-wins** policy (`CommitmentReconciler`): a stale unlocked record shall never override an active shield (FR-PERSIST-003).
- **FR-P2-SYNC-005 [P2]** A `SupabaseCommitmentRepository` shall implement the existing `CommitmentRepository` protocol so feature code is unchanged (NFR-MAINT-001).
- **FR-P2-PRIV-001 [P2]** Moving sponsor-linked data server-side **supersedes the P1 "private CloudKit only" stance (NFR-PRIV-002) for Phase 2**; the system shall disclose that sponsor-linked data resides in Supabase, scope all access via RLS, and keep the private recovery journal (urge/relapse free-text notes) **user-only and not sponsor-readable**.

### 6.2 Phase 3 — Hard tier + product
- **FR-P3-HARD-001 [P3]** The system shall guide a sponsor through setting the device's Screen Time passcode (performed manually by the sponsor in iOS Settings — the app cannot set it) to close the delete/revoke escape hatches and create the only truly unfakeable tier (**HC-4**).
- **FR-P3-STAKE-001 [P3]** The system shall support financial stakes tied to relapse/commitment outcomes (mechanism and provider TBD with Decision D4).
- **FR-P3-SKU-001 [P3]** The system shall support a physical key SKU and fulfillment (NTAG215 tag personalized to a user/commitment), priced per the business model (Decision D4).
- **FR-P3-HARD-002 [P3→promote to P2] CONFIRMED WORKING — ship it.** On-device spike (2026-06-23, real iPhone, individual Screen Time auth): `ManagedSettingsStore(named: .pawl).application.denyAppRemoval = true` **blocks true uninstall**. The Home-Screen long-press still shows "Remove App," but inside it the **"Delete App" option is removed** — only "Remove from Home Screen" remains, which leaves Pawl installed in the App Library with the shield still running. (Initial reading mistook the menu label for a no-op; the actual delete is blocked.) The app shall set `denyAppRemoval = true` whenever an active commitment exists, and keep it set through grace cycles (set at activation + re-assert on launch; do **not** clear it in `SharedShield.lift()`). Honest-copy constraint (**HC-4**, FR-P2-HEART-007): this blocks the casual long-press delete, **not** an absolute lock — a user can still revoke Family Controls in Settings → Screen Time (no passcode), which wipes it along with the shield; the only absolute lock remains the sponsor-set Screen Time passcode (FR-P3-HARD-001) or `.child` enrollment (D-P3-1). Net: a real friction tier above Gamban's openly-easy uninstall, below the passcode tier.

**Open Phase-3 decision — D-P3-1 (hard-lock mechanism).** Two distinct paths create real, second-party prevention on iOS; pick or combine after evaluation:
  - **(a) Sponsor-set Screen Time passcode** (FR-P3-HARD-001) — guided in-person at setup (confirmed direction). The app cannot set it; protects Content & Privacy restrictions *and* the Family-Controls-revocation toggle. Works on any device; depends on the sponsor being present (RG-desk model).
  - **(b) `.child` Family Sharing enrollment** — under `.child` authorization, `denyAppRemoval` and related restrictions actually enforce and are guardian-controlled (not self-revocable). Upside: real OS-level prevention. **To evaluate:** Family Sharing child-account age/Apple-ID eligibility and UX constraints for *adult* sponsor relationships; may not fit the target user.
  These are second-party models by necessity: no consumer iOS app — including the market leader (Gamban) — can make itself truly undeletable without MDM/Supervision, `.child`, or a human-held passcode. See `Competitive_Comparison.md`.

**Open Phase-3 decision — D-P3-2 (network-layer website blocking).** Evaluate a `NEFilterDataProvider` / DNS content-filter profile (Tier 2 of `Blocklist_Expansion_Plan.md`) to complement Screen Time app-shielding: it blocks websites far more robustly and (like Gamban's VPN profile) keeps filtering even if the app is deleted. Target combo = Family Controls for **apps** + content-filter for **sites**, which would exceed Gamban's coverage. Cost: new entitlement, heavier App Store/privacy review, battery review. Justify against a partner/revenue case (Decision D4).

---

## 7. Traceability matrix (requirements → phase & constraints)

| Requirement group | IDs | Phase | Key constraints |
|---|---|---|---|
| Family Controls authorization | FR-AUTH-001..005 | P1 | HC-1, HC-6 |
| Shield setup | FR-SHIELD-001..010 | P1 | HC-1, HC-4, HC-6 |
| NFC key pairing | FR-NFC-001..006 | P1 | HC-5, HC-7, HC-4 |
| Unlock + cooling-off | FR-UNLOCK-001..012 | P1 | HC-4, HC-5, HC-6 |
| Streak & relapse | FR-STREAK-001..006 | P1 | — |
| Urge / panic | FR-URGE-001..005 | P1 | HC-4 (philosophy) |
| Reinstall-proofing | FR-PERSIST-001..006 | P1 | HC-4, HC-6 |
| Onboarding | FR-ONBOARD-001..003 | P1 | HC-1..HC-7 |
| External interfaces | EI-* | P1 | HC-1, HC-2, HC-3, HC-5 |
| Non-functional | NFR-* | P1 | HC-1, HC-4, HC-6 |
| Accounts & auth | FR-P2-AUTH-001..006 | P2 | HC-2, HC-4, HC-6 |
| Sponsor linking | FR-P2-LINK-001..005 | P2 | HC-4 |
| Sponsor-gated unlock | FR-P2-SPON-001..009 | P2 | HC-4 |
| Heartbeat & tamper | FR-P2-HEART-001..007 | P2 | HC-6, HC-4 |
| Notifications (APNs) | FR-P2-NOTIF-001..004 | P2 | — |
| Server-side WebAuthn | FR-P2-WAUTH-001..003 | P2 | HC-7 |
| Source of truth / sync / privacy | FR-P2-SYNC-001..005, FR-P2-PRIV-001 | P2 | HC-4, HC-6 |
| Hard tier + product | FR-P3-* | P3 | HC-4, HC-7 |

**Entitlement dependency (cross-cutting):** every shippable P1 requirement depends on **A-1 / HC-3** (Family Controls Distribution entitlement approval).

---

## 8. Requirements that depend on unconfirmed decisions (flagged)

- **Pricing (D4):** FR-P3-STAKE-001, FR-P3-SKU-001 — cannot be fully specified until D4 is settled.
- **Naming:** Bundle identifier, App Store name, and trademark posture depend on the naming exercise (Project Brief §6). Does **not** block P1 engineering under the codename.
- **Sponsor scope:** Confirmed solo-first for P1 (D1); sponsor requirements live in P2/P3 only.
