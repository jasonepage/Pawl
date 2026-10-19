# Archived docs

These describe parts of Pawl that were removed in 2.3 (October 2026). They are
kept for history only. Do not follow them to set anything up.

In 2.3 the ally (sponsor) feature and the Supabase server behind it were taken
out. That removed sign-in, accounts, invite codes, ally approval of unlocks,
push notifications, heartbeats and tamper alerts. The physical key is the
accountability now: whoever holds it decides when Pawl can loosen.

| File | What it was |
|---|---|
| `08_Phase2_Plan.md` | The plan for the server-backed ally feature |
| `09_Supabase_APNs_Setup.md` | Setting up the Supabase project and Apple push |
| `10_EdgeFunctions_Push.md` | The server functions that sent push alerts |
| `11_Phase3_Passcode.md` | The hard lock design. **The hard lock itself is still in the app**, recorded on the phone and in iCloud only. Everything here about server records and tamper alerts is gone. |
| `Two_Phone_Verification.md` | The two-phone test for ally approvals and tamper alerts |
| `Build_Checkpoint_Smoke_Test.md` | The build and smoke test for the server-backed build |

The server code itself (`supabase/`) was deleted from the repo in the same
change. It is still in Git history before the commit that removed it.
