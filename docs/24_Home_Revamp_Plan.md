# 24. Home revamp: time back, not confession

**Status:** plan, 2026-11-01. Jason asked for it after the ally work. Order: ally approvals
(2.4) ships first, then this, then ally-only mode (docs/23) or the other way round.

## The problem

Home is built around a sobriety idea: days clean, a relapse log you fill in by hand. That
fits gambling and porn, where the slip happens off the phone. It does not fit the biggest
group, people fighting TikTok, Instagram, games, shopping. For them Pawl already saw every
slip (the unlock) and every near miss (the block screen). Asking them to type "I slipped" is
tedious and a little humiliating, so nobody does, and Home shows a lie.

## The rule

Home never asks you to report on yourself. It shows what Pawl already knows, in hours and
counts, with no grade. Typing is optional and lives behind one small link.

## What Home shows (all from data Pawl already keeps)

1. **Hero: time back.** "About 7 hr back this week." The number the weekly report already
   estimates (hours the blocked apps were locked, scaled by the person's old daily use from
   onboarding). Big, cream on green. Under it, one line: "Blocked 6 of 7 days."
2. **This week, as facts.** Three or four plain tiles, zero values hidden:
   - Unlocked 2 times, 55 min open (from the unlock log; an unlock is the slip, no typing)
   - Hit the wall 12 times (block screen attempts, already counted)
   - Rode out 3 urges (the "I'm tempted" timer runs you finished)
   - Hardest time: late night (the weekly report already finds this)
3. **The day strip** stays, but a day's dot now means "blocked" or "unlocked that day", not
   "clean" or "relapse". An unlocked day is a fact, not a red mark.
4. **I'm tempted** stays as the one big button. It is the only thing Home asks you to do.
5. **Screen Time, for real (new).** A card that shows Apple's own usage numbers for the
   blocked apps: minutes this week, by day, and the week before Pawl for comparison. Built
   with Apple's `DeviceActivityReport` extension: the numbers render inside the app and never
   reach Pawl's code, so the privacy story does not change. This is the one piece of real new
   work (a fourth extension target, maybe three or four days).
6. **Notes, optional.** "Add a note about today" as a small link under the week, for the
   people whose slip is off the phone. The old relapse sheet becomes that note. It never
   resets anything on its own.

## What goes

- "Days on track" as the hero. It moves to a small line ("Day 44 with Pawl") or goes.
- The relapse button on Home.
- Streak milestones with a halo. The ring becomes the week ring (days blocked of 7).

## Copy rules

Plain and respectful, same as the rest. "Unlocked twice" never "you gave in twice". Zero of
anything is left out, never announced. No comparisons to other people.

## A real example

A TikTok person after one week: hero "About 7 hr back this week. Blocked 6 of 7 days."
Tiles: "Unlocked 2 times, 55 min open", "Hit the wall 12 times", "Rode out 3 urges",
"Hardest: late night". Screen Time card: "TikTok: 48 min this week. Week before Pawl: 9 hr
10 min." They typed nothing.

## Open questions

- Whether "time back" stays an estimate or becomes the real Screen Time number once the
  report extension exists (then it is honest to the minute).
- Whether the gambling and porn setups keep a visible "Log a slip" button on Home. They may
  need it. Could follow the vertical chosen in onboarding.
