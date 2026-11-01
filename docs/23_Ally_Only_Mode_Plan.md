# 23. Ally-only mode (after 2.4)

**Decided 2026-10-31, built 2026-11-01 into 2.4.** A person with no security key can use an
ally (Pro) as their only way to unlock. Adding an ally takes the wait only, never a key tap.

## What it is

Today the key is the only exit. With ally-only mode, a person who never buys a key can still
have Pawl loosen: their ally says yes from their own phone, and the usual wait follows. The
ally is the accountability instead of the key.

A real example: someone sets up blocking, skips the key, and invites their partner as ally. At
1am they tap "Ask," the partner's phone shows "wants to unlock Pawl," the partner taps Not now.
Nothing changes. If the partner taps Approve, the 15 minute wait starts, same as a key tap.

## Rules that do not bend

- The wait is never skipped. An ally's yes starts the wait, never ends it.
- With no key and no ally, there is still no exit on the phone. That stays true.
- Adding an ally is a loosening. With no key to tap, it is gated by the wait alone: invite,
  ally joins, then "Make them my ally" starts the current wait and only then are they active.
- Removing an ally is instant. If the person has no key either, the app says plainly that
  nothing on the phone can unlock now until they pair a key or add an ally.
- Pro is required for the owner. The ally pays nothing.
- The key path does not change at all.

## Changes

1. `AppModel.approveLoosening()`: when no key is paired and an ally is active, skip the key
   prompt and ask the ally. When neither exists, keep the current "Pair your key first."
2. `AppModel.confirmAlly()`: when no key is paired, gate by the wait only.
3. Unlock tab, locked state with no key: show "Ask Sam" as the main button when an ally is
   active, with "Pair a key" as the secondary. Copy under it: "Sam decides. Their yes starts
   the wait."
4. Onboarding "Pair your key" step: a third choice, "I'll use an ally instead (Pro)," which
   opens the Ally page after setup.
5. Home nudge: with no key and no ally, say "Pair a key or add an ally so you can unlock."
6. README, privacy page, store description: "a key or an ally."

## Open question

Whether the no-key, no-ally state should be reachable at all after this ships, or whether
setup should require one of the two before "Lock it in." Decide when building.
