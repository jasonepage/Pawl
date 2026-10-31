# 2.4 App Store notes (draft)

## What's new (release notes field)

Ally approvals, for Pawl Pro. The person who holds your key can now say yes from their own
phone instead of handing the key over. Their yes starts the same wait your key starts. Nothing
is skipped. It goes through your own iCloud, never a Pawl server, and your ally never sees what
you block. Only you need Pro.

Also in 2.4:
- Unlock timing has more choices: any wait from none to 24 hours, any open time from 15 minutes
  to 12 hours, or until you lock it. Lock now ends the open time early.
- Your first key pairs right away, even with blocks already on. The streak now starts the day
  you pair a key, as it was meant to.
- A looser timing now needs your key first, like every other change that blocks less.
- New icon, and the wait and open time shown on the Unlock tab.

## Privacy label

Expected to stay "Data Not Collected." Ally requests live in the user's private iCloud, shared
with one person they pick; the developer cannot read them. Confirm against Apple's definitions
before submitting (docs/18 section 5 lists this as unconfirmed).

## Before the build

- CloudKit Dashboard: deploy the schema to Production (docs/20).
- Test on two phones with two Apple Accounts (docs/18 section 7, steps 2 to 4).
