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

## Production Secrets

Do not commit provider secrets. Supabase Edge Functions expect production
secrets such as `ANTHROPIC_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, managed RPC
URLs, and rate-limit overrides to be configured in Supabase.
