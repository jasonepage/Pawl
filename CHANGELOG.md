# Changelog

## 2.4 (in progress)

Ally approvals, a Pawl Pro feature. The person who holds your key can say yes from their own
phone instead of handing the key over. Plan: `docs/18_Ally_Approvals_Plan.md`. Built one step at
a time, after the rest of 2.4 below.

- Step 0, the unlock loop. `UnlockMachine` has a new state, `awaitingAlly`, and three new
  events: ask the ally, the ally's decision, and the request expiring. A valid yes starts the
  same wait a key tap starts; nothing is ever lifted on a decision. A no, a bad signature, a
  wrong request, a late answer, expiry or cancel all go back to locked and withdraw the
  request. Reaching for the key while a request is open withdraws the request and reads the
  key, so the physical key always works. A request stays open 30 minutes. Fourteen new tests in
  `PawlTests/AllyUnlockMachineTests.swift`; the nine original loop tests are unchanged. The
  Unlock screen shows a plain "Asking your ally" state with a cancel button so the new state is
  never blank, and Pawl waits in that state. No iCloud code yet.
- Step 1, the signature check. `Pawl/Domain/AllyDecisionVerifier.swift` defines the `Request`
  and `Decision` shapes and the exact bytes the ally's phone signs: a fixed label, the request
  id, a random nonce, the answer, and the expiry. The owner's phone checks the ES256 signature
  against the ally's saved public key and refuses a wrong request, a late answer, a flipped
  answer, a stretched expiry, a wrong key or a replay. Fourteen tests in
  `PawlTests/AllyDecisionVerifierTests.swift` with made-up keys. Still no iCloud code.
- Step 2, the iCloud layer. `Pawl/Services/AllyCloud.swift` makes the owner's private `Ally`
  zone, a share for the whole zone (the invite link), and the three records: `allyLink`,
  `request` and `decision`, each with a fixed name so nothing needs a query. The owner's
  phone checks that `allyLink` was written by someone the share was sent to and not by the
  owner's own Apple Account. Removing an ally deletes the zone, instantly.
  `Pawl/Services/AllyStore.swift` keeps the ally's public key on the owner's phone and the
  Secure Enclave signing key on the ally's phone, in the Keychain, this device only. Needs the
  Xcode capabilities in `docs/20_Ally_Xcode_Checklist.md`. Not wired to any screen yet.
- Step 3, the round trip. The owner's Unlock screen can open a request (`askAlly`), which
  writes it to iCloud, polls every 5 seconds for the answer, and also listens for a silent
  CloudKit push. The answer is checked with `AllyDecisionVerifier` against the saved public
  key before the machine ever sees it. The ally's phone gets a banner, "Jason is asking you in
  Pawl.", generic on purpose so nothing about the request rides through Apple's push servers.
  If iCloud is unreachable the request is dropped and the screen says the key still works.
  The app delegate registers for pushes only on phones that are part of a pairing. No button
  calls `askAlly` yet; that is step 4.
- Step 4, the screens. Settings has an Ally page: invite someone with an iCloud share link
  (Messages, Mail, AirDrop), see when they joined, then "Use my key" to make them your ally
  after the usual wait. Remove is instant. The Unlock tab gets an "Ask Sam" button next to the
  key, and an "Asking Sam" state with "Use my key instead" and cancel. Every other change that
  blocks less (removing an app, turning off a category, removing a site, loosening a set, a
  looser timing) now asks "Use my key" or "Ask Sam" when an ally is set up, and shows a waiting
  sheet with a cancel while the request is open. The ally's phone gets a join sheet when the
  link is opened, and an Ally screen (its own tab, or the whole app if they only help someone):
  "Jason wants to unlock Pawl." with Approve (Face ID) and Not now, Pawl waiting beside it, and
  a Stop button. The paywall lists ally approvals first.
- Home is about time back, not days clean (docs/24). The hero says "About 7 hr back this
  week" (or "Blocked 6 of 7 days" when the setup answer is unknown), then plain tiles from data
  Pawl already keeps: unlocked N times and how long apps were open, hit the wall N times, rode
  out N urges, the hardest time of day. An unlock is the slip; nobody types one. The "Log a
  slip" button becomes a small "Log a slip or a note" link at the bottom, for people whose slip
  is off the phone. Zero of anything is left out. The streak ring and milestones are gone from
  Home. New pure `WeekFacts` with tests.
- An open ally request survives switching tabs, leaving the app and a force quit. The Unlock tab
  comes back to "Asking Sam" with its countdown; an expired one is cleaned up.
- The Ally page says up front that inviting needs free iCloud space, which for most free 5 GB
  accounts means a paid iCloud plan. A full iCloud gets a plain message instead of a raw error.
- Pairing your first key is instant, even if blocks are already on. It used to wait 15 minutes
  whenever a commitment existed. The wait stays for a phone where blocks synced from iCloud but
  the key did not (a new phone), because an instant pair there would be a way around the key.
- Fix: the streak now really starts the day you pair a key. 2.4 read the pairing day from
  iCloud but nothing ever wrote it, so Home kept saying 0 days and "your count starts the day
  you pair a key" after pairing. The day is written at the first pairing (and once, at the end
  of setup, if a key was paired during it). A re-pair keeps the original day.
- Security fix: a looser unlock timing (a shorter wait, a longer open time, No wait, Until I
  lock it) now needs your key first, then the current wait, like every other change that blocks
  less. Before this, only the wait applied, so No wait could be set from Settings without the
  key and would land 15 minutes later. The Save button says "Use your key" for a looser change.
- The Unlock tab shows your wait and open time as two big numbers under the status card while
  apps are blocked ("15 min wait", "30 min open", or "Until I lock it"). Tap the card to change
  them; it opens the same Unlock timing screen as Settings, with the same rules.
- The block screen (the "Locked by Pawl" screen iOS shows over a blocked app) shows the new
  icon instead of the old shield drawing.
- New app icon: a green security key with a paw print, with dark and tinted variants. The
  same icon sits in the Settings header, and nothing sits over the streak ring on Home.
- getpawl.com: the hero shows the new painting (the tabby asleep on the key), the how-it-works
  steps use the state art, and a fourth step explains ally approvals. The Pro line mentions
  them. The App Store screenshots on the page still show the old mascot until they are retaken.
- The 2.4 drawn mascot (the brass key with cat ears) is gone from the app, the website, the
  favicon, the link preview image and the repo. The locked and no-key states on the Unlock tab
  use the new painted art; every other state shows one plain symbol until it has its own art. The key is the product.

- Home no longer pitches Pawl Pro. The week card shows the free part and one small "Full report"
  link; the paywall appears only when someone taps that or tries to add a scheduled set.
- Tough-moment screen: "I resisted" moved to the end of the ten-minute wait, where it is
  true, with Pawl's swipe. The form is chips first (Mild, Strong, Overwhelming; bored,
  stressed, lonely, late night, a notification, saw an ad, something else), typing last, and
  "Save this" keeps a draft without counting anything. Saving starts the wait if it is not
  running. The wait and the draft survive leaving the screen. No zero shows at the top. A Done
  button sits above the keyboard, and the save and the count each give a small haptic.
- Build warnings: `ScheduledSet` and the reminder id strings are nonisolated.
- The streak starts the day you pair a key, not the day you installed Pawl. With no key paired
  the home screen shows 0 days and says the count starts when you pair one. A relapse still
  resets it. The week card counts from the same day. Before this, the count ran from the first
  launch, so a phone that never paired a key could show months on track.
- New mascot and app icon: Pawl, an old brass key wearing cat ears, with heavy lids and a
  handlebar mustache. He is drawn in code now (`Pawl/Theme/PawlMascot.swift`, outline in
  `PawlMascotArt.swift`), so he moves: asleep on the job while apps are locked, half-lidded
  with an hourglass during the wait, hands the key over while apps are open, a dashed outline
  until a key is paired. Tap him and a paw floats in and bats an app away. On the urge screen he
  waits with you and swipes when you ride it out. A small Pawl sits over the streak with a halo
  on milestone days. Reduce Motion keeps only the blinks. The app icon is his face on green with
  dark and tinted variants; the site, favicons, link preview and the setup card use him too.
  Design files and the reference drawing live in `design/mascot-v2/`.

- Version 2.4, build 14 (app and all three extensions).
- Unlock timing has more choices. Wait before unlocking: No wait, 15 min to 2 hr, or Custom
  (1 minute to 24 hours). Then open for: 15 min to 3 hr, Custom (15 minutes to 12 hours), or
  Until I lock it. Same rule as before: a longer wait or a shorter open time applies right away,
  and a shorter wait or a longer open time (No wait and Until I lock it included) waits out your
  current wait first. Open times stay at least 15 minutes because iOS won't run a relock timer
  shorter than that.
- Lock now. While apps are open, the Unlock tab has a Lock now button that locks them right
  away. With Until I lock it, that is the only thing that locks them: the screen and the "apps
  are open" reminder say so, and there are no lock reminders. Behind the scenes iOS still gets a
  15 minute window, and the monitor leaves apps open at its end instead of relocking.
- With No wait, Pawl opens apps itself as soon as the key checks out, and the iOS window that
  owns the relock starts a minute later but still ends at the time shown.
- Pairing a new key always waits at least 15 minutes, even with No wait. Re-pairing doesn't need
  the old key, so without this anyone holding the phone and any security key could make it
  "the key" and unlock at once.
- Reopening Pawl during a wait finishes that unlock with the open time it started with, even if
  a timing change landed in between.
- Messages after a change that blocks less say "Removed" or "Saved" when there is no wait,
  instead of "starts in 0 min". Countdowns show hours past an hour. The Settings row and the
  line under Tap to unlock describe the saved timing.
- Tests: TimingOptionsTests (13 new), and the floor test now expects a floor of 0.

## 2.3

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
