# Simastry recovery cleanup archive

Recommendation: keep PR #6 as the protected Expo/Factory checkpoint, and use this cleanup branch only to preserve planning context and keep generated clutter out of the repo.

## Safety archive

A full dirty-worktree archive was created outside the repository before any cleanup:

- `/Users/chiburashka/Documents/Codex/Simastry-recovery-archive-20260601-185558/dirty-worktree-files.tar.gz`
- `/Users/chiburashka/Documents/Codex/Simastry-recovery-archive-20260601-185558/tracked-changes.patch`
- `/Users/chiburashka/Documents/Codex/Simastry-recovery-archive-20260601-185558/git-status-short.txt`
- `/Users/chiburashka/Documents/Codex/Simastry-recovery-archive-20260601-185558/SHA256SUMS.txt`

The archive captured 582 dirty or untracked paths from `/Users/chiburashka/Documents/Codex/Simastry`.

## What this archive preserves

- Product instructions from `AGENTS.md`.
- App Store readiness notes.
- Claude UI audit findings.
- Product audit notes.
- Grok CEO and mentor prompts.

## Current repo reality

The useful Expo prototype and Factory work are protected in PR #6.

The dirty native SwiftUI work in the recovery workspace targeted the stale root app:

- `Simastry/SimastryApp`
- `Simastry.xcodeproj`

The current iOS app on `origin/main` lives under:

- `ios/Simastry/SimastryApp`
- `ios/Simastry.xcodeproj`

Do not port the stale SwiftUI shell wholesale. Only port the specific product-loop ideas listed in `docs/IOS_PORT_PLAN.md`.

## Generated clutter to ignore

- `.claude/`
- `Factory/Factory.app/`
- `expo-prototype/dist/`
- `expo-prototype/*.png`
- duplicate untracked companion PNG assets under `expo-prototype/assets/astrogram` and `expo-prototype/assets/hero-cast`
- `expo-prototype-preview/`
- `Model Template/`

## Founder review

Before turning any archived doc into current source of truth, review whether it still matches the current `ios/` app and the latest product direction.
