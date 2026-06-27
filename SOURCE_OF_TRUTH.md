# Simastry Source Of Truth

Use this folder as the only active iOS and web source:

`/Users/chiburashka/Documents/Codex/Simastry`

Before any Codex, Bitrig, or Xcode work, run:

`scripts/verify_canonical_simastry.sh`

## iOS App

- Xcode project: `Simastry.xcodeproj`
- Scheme: `Simastry`
- Bundle ID: `app.simastry.ios`
- Active TestFlight/Bitrig branch: `codex/testflight-bitrig-readiness`
- DerivedData for verification: `/Users/chiburashka/Library/Developer/Xcode/DerivedData/Simastry-canonical`
- XcodeBuildMCP active profile: `simastry-canonical` only

The intended iOS baseline must contain all of these:

- `Today` tab in `Simastry/SimastryApp/Views/MainTabView.swift`
- `NadiaFeaturedGuide.mp4` in `Simastry/SimastryApp/Media/`
- Factory Nadia image sets in `Simastry/SimastryApp/Assets.xcassets/`
- No legacy vendor/bundle references in app or Xcode sources

Do not build, run, or review these archived/stale copies:

- `/Users/chiburashka/Documents/Codex/_archives/Simastry-source-cleanup-*`
- `/Users/chiburashka/Documents/Codex/_archives/Simastry-canonical-ios-before-nadia-promote-*`
- `/Users/chiburashka/Library/Bitrig/Projects/c71323dc-4878-486c-825d-c0ac5470c55d`
- Any `Simastry_audit_*`, `Simastry-current`, `Simastry-finalization`, or detached Bitrig PR copy outside this repo.

## Web Landing Page

- Production web source: `website/`
- Privacy policy: `https://simastry.vercel.app/privacy`
- Terms: `https://simastry.vercel.app/terms`

## Bitrig Review

Bitrig should review the pushed GitHub branch for this repo only. Do not use archived local snapshots or old Bitrig project folders. Before reviewing, confirm the branch contains the companion-collage landing in `Simastry/SimastryApp/Views/LandingView.swift`.

## Build Guardrails

- Run `scripts/verify_canonical_simastry.sh` before Simulator, Bitrig, archive, or TestFlight work.
- If XcodeBuildMCP is used, `session_show_defaults` must show `simastry-canonical`, `app.simastry.ios`, and `/Users/chiburashka/Library/Developer/Xcode/DerivedData/Simastry-canonical`.
- If a different Simastry path, bundle ID, or DerivedData folder appears, stop and fix the active profile before building.

## Recovery Note

The Nadia/Factory iOS source was recovered from the finalization archive and promoted here on 2026-06-18. The pre-promotion iOS app was archived under `/Users/chiburashka/Documents/Codex/_archives/Simastry-canonical-ios-before-nadia-promote-*` and is no longer an active build source.
