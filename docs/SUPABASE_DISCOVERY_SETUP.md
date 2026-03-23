# Social Discovery Setup

This repo now includes a real first-pass discovery implementation in the iOS app. To turn it on safely, the Supabase schema and env flag both need to be in place.

## 1. Apply the migration

Run the SQL in:

- [/Users/chiburashka/Documents/Codex/Simastry_audit_3264481/supabase/migrations/20260323_discovery_v1.sql](/Users/chiburashka/Documents/Codex/Simastry_audit_3264481/supabase/migrations/20260323_discovery_v1.sql)

You can apply it in either:

- Supabase SQL Editor
- `supabase db push` if you later add the CLI workflow to this repo

The migration creates:

- `social_profiles`
- `discovery_messages`
- `discovery_blocks`
- `discovery_reports`

It also enables RLS and adds policies so users can only edit their own profile, only send messages as themselves, and only view/delete messages or blocks they participate in.

## 2. Enable the feature in the app

Set this environment variable for the app target:

```text
EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED=true
```

The feature stays off unless all of these are true:

- `EXPO_PUBLIC_SUPABASE_URL` is set
- `EXPO_PUBLIC_SUPABASE_ANON_KEY` is set
- `EXPO_PUBLIC_SOCIAL_DISCOVERY_ENABLED=true`

## 3. Verify the basic flow

After the migration is live and the env flag is enabled:

1. Sign in on two test accounts.
2. Turn on "Visible in Discovery" for each account.
3. Confirm profiles appear in Discovery.
4. Send a discovery intro from one account to the other.
5. Confirm the recipient sees it in Messages and can reply in-thread.
6. Test block and report actions from the profile detail sheet.
7. Refresh the inbox while a second account sends a new message and verify the local alert behavior.

## 4. Current scope

This v1 supports:

- opt-in public discovery profiles
- public display name, signs, short bio, and optional social links
- discovery intros and threaded replies in the inbox
- local alerts for newly refreshed discovery messages when notifications are allowed
- blocking
- reporting

This does not yet include:

- moderation dashboards
- admin review tools for reports
- server-driven push for discovery messages
