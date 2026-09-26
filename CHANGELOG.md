# Changelog

## 2.1 (not on the App Store yet)

A hardening release. The screens, the cooling off wait and the sponsor flow are unchanged.

- The security key check now verifies the key's whole response on the phone: the fresh
  challenge (so an old response can't be replayed), the `getpawl.com` relying party hash,
  the "user present" flag, a signature counter that must go up, and the ES256 signature
  against the public key saved at pairing. See `Pawl/Domain/WebAuthnVerifier.swift`.
- Keys paired on 2.0 keep working. Their signature can't be checked until they are paired
  again, because 2.0 never saved the public key. Everything else is checked.
- The paired key now lives in the Keychain (this device only) instead of UserDefaults.
  2.0 values are moved over on first launch.
- 28 new unit tests for the key check.
- Unlocking now asks the key for the exact credential you paired. Re-pairing the same
  physical key no longer risks the key answering with its old credential.
- While Pawl is protecting you, it now asks Screen Time to require automatic date and
  time, so the clock can't be moved forward to skip the wait. Still being confirmed on
  a device.
- Fixes from our own review of the code and the sponsor server (no one had reported them):
  - The shortest grace window is now 15 minutes. iOS won't schedule a relock window shorter
    than that, so a shorter grace could leave apps unblocked until Pawl was opened again.
    If the relock can't be scheduled, Pawl now stays locked.
  - Signing out, going offline, or switching accounts no longer skips your sponsor.
  - Running setup again on a phone that was already protecting can only add protection. It
    keeps your paired key, your blocks, your durations and your streak.
  - Pairing a key on a new phone while a commitment is active now waits like a re-pair.
  - The automatic relock uses your current block list, including apps you added since.
  - Removing an active sponsor from your own side is turned off. Your sponsor can step down
    from their app, or you can email support@getpawl.com.
  - Server: people can no longer approve their own unlock requests, sponsor themselves, link a
    stranger as a sponsor, edit away alerts, fake a future heartbeat, or dismiss an alert
    while they have a sponsor (supabase/migrations/12_owner_write_lockdown.sql).
  - Background heartbeats now actually run, and every extension has a privacy manifest.
- The buttons on the block screen now work on iOS 18 through 26.4. The block screen
  extension was set to require iOS 26.5 by mistake.

## 2.0

First open source release.
