# Simastry iOS port plan

Recommendation: port only the useful companion/chat/prediction ideas from the stale root SwiftUI work into the current `ios/` app. Do not port the stale UI shell.

## Rationale

The recovery workspace contains useful product-loop code, but it was written against the old root app:

- `Simastry/SimastryApp`
- `Simastry.xcodeproj`

The current app on `origin/main` uses:

- `ios/Simastry/SimastryApp`
- `ios/Simastry.xcodeproj`

Porting file-for-file would target the wrong app and risk reintroducing stale navigation and architecture. The right move is a small sequence of focused PRs against the current `ios/` target.

## Keep for porting

- `ConversationPrivacyService`: client-side privacy redaction and safety screening before prediction/chat work.
- `CompanionChatView`: DM-style companion conversation surface.
- `LocalCompanionChatStore`: local prototype persistence for companion messages.
- `CompanionReplyFactory`: deterministic, sign-specific, placement-aware companion replies for the prototype.
- `PredictionDraft`: a typed handoff from companion/guides/chat into prediction.
- `startPrediction(for:)`: companion and sign entry points into Predict.
- Chart accuracy UI: visible feedback when birth time/location improves Rising sign accuracy.
- Privacy, chat, prediction, and chart-accuracy tests.

## Do not port

- The stale root `Simastry.xcodeproj`.
- The stale root app shell or full tab redesign.
- Any direct UI changes that bypass the current `ios/` app structure.
- Any production AI/backend work until moderation, quotas, failure states, and privacy rules are explicit.

## Current iOS target files

Use these current files as the integration points:

- `ios/Simastry.xcodeproj/project.pbxproj`
- `ios/Simastry/SimastryApp/Models/SimulationModels.swift`
- `ios/Simastry/SimastryApp/ViewModels/AppViewModel.swift`
- `ios/Simastry/SimastryApp/Services/BirthChartService.swift`
- `ios/Simastry/SimastryApp/Services/PredictionService.swift`
- `ios/Simastry/SimastryApp/Services/ContentModerationService.swift`
- `ios/Simastry/SimastryApp/Services/RateLimiter.swift`
- `ios/Simastry/SimastryApp/Views/BirthDetailsView.swift`
- `ios/Simastry/SimastryApp/Views/SignUpView.swift`
- `ios/Simastry/SimastryApp/Views/CompanionsView.swift`
- `ios/Simastry/SimastryApp/Views/CompanionDetailSheet.swift`
- `ios/Simastry/SimastryApp/Views/GuidesView.swift`
- `ios/Simastry/SimastryApp/Views/HomeView.swift`
- `ios/Simastry/SimastryApp/Views/MessagesView.swift`
- `ios/Simastry/SimastryApp/Views/SimulateView.swift`
- `ios/SimastryTests/SimastryAppTests.swift`
- `ios/SimastryTests/AppViewModelRegressionTests.swift`
- `ios/SimastryTests/BirthChartServiceTests.swift`
- `ios/SimastryUITests/SimastryAppUITests.swift`

Add these new current-target files only when the port PR begins:

- `ios/Simastry/SimastryApp/Services/ConversationPrivacyService.swift`
- `ios/Simastry/SimastryApp/Services/CompanionChatService.swift`
- `ios/Simastry/SimastryApp/Views/CompanionChatView.swift`

## Suggested PR sequence

1. Privacy foundation: add `ConversationPrivacyService`, wire it into `PredictionService`, and port privacy/safety tests.
2. Prediction handoff: add `PredictionDraft` and `startPrediction(for:)` to the current model/view model, then wire companion and guide entry points into `SimulateView`.
3. Chart accuracy: port the visible accuracy model and UI into onboarding, backed by `BirthChartService` tests.
4. Companion DM prototype: add `LocalCompanionChatStore`, `CompanionReplyFactory`, and `CompanionChatView`, then connect from `MessagesView` or companion detail.
5. Polish pass: make chat feel like Instagram DMs while preserving Simastry's premium astrology tone.

Each PR should build against `ios/Simastry.xcodeproj` and avoid touching the stale root app.
