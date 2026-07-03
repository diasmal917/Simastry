# Simastry Build Notes

Simastry uses XcodeGen as the checked-in source of truth for the Xcode project.
`Simastry.xcodeproj/` and `App/Info.plist` are generated local artifacts and are
ignored intentionally.

## Clean Checkout Build

1. Install XcodeGen if it is not already available:

   ```sh
   brew install xcodegen
   ```

2. Generate the project from the repo root:

   ```sh
   xcodegen generate --spec Project.json
   ```

3. Build the simulator target:

   ```sh
   xcodebuild \
     -project Simastry.xcodeproj \
     -scheme Simastry \
     -configuration Debug \
     -sdk iphonesimulator26.2 \
     -destination 'generic/platform=iOS Simulator' \
     build
   ```

`Project.json` owns the app bundle identifier, deployment target, generated
Info.plist properties, package dependencies, and source layout.

## Local Supabase (DEBUG integration testing)

Release builds always target the remote Supabase project. DEBUG builds can be
pointed at a local `supabase start` stack to exercise the expert-astrologer
intake persistence and SSE streaming end-to-end without touching production.

Start the local stack and serve the function:

```sh
SUPABASE_TELEMETRY_DISABLED=1 supabase start --exclude vector
supabase functions serve companion-reply
```

Then launch the DEBUG app with the override. Either:

- Launch argument: `-SimastryUseLocalSupabase`
  (URL `http://127.0.0.1:54321` + the standard local anon key), or
- Environment variables (take precedence; use for a non-default key/port):
  - `SIMASTRY_SUPABASE_URL_OVERRIDE=http://127.0.0.1:54321`
  - `SIMASTRY_SUPABASE_ANON_KEY_OVERRIDE=<anon key from supabase start>`

Example for `xcodebuild test`:

```sh
xcodebuild test \
  -project Simastry.xcodeproj -scheme Simastry \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  SIMASTRY_SUPABASE_URL_OVERRIDE=http://127.0.0.1:54321
```

When active, the console prints `DEBUG Supabase override active → …` at launch.
The override is compiled out of release builds entirely.

## Production Secrets

Do not commit provider secrets. Supabase Edge Functions expect production
secrets such as `ANTHROPIC_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, managed RPC
URLs, and rate-limit overrides to be configured in Supabase.
