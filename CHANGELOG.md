# Changelog

## 2.2 (in progress)

- Scheduled block sets. In Settings, What's blocked, add a named set with its own apps and
  sites and a weekly schedule, like a Work set that blocks social apps 9 to 5 on weekdays. When
  a set's hours end its apps open on their own. Your original selection is the always-on set
  and still opens only with your key. Adding a set or adding hours applies right away; fewer
  apps, fewer hours, turning a set off, or deleting one needs your key, your sponsor if linked,
  and the cooling-off wait. Up to ten sets, kept on your phone and in iCloud.
- The "Rate Pawl" row is gone from Settings. Pawl still asks at earned moments only.
- Sound and haptics are gone, along with the Settings toggle for them.
- Fix: when Screen Time access is off, the Unlock tab and the Home status card now say
  "Screen Time is off" instead of claiming apps are blocked.
- Home redesigned. The streak sits inside a ring that fills toward your next milestone, with
  one plain status under it (Protected, no key yet, or Screen Time off). A "What's blocked"
  card shows the real counts and names a scheduled set that is on right now. Logging a relapse
  is a quiet link at the bottom instead of a big button.
- Setup redesigned. Each step is one idea with a picture at the top, the focus choices are a
  grid of cards, and the last step shows a summary of what you are turning on. You can now
  type websites to block right in setup instead of waiting until Settings.
- Logging a relapse is now one question per screen: when it happened (you can pick an earlier
  day), what happened, and whether it cost anything, each skippable. The log is an honor
  system, so any entry can be removed from History and the count is recalculated.
- History on Home now shows urges you rode out next to relapses, each with its note, so what
  you wrote in a tough moment is there to read later. Either kind can be removed.
- The tough-moment screen is rebuilt. The breathing circle is gone. In its place: a ten-minute
  wait timer (urges peak and fade on their own), your own notes from past moments shown back to
  you, your days on track, how many times you have ridden it out, and the hours you have kept.
  Then the log, the call button and the help lines as before.
- Home shows how many times you have ridden out an urge, a number that only goes up and
  survives a relapse. The week card shows the hours you kept this week, from your setup answer.
- Settings is now a short index that fits on one screen. What's blocked, the cooling-off and
  grace timers, and the hard lock each open on their own page, the long explanations moved into
  "How protection works", Screen Time only shows up when it is off, and "Someone to call" has its
  own row under Help instead of hiding inside the explainer.
- Setup starts by asking what you want to block: social media, games, shopping, news, adult
  content, gambling, or something else. Nothing is picked for you. Gambling and adult content
  preset the website filter; everything else starts with the app picker, since Apple does not
  let an app pre-fill it. The welcome screen also shows what your daily hours add up to in a
  year. That number is for you to see and is not saved.
- Home has a "This week" card: seven day dots and plain counts of days Pawl was on, attempts
  it blocked, urges you logged, unlocks with your key, and relapses logged. Counts of zero are
  left out. No score, no grade, no comparison to anyone. It replaces the "Caught this week" card.
- You can now type in specific websites to block (Settings, Websites, Specific websites). One per
  line or pasted as a list. They are blocked right away, in Safari and inside apps, and the list
  comes back after a reinstall through iCloud. Removing a site works like removing an app: key,
  sponsor if you have one, then the cooling-off wait, and the site stays blocked until then.
- In Debug builds, a failed write of the sponsor record now prints to the console instead of
  vanishing. Release builds are unchanged.

## 2.1

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
- Pawl now asks for an App Store rating at earned moments only: a streak milestone, a
  third or later resisted urge, and the first time a sponsor links. Never after an unlock.
  Nothing in the first three days, and at least sixty days between asks. Settings has a
  "Rate Pawl on the App Store" row that always works.
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
