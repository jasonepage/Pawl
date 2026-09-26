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

## 2.0

First open source release.
