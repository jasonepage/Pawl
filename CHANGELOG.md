# Changelog

## 2.3 (in progress)

- Under the hood, steps 5 and 6: all five waits are restored one after another on launch, in
  the same order as before, and no leftover timer or save code remains in the app model. The
  app model is about 110 lines shorter. Nothing a person sees changes.
- Under the hood, step 4: removing a typed website and making a scheduled set block less now
  wait through the shared code too, so all five kinds of waiting change use one piece of code.
  Each is saved under a new name, and a wait started on 2.2 is moved over with the exact same
  end time. The key check, the ally step and the messages are unchanged. Two new tests.
- Under the hood, step 3: a looser cooling-off or grace now waits through the shared code. It
  is saved under a new name, and a looser setting started on 2.2 is moved over with the exact
  same end time. Still no key needed for this one, same as before. One small change on launch:
  if that wait already ended while the app was closed, the new setting is now applied before
  the other waits are restored, instead of at the same time. Two new tests, and one existing
  test now also covers durations.
- Under the hood, step 2: turning off a website category now waits through the shared code
  too. The wait used to be saved in three loose settings; it now has its own typed record. A
  turn-off started on 2.2 is moved over on first launch with the exact same end time, so the
  countdown does not change. The key check and the messages are unchanged. Six new tests,
  five of them for the move.
- Under the hood, step 1 of the pending-change cleanup: removing apps now waits out the
  cooling-off through the shared code from step 0. It reads the same saved keys as before, so a
  removal started on 2.2 keeps its countdown after updating. The key check and the messages are
  unchanged. One new test proves the old saved removal still loads.
- Under the hood, step 0 of the pending-change cleanup: one shared piece of code for every
  change that waits out the cooling-off (save, wait, apply, clear), with 14 new tests. Nothing
  uses it yet, so the app behaves exactly as before. Also fixes a test that expected 912 hours a
  year for 2.5 hours a day; the app correctly says 913 (912.5 rounds up).
- Copy pass so Pawl reads as a general app and website blocker. "Log a relapse" is now "Log a
  slip", "Rode it out" is now "Resisted", "clean-day streak" is now "streak", "I'm in a tough
  moment" is now "I'm tempted", and "crisis tools" is now "urge tools". The Settings header now
  says "An app and website blocker you unlock with a physical key." Nothing about how the app
  works changes.
- "Sponsor" is now "ally" in every place a person reads it, including push alerts. Code names,
  database tables and comments still say sponsor. The server push text is changed in this
  branch but is deployed the day 2.3 is approved.
- The problem gambling help link and note show only when gambling is your focus or the gambling
  site list is on. The 988 crisis line always shows.
- The block screen's "I need a minute" button is now "I'm tempted", the same words as the
  button on Home. Its subtitle now ends "No shortcuts, even at 1am."
- The block screen looks like Pawl now: a glowing Pawl shield mark instead of the generic blue
  hourglass, a solid deep green background, and a readable "Close this app" button in light
  green with dark text. The title names what is blocked, like "Instagram is locked", and once
  you have walked away from the block screen this week it says how many times.
- Logging a slip asks "Did it cost anything?" only when gambling or shopping is your focus, or
  the gambling site list is on. Everyone else goes straight from the note to saving.
- No em dashes in any text the app shows. Each one is now a comma, colon or period.
- Small copy fixes on the urge screen, and the VoiceOver hint for "I'm tempted" now describes
  the screen it opens.

## 2.2

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
