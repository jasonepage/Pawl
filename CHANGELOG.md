# Changelog

## 2.3 (in progress)

- Fixed: unlock reminders could still go off after the unlock was cancelled or ended early.
  Cancelling while the reminders were still being set up (for example while the permission
  prompt was showing) let them be added anyway. Now a cancel always wins, apps locking early
  or Pawl finding nothing unlocking drops every reminder still waiting, and if the open time
  starts at a different moment than planned, the lock reminders move to the real lock time.
  The normal "Apps are locked again" still shows at the end of a real unlock. Erase everything
  (developer builds) removes them too. Two new tests.
- A mascot on the Unlock screen: the Stooped Key, an old key with a bent back and a mustache.
  He stands guard while apps are blocked, closes his eyes with a small hourglass during the
  wait, stands up straight and looks away while apps are open, and is a dashed outline until
  a key is paired. Tap him and he does a short dance (a small nod with Reduce Motion on). No
  sound or haptics, and it has nothing to do with unlocking. "Screen Time is off" keeps its
  warning sign. The drawings are vector, so they stay sharp at any size. Two new tests.
- Suggestions for what to block. In setup and in Settings, Websites, popular sites for your
  focus are one-tap chips (for example instagram.com and tiktok.com for social media). Nothing
  is picked for you. Apps show popular names to search for in Apple's list, since Screen Time
  never tells Pawl which apps are installed and can't pick apps for you. Two new tests.
- Unlock reminders. When you start an unlock, Pawl sets reminders on your phone: 5 minutes and
  1 minute before apps open (with a reminder you can still cancel), when they open (with the time
  they lock again), and 5 minutes, 1 minute and the moment before they lock again. Cancelling
  the unlock removes them. Permission is asked the first time you start an unlock. They're local
  to the phone, so there's still no server and no data collected. Two new tests.
- Fixed: if iOS closed Pawl in the background during an unlock, reopening it wiped the
  countdown and showed "Apps are blocked", and during the open time it could re-block your apps
  early. Pawl re-applies your blocks on every launch, and that step used to always mark the state
  as locked. Now it keeps an unlock in progress: during the wait it keeps blocking and keeps the
  countdown, during the open time it leaves apps open, and a window that already ended still
  locks. Four new tests.
- Unlock timing is easier. A picture shows what happens after your key (the wait, then the
  open time, then it locks again). Times are one-tap choices from 15 minutes to 2 hours (wait)
  and 15 minutes to 3 hours (open), with "now" marking your current setting, instead of
  5-minute steppers. The save button only shows after a change, and says whether it applies
  now or after your current wait. Same rules as before.
- Fixed: the gambling site list could turn on by itself. A fresh install or reinstall switched
  it on before setup, and setup then kept it. Now nothing is on until you pick it, except for
  someone already set up with a gambling focus, so a reinstall doesn't drop their protection.
  If setup runs again on a phone that was already protecting you, a category that's already on
  shows as on and locked, with a line saying turning it off needs your key in Settings.
- Fixed: tapping "Pair security key" could look like nothing happened. It now says what to do
  right away, explains why it can't pair (like a phone that was already protecting you) right
  above the buttons, stops with a clear message in the Simulator, and gives up with a reason if
  nothing answers within 90 seconds.
- "When you're tempted" left Settings. The person to call is now added or changed right on the
  "I'm tempted" screen, which already has the call button and the help lines.
- More good moments to ask for an App Store rating: a full week with Pawl on every day and no
  slip, right after buying Pro, and right after the hard lock is set up. Logging an urge from
  Home's "I'm tempted" button now counts too (only the block screen path did before). The same
  limits apply: never in the first 3 days, at least 60 days between asks, each moment once, and
  never on an unlock or a slip. One new test.
- Setup now suggests where to keep your key, right after you pair it (or when you say you
  don't have one yet): someone you trust across town, a time lock box, a bank safe deposit
  box, your desk at work, or mailing it to a friend. Whoever holds the key decides when Pawl
  can open.
- Home is clearer. "This week" sits right under the urge button and shows each day as a dot:
  green when Pawl was on, with a number for urges you resisted that day, and a gray mark (never
  red) for a slip. With Pawl Pro it also shows big numbers for hours back, blocked attempts,
  urges resisted and unlocks, the time of day that was hardest (with a shortcut to add a
  scheduled set for it), the trigger you typed most, and your own words from this week. It
  still never scores, grades or compares, and leaves out anything that was zero. What's blocked
  shows chips and no longer says "Locked by your key" before a key is paired. History is now
  "Recent": four entries, plain days like "Yesterday", press and hold to remove. "Log a slip"
  is gray instead of red. Four new tests.
- Settings is simpler. The logo header is a little smaller, and below it are four plain groups: What's
  blocked (Apps, Websites, Scheduled sets, each its own page), Unlocking (your key, unlock
  timing, hard lock), When you're tempted (someone to call, help lines), and Pawl (Pro, how it
  works, privacy, version). Every row says in one line what it is and how it is set now, so
  "Cooling-off and grace: 15 / 30 min" now reads "Unlock timing: 15 min wait, then open for 30
  min". Website categories are switches. Scheduled sets are one tap from Settings instead of
  two. Nothing about how blocking or unlocking works changes.
- The ally (sponsor) feature and the Supabase server behind it are gone. Your physical key is
  the accountability now: give it to someone you trust and they decide when Pawl can loosen.
  Unlocking and every loosening (removing an app, a site, a category, a set) need the key and
  the cooling-off wait, with no ally approval step. There is no sign-in, no account, no push
  notifications and no background check-in anymore, and Pawl collects no data. The Approvals
  tab, the account screen and the "support someone else" setup path are removed.
- The gambling site list is built into the app: the 167 sites written for Pawl, up from 34. It
  no longer downloads a longer list on launch. A list an older version already downloaded stays
  on the phone.
- The hard lock stays, on the phone and in iCloud only. Its "your ally is alerted" lines are
  gone because nothing sends alerts now.
- Pawl Pro now covers making new scheduled sets and the weekly report. Sets you already made
  keep running and stay editable without Pro. Blocking, the key, the wait, the streak and the
  urge tools stay free.
- On first launch after updating, Pawl quietly clears what the ally feature left behind: the
  saved "this phone has an ally" flag, the old sign-in, and the free-for-life Pro flags. Someone
  who was set up only to approve for others goes through setup. Nothing that blocks is touched.
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
- "Sponsor" is now "ally" in every place a person reads it. (The ally feature itself was then
  removed later in 2.3, see the top of this list.)
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
