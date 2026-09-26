# Reporting a vulnerability

Email **support@getpawl.com** with "Pawl security" in the subject. A person
reads it.

Do not put the details in a public issue. If the email bounces, open an issue
that says only that you have a security report and how to reach you.

Please say what you found, how to reproduce it, and what you think it lets
somebody do.

There is no bounty. Pawl is one developer, with no company or funding behind
it. What you get is a fast answer, credit in the fix commit if you want it,
and a straight account of what was wrong.

## Test fairly

Use your own accounts and your own phones. Do not touch other people's data,
do not flood the servers, and do not keep anything you happen to see. Work that
way and there is nothing to forgive: no legal action from this project.

## What counts

Pawl exists for people trying to stop gambling, so the things that matter most
are the ones that hurt that person at a bad moment:

- Anything that lifts the shield without the physical key and the full
  cooling off wait.
- Anything that lets someone read another person's data, or act as a sponsor
  they are not.
- Anything that sends a false alert or a false "approved" to a real person.
- Anything that stops a real tamper alert from reaching a sponsor.

## Known limits (not findings)

These are written down in the README. A way to make one of them worse than
described is still a finding.

- The security key check compares credential IDs. It does not verify the
  assertion signature. See `Pawl/Services/SecurityKeyService.swift`.
- iOS lets the owner of a phone turn Screen Time off. Pawl cannot prevent
  that. It can only notice and tell a sponsor.
- Nobody independent has audited Pawl.

## Where to look first

| File | Why |
|---|---|
| `Pawl/Domain/UnlockMachine.swift` | The whole unlock loop, as a pure function |
| `PawlTests/UnlockMachineTests.swift` | Its tests |
| `Pawl/Services/SecurityKeyService.swift` | The physical key check |
| `Pawl/Services/ShieldService.swift` | Applying and lifting the shield |
| `supabase/schema.sql` and `supabase/migrations/` | Tables, row level security, server functions |
| `supabase/functions/` | The five server functions |
