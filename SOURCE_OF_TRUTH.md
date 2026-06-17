# Simastry Source Of Truth

Use this folder as the only active iOS and web source:

`/Users/chiburashka/Documents/Codex/Simastry`

## iOS App

- Xcode project: `Simastry.xcodeproj`
- Scheme: `Simastry`
- Bundle ID: `app.simastry.ios`
- Active TestFlight/Bitrig branch: `codex/testflight-bitrig-readiness`
- DerivedData for verification: `/Users/chiburashka/Library/Developer/Xcode/DerivedData/Simastry-main-recovery`

Do not build, run, or review these archived/stale copies:

- `/Users/chiburashka/Documents/Codex/_archives/Simastry-source-cleanup-*`
- `/Users/chiburashka/Library/Bitrig/Projects/c71323dc-4878-486c-825d-c0ac5470c55d`
- Any `Simastry_audit_*`, `Simastry-current`, `Simastry-finalization`, or detached Bitrig PR copy outside this repo.

## Web Landing Page

- Production web source: `website/`
- Privacy policy: `https://simastry.vercel.app/privacy`
- Terms: `https://simastry.vercel.app/terms`

## Bitrig Review

Bitrig should review the pushed GitHub branch for this repo only. Do not use archived local snapshots or old Bitrig project folders. Before reviewing, confirm the branch contains the companion-collage landing in `Simastry/SimastryApp/Views/LandingView.swift`.
