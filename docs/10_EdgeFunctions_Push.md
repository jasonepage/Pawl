# 10 — Real-time push: deploy the Edge Functions

**Audience:** whoever runs the backend. This turns the sponsor flow from "open the app to see requests" into instant
push. The app already invokes these functions; they just need deploying. The polling path keeps
working if you skip this — push is purely additive.

Functions (in `supabase/functions/`):
- `notify-sponsor` — pushes the sponsor when you request an unlock.
- `notify-user` — pushes you when the sponsor approves/denies.
- `detect-silence` — scheduled; pushes the sponsor on a tamper alert.
- `_shared/apns.ts` — APNs sender (bundled automatically).

---

## 1. One-time CLI setup
- [ ] Install the CLI: `brew install supabase/tap/supabase`
- [ ] `supabase login`
- [ ] From the repo root: `supabase link --project-ref bvixxdlmjeulxrefmqjx`

## 2. Confirm the APNs secrets exist
You added these in `09_Supabase_APNs_Setup.md` §5. Verify: `supabase secrets list` should show
`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_BUNDLE_ID`, `APNS_P8`, `APNS_ENV`.
- [ ] For on-device **development** testing, `APNS_ENV` must be `sandbox`.
- [ ] For **TestFlight/App Store**, set it to production: `supabase secrets set APNS_ENV=production`.
  *(Dev builds use the sandbox APNs gateway; TestFlight builds use production. They're separate —
  a sandbox key won't deliver to a TestFlight build and vice-versa.)*

## 3. Deploy the functions
- [ ] `supabase functions deploy notify-sponsor`
- [ ] `supabase functions deploy notify-user`
- [ ] `supabase functions deploy detect-silence`

(`notify-sponsor` / `notify-user` are invoked by the app with the signed-in user's token, so leave
JWT verification on. `detect-silence` is called by the cron with the service-role key.)

## 4. Schedule detect-silence (replaces the SQL-only cron from migration 01)
Enable **pg_net** (Dashboard → Database → Extensions). Then in the SQL Editor — paste your
**service_role** key (Settings → API) where shown:

```sql
select cron.unschedule('pawl-detect-silence');   -- remove the SQL-only job from migration 01

select cron.schedule('pawl-detect-silence-push', '0 * * * *', $$
  select net.http_post(
    url := 'https://bvixxdlmjeulxrefmqjx.functions.supabase.co/detect-silence',
    headers := jsonb_build_object(
      'Authorization', 'Bearer <YOUR_SERVICE_ROLE_KEY>',
      'Content-Type', 'application/json')
  );
$$);
```

---

## Test (two phones, real devices — APNs needs sandbox env + a dev build)
1. Both phones signed in, sponsor-linked, and each has opened the app once (so their APNs token is
   stored — check the `devices` table has `apns_token` populated).
2. Phone A → Unlock → tap key. **Phone B should get a push** "Pawl unlock request" within a second or
   two, even with the app closed.
3. Phone B approves → **Phone A gets** "Sponsor approved."
4. Tamper: force a silence alert (`select public.detect_silent_clients(interval '2 minutes');` after
   not beating), then invoke the function once to push: it runs hourly on its own, or hit it manually:
   `curl -X POST https://bvixxdlmjeulxrefmqjx.functions.supabase.co/detect-silence -H "Authorization: Bearer <SERVICE_ROLE_KEY>"`

## If a push doesn't arrive
- Check the function logs: `supabase functions logs notify-sponsor` (APNs errors print there).
- Most common cause: `APNS_ENV` mismatch (sandbox vs the build type) or a missing `apns_token` on the
  recipient's `devices` row (they need to have granted notifications + opened the app once).
- The app never blocks on push — if a function is down, requests still work via polling.
