# Claude UI Audit

## Recommendation

Do not push Claude's native UI branch directly.

Port a small set of product-loop improvements into the current `origin/main` app under `ios/Simastry/SimastryApp`, then open a clean PR from that current structure.

## Rationale

Claude's native UI changes were made against the stale root-level SwiftUI app:

- `Simastry/SimastryApp/...`
- `Simastry.xcodeproj`

The current `origin/main` app now lives under:

- `ios/Simastry/SimastryApp/...`
- `ios/Simastry.xcodeproj`

That means the Claude UI commit is directionally useful, but it targets the wrong version of the app. Pushing it as-is would either fail to affect the current app or reintroduce stale architecture.

## Verified Current State

Clean current worktree inspected:

- `/Users/chiburashka/Documents/Codex/Simastry-current-ui`
- `origin/main` commit: `7e3aed9 Replace Scorpio landing page model`
- Xcode project: `ios/Simastry.xcodeproj`
- Available scheme: `Simastry`

Current app files include:

- `ios/Simastry/SimastryApp/Views/MainTabView.swift`
- `ios/Simastry/SimastryApp/Views/HomeView.swift`
- `ios/Simastry/SimastryApp/Views/SimulateView.swift`
- `ios/Simastry/SimastryApp/Views/MessagesView.swift`
- `ios/Simastry/SimastryApp/Views/CompanionDetailSheet.swift`
- `ios/Simastry/SimastryApp/Services/ContentModerationService.swift`
- `ios/Simastry/SimastryApp/Services/RateLimiter.swift`

The local root checkout is dirty and divergent:

- ahead of `origin/main` by 2 commits
- behind `origin/main` by 42 commits
- contains large untracked prototype/tool folders that should not be pushed to app main

## Keep And Port

These strengthen Simastry's core loop and should be ported into the current `ios/` app.

### 1. Companion to Predict routing

Claude added `startPrediction(for:)` flows from companion surfaces into Predict.

Keep this because it makes the loop concrete:

`meet companion -> choose context -> predict reply`

Port target files:

- `ios/Simastry/SimastryApp/ViewModels/AppViewModel.swift`
- `ios/Simastry/SimastryApp/Views/CompanionDetailSheet.swift`
- `ios/Simastry/SimastryApp/Views/CompanionsView.swift`
- `ios/Simastry/SimastryApp/Views/GuidesView.swift`
- `ios/Simastry/SimastryApp/Views/SimulateView.swift`

### 2. Prediction target context

Claude's Predict screen can show who or what sign is being interpreted.

Keep this. It makes prediction feel intentional instead of generic.

Port as a small extracted component, not as another large inline block inside `SimulateView`.

Recommended new component:

- `ios/Simastry/SimastryApp/Views/Components/PredictionTargetCard.swift`

### 3. Conversation privacy redaction

Claude added `ConversationPrivacyService` to redact emails, phone numbers, links, and handles before prediction.

Keep this. It directly supports trust, App Store risk reduction, and the product rule that private conversation content must be handled carefully.

Port target files:

- `ios/Simastry/SimastryApp/Services/ConversationPrivacyService.swift`
- `ios/Simastry/SimastryApp/Services/PredictionService.swift`
- `ios/Simastry/SimastryApp/Models/SimulationModels.swift`
- `ios/Simastry/SimastryApp/Views/SimulationResultView.swift`

### 4. Privacy notice in Predict

Keep a short notice near the conversation paste box.

Copy should remain direct:

> Emails, phone numbers, links, and handles are redacted before prediction.

Do not over-explain.

### 5. Chart accuracy messaging

Claude added chart confidence concepts around exact time, estimated time, and missing birthplace.

Keep the idea, but port carefully because `origin/main` already has a better pending onboarding chart flow.

### 6. Debug demo mode

Keep only under `#if DEBUG`.

It helps development velocity without affecting production.

## Rework Before Porting

### 1. Custom liquid glass tab shell

Claude's custom tab bar is visually closer to the premium direction, but the implementation should not be pushed as-is.

Problems:

- replaces native `TabView` with a top-level `switch`
- risks view identity churn
- puts too much UI into `MainTabView`
- duplicates messages behavior that already exists in current `origin/main`

Recommendation:

Use the visual direction selectively later, but keep current navigation architecture unless there is a dedicated navigation redesign.

### 2. Home companion hero deck

The idea is good: companions should be a primary surface.

Do not port inline into `HomeView`. Current `HomeView` is already large.

Recommended new components:

- `HomeCompanionDeckView.swift`
- `CompanionHeroCard.swift`

### 3. Shell background and palette changes

Claude's `SimastryShellBackground` and design tokens are tasteful, but broad application risks making the app too espresso/brown and less premium astrology.

Use selectively:

- onboarding
- Predict
- companion cards

Do not globally recolor everything in one pass.

### 4. Co-Star-style onboarding

The simpler onboarding direction is useful, but Simastry should not become a Co-Star clone.

Keep:

- fewer landing choices
- birth details before account creation
- clear privacy copy

Preserve:

- companion-first positioning
- Predict their reply hook
- conversation-first astrology

## Do Not Push

Do not push these from Claude's branch:

- stale root-level app path changes
- giant inline `MainTabView` replacement
- inline `MessagesView` inside `MainTabView`
- broad palette overwrite
- old Supabase config handling that is already superseded by `origin/main`
- old onboarding persistence that is already superseded by `origin/main`
- large untracked folders such as `expo-prototype`, `Factory`, `chatgpt-apps`, and `.claude`

## Push Plan

1. Create a new branch from `origin/main`.
2. Port only the Keep items into `ios/Simastry/SimastryApp`.
3. Keep UI changes componentized.
4. Run the Simastry scheme.
5. Open a PR with a narrow title:

   `Port prediction context and privacy-safe conversation handling`

## Next Action

Implement the Keep items first:

1. `PredictionDraft`
2. `startPrediction(for:)`
3. `ConversationPrivacyService`
4. Predict target context card
5. privacy summary in results

Defer the tab bar redesign until the prediction loop is cleaner and testable.
