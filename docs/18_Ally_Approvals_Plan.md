# 18. Ally approvals over iCloud (plan for 2.4)

**Status:** plan only. No code until Jason approves this plan. The build also waits until
Pawl Kits are selling (step 1 of the money plan), unless Jason decides otherwise.
**Date:** 2026-10-28.

---

## 1. What it does

Today the only way to loosen Pawl is to tap the physical key, then wait. Whoever holds the
key decides. Ally approvals let that person say yes from their own phone instead of handing
the key over.

A real example of how it would look: Jason's sister across town holds his key. At 1am he
taps Unlock in Pawl and picks "Ask my ally." Her phone shows "Jason wants to unlock Pawl."
She opens it and taps Approve, then confirms with Face ID. Jason's 15 minute wait starts,
exactly as if he had tapped the key. If she taps "Not now," or does nothing for 30 minutes,
nothing changes and his apps stay blocked.

The same thing works for every other change that blocks less: removing an app, turning off a
website category, removing a typed site, loosening or deleting a scheduled set.

## 2. Rules this plan keeps

1. **No Pawl server.** Everything goes through Apple's iCloud (CloudKit). Nothing runs that
   Jason pays for or keeps on.
2. **No Pawl accounts.** Both people use the Apple Account already on their phone. There is
   no sign-in screen.
3. **No new data reaches Jason.** Requests and answers live in the owner's own iCloud. The
   developer cannot read them.
4. **The physical key still works**, always, with or without an ally.
5. **The free tier does not change.** Blocking, the key, the wait, the streak and the urge
   tools stay free and serverless.
6. **Pro's current features do not change.** Scheduled sets and the weekly report stay as they
   are. Ally approvals are added to Pro.
7. **The shield never waits on the network.** Blocking stays local. The three extensions
   (block screen, block screen buttons, schedule monitor) get no network code.
8. **The wait is never skipped.** An ally's yes starts the same cooling-off a key tap starts.

## 3. Decisions for Jason

Each has a recommendation. Nothing gets built until these are picked.

| # | Question | Recommended | Other choice |
|---|---|---|---|
| D1 | Does an ally's yes **replace** the key tap, or come **on top of** it? | **Replace.** Key tap or ally yes, then the wait. That matches "a key holder approves from their own phone." | On top: key tap and ally yes, then the wait. Stricter, but the 1am person needs the key in hand anyway, so the ally adds little. |
| D2 | Who needs Pro? | **Only the person being protected.** The ally pays nothing and needs no Pro. | Both need Pro. Fewer people would agree to be an ally. |
| D3 | What is the "family plan"? | **No new product in 2.4.** Ship ally approvals inside the current Pro and see if people use them. | (a) A new "Pawl Pro Family" product with Apple Family Sharing turned on, leaving current Pro untouched. (b) Turn on Family Sharing for the current Pro. Apple: "once you turn on Family Sharing for an In-App Purchase in App Store Connect, you can't turn it off." |
| D4 | How long does a request stay open? | **30 minutes.** Long enough for a real yes, short enough that a 1am request is gone by morning. | 15 or 60 minutes. |
| D5 | What does the ally see? | **Only the minimum:** who is asking, "unlock" or "block less," and the time. | Also show the streak. Not recommended: it turns a yes or no into a judgment. |
| D6 | How many allies? | **One** in 2.4. | Two or more. More sharing and more screens to build. |

The rest of this plan assumes the recommended choices. If D1 goes the other way, section 4.4
flips (see the note there).

## 4. How it works

### 4.1 Where the data lives

- The protected person (the **owner**) gets a private iCloud zone named `Ally` in Pawl's
  iCloud container. Only their Apple Account owns it.
- The owner shares that one zone with the ally using Apple's zone sharing (`CKShare`). The
  invite is a normal iCloud share link the owner sends by Messages or any other way.
- The ally taps the link, Pawl opens on their phone, and Apple adds them to the zone. The
  ally sees the zone in their own shared iCloud database.
- Nobody else, including the developer, can read the zone.

### 4.2 Records

| Record | Written by | Fields | Kept for |
|---|---|---|---|
| `AllyLink` | ally, once at pairing | ally's public signing key, ally's first name (typed by the ally) | until the ally is removed |
| `Request` | owner | request ID, kind (`unlock` or `blockLess`), created time, expiry time, random nonce | until answered or expired, then deleted |
| `Decision` | ally | request ID, approved yes or no, signed time, signature | deleted by the owner's phone once read |

No app names, site names, slips, urges, notes or streak numbers go in any record. Pawl
cannot read app names anyway, because Screen Time only hands it opaque tokens.

### 4.3 Proving the yes came from the ally

The owner can write to their own zone, so a "yes" record alone is not proof. So:

1. At pairing, the ally's phone makes a signing key in its Secure Enclave (CryptoKit
   `SecureEnclave.P256.Signing.PrivateKey`). The private half never leaves that phone.
2. The public half goes to the owner's phone in the `AllyLink` record. The owner's phone
   saves it in its own Keychain (this device only). That saved copy is the one that counts.
3. Every `Decision` is signed over: request ID, nonce, approved yes or no, and expiry time.
4. The owner's phone checks the signature against its saved copy, checks the nonce and request
   ID match an open request, and checks it has not expired. Only then does the wait start.
5. Changing the saved public key means changing the ally, which follows section 4.4.

This uses the same idea as the key check in `WebAuthnVerifier.swift`: the phone verifies a
signature against a key it saved when you paired.

What this does not stop: a jailbroken phone, or someone building Pawl themselves in Debug.
The README already says that about the key check, and the same sentence applies here.

### 4.4 Adding and removing an ally (the asymmetry rule)

With D1 = replace, an ally is **another way to loosen**. So:

- **Adding an ally blocks less.** It waits like any other loosening: key tap, then the
  cooling-off, then the ally becomes active.
- **Removing an ally blocks more.** It applies right away, no key needed. The owner can cut an
  ally off at any moment.
- **The ally leaving** (stop sharing in iCloud) also applies right away. The owner's phone
  shows "Your ally left. Your key still works."

If D1 = on top instead, this flips: adding an ally applies right away, and removing one is
gated like a loosening.

### 4.5 The unlock loop

`UnlockMachine` stays a pure function with no iOS code. Changes:

- New state `awaitingAlly(requestID, expiresAt)`.
- New events `askAlly`, `allyDecision(requestID, approved, valid)`, `allyExpired`.
- `locked` + `askAlly` goes to `awaitingAlly`, with a new effect `sendAllyRequest`.
- `awaitingAlly` + a valid, approved decision for that request goes to `coolingOff`, the same
  as an accepted key tap today.
- A no, an invalid signature, a wrong request ID, expiry or cancel goes back to `locked`, with
  an effect `withdrawAllyRequest` that deletes the request.
- Anything unexpected is a no-op, as now. The shield never drops as a side effect.

For the other loosenings, `AppModel.approveLoosening()` becomes "key or ally." The person
sees two buttons: "Use my key" and "Ask my ally." The ally path returns true only after a
valid signed yes. Everything after that (the pending change and its wait) is unchanged, so
`PendingChange.swift` does not change.

### 4.6 Notifications without a server

- The ally's phone subscribes to its shared iCloud database (`CKDatabaseSubscription`).
  When the owner writes a `Request`, Apple's own push service tells the ally's phone, and
  the subscription's alert text shows "Jason wants to unlock Pawl."
- The owner is usually watching the Unlock screen while waiting, so their phone checks for a
  `Decision` while the screen is open, and also subscribes to its private database for when
  the app is in the background.
- Apple does not promise every push arrives. The ally can always open Pawl and see any open
  request on its first screen.

### 4.7 What the ally's phone needs

- Pawl installed and signed in to iCloud. No blocking set up, no Screen Time permission, no
  key, no Pro.
- A small "I'm an ally" mode: one screen listing the person they help, any open request with
  Approve and Not now, and a Leave button. Use a new role name `ally`. Do not reuse
  `approver`, because 2.3's `retireApproverRole()` resets anyone saved as `approver`.

### 4.8 Pro

- Asking an ally needs the owner's Pro to be active.
- If Pro ends, the "Ask my ally" button goes away and the key still works. That only makes
  Pawl stricter, so nothing that is already blocking turns off.
- Pairing an ally needs Pro. The ally side never checks Pro.

### 4.9 Xcode changes

- iCloud capability: add the CloudKit service and a container, for example
  `iCloud.io.github.jasonepage.Pawl`. Today the entitlement lists no containers and only
  uses iCloud key-value storage.
- Push Notifications capability (`aps-environment`).
- Background Modes: Remote notifications.
- Info.plist: `CKSharingSupported` = YES, so share links open Pawl.
- In the CloudKit Dashboard, deploy the schema to Production before the App Store build.

## 5. Privacy

- README "Backend" row stays "None." Add a row to "Where your data goes": ally requests and
  answers live in your iCloud, shared only with your ally, deleted after each answer.
- privacy.html section 3 gets the same line. Section 5 says your ally sees only requests.
- App Store privacy label: likely stays "Data Not Collected," since the developer cannot read
  a user's private iCloud data. **Unconfirmed.** Check Apple's privacy label definitions
  before submitting.

## 6. Safety

- Pawl is not a monitoring tool. The ally never sees what is blocked, how often someone opened
  a blocked app, slips, urges, notes or the streak.
- The owner can remove the ally instantly and still has the key.
- The ally cannot block anything, unblock anything, or change any setting. They can only
  answer a request.
- Copy follows the tone rules: plain and respectful, never punishing. The request says "wants
  to unlock," never "is trying to break their commitment."

## 7. Build steps (each one checked before the next)

| # | Step | Check before moving on |
|---|---|---|
| 0 | Pure machine: new states, events, effects | New `UnlockMachineTests` pass; the 9 old ones still pass unchanged |
| 1 | Signature format and verifier | Tests with made-up keys: good yes, good no, wrong key, wrong nonce, expired, replayed |
| 2 | iCloud zone, share link, records | Two phones on two Apple Accounts: owner shares, ally joins, both see the zone |
| 3 | Push to the ally, answer back to the owner | Two phones: request shows on the ally's lock screen; yes starts the owner's wait within a minute |
| 4 | Screens: owner's Ally page, the two buttons, the ally's screen | Every loosening path offers both buttons; removing the ally is instant; adding waits |
| 5 | README, privacy page, CHANGELOG, App Store notes | Read through for tone and accuracy |

Steps 0 and 1 have no iOS dependencies and can be tested without a second phone.

## 8. Unknowns

- Whether accepting an iCloud share needs iCloud Drive turned on for Pawl. Test on step 2.
- How long CloudKit pushes take in practice. Test on step 3.
- The App Store privacy label question in section 5.

## 9. Not in 2.4

- Silence alerts, which tell an ally when Pawl stops reporting. That is step 3 of the money
  plan, starting with an email waitlist only, and it would need something always on.
- More than one ally.
- Any change to how blocking, the key, or the wait work.
