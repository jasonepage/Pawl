# 20. Prompt for a fresh session: build ally approvals (Pawl Pro)

Paste this into a new session with the repo folder connected.

---

You are building ally approvals for Pawl, an iPhone app blocker unlocked with a physical
security key. Repo: ~/Documents/GitHub/Pawl-iOS (public at github.com/jasonepage/Pawl).
Read in this order: README.md, docs/18_Ally_Approvals_Plan.md (the full plan, already
approved), docs/01_SRS_Pawl.md section 3, Pawl/Domain/UnlockMachine.swift,
Pawl/Domain/WebAuthnVerifier.swift, Pawl/App/AppModel.swift (approveLoosening), and
Pawl/Services/CloudStore.swift. Jason approved building on 2026-10-29. All six decisions in
plan section 3 stand: an ally's yes replaces the key tap, only the owner needs Pro, no new
product, requests expire in 30 minutes, the ally sees only who is asking and the kind of
request, one ally.

Why: Pawl Pro today is scheduled sets and the weekly report, which is thin. Ally approvals
are the feature that earns the subscription. Jason also wants more than one commitment with
different keys later; that is a separate job, not this one.

Work in the plan's order, section 7, one step at a time, and stop after each step so Jason
can build in Xcode and test. Jason builds in Xcode and sends back errors and screenshots; you
have no compiler. Steps 0 and 1 (the pure state machine and the signature verifier, with
tests) need no Xcode changes and no second phone, so do those first and get the tests green.
Step 2 onward needs the Xcode changes in plan section 4.9 (CloudKit container, push,
background modes, CKSharingSupported). Write out exactly which checkboxes to tick and stop
for Jason to do them.

Rules that do not bend: no Pawl server, no Pawl accounts, the shield never waits on the
network, the wait is never skipped, the three extensions get no network code, the physical
key always works, the free tier does not change. Adding an ally is a loosening (key tap, then
the wait). Removing one is instant. Copy is plain and respectful: "wants to unlock," never
anything that reads as judgment. Use the role name `ally`, never `approver`.

Pawl the mascot (Pawl/Theme/PawlMascot.swift) can appear on the ally's screen in the
`waiting` pose while a request is open and the `resisted` pose after a "Not now." Do not add
new poses.

Writing rules: no em dashes or en dashes anywhere, use periods, commas or colons. Plain
words, short sentences. Follow Jason's saved writing preferences in memory.

Git: Jason does not run commits. One commit per finished step, on main, with everything in
the Changes list. Add a 2.5 section to CHANGELOG.md; this ships after 2.4.

After step 5, update README.md ("Where your data goes" and the Backend row stays "None"),
site/privacy.html section 3 and 5, and docs/01_SRS_Pawl.md with the new requirements.
