# Simastry App Store Readiness

This file tracks the current release gates for the SwiftUI app. It separates verified work from planned work so release decisions do not depend on prototype assumptions.

## Current Release Target

- Platform: iOS SwiftUI app in `Simastry/SimastryApp/`
- Product loop: onboarding -> companion setup -> companion guidance -> prediction/chat utility -> subscription upgrade
- Positioning: premium astrology communication app, not a horoscope feed, dating app, or marketplace

## Verified In Current Worktree

- Birth chart calculation exists through `BirthChartService`.
- Supabase auth/data service exists through `SupabaseService`.
- RevenueCat is referenced for subscriptions.
- Prediction requests route through `PredictionService`.
- Conversation privacy redaction exists through `ConversationPrivacyService`.
- DM-style companion chat exists through `CompanionChatView`.
- Local companion messages persist through `LocalCompanionChatStore`.
- Companion chat replies are deterministic, sign-specific, and placement-aware through `CompanionReplyFactory`.
- Notifications exist through `NotificationService`.
- Safety handling blocks self-harm, direct threats, sexual-minor content, and coercive relationship behavior before prediction generation.

## Release Blockers

- Production AI moderation is still lightweight and local to request preparation. Backend moderation, server-side quotas, and abuse telemetry are required before scale.
- Companion DM replies are local deterministic prototype replies. A production release needs backend AI chat wiring, server-side safety, quotas, and persistence.
- Subscription products and RevenueCat configuration must be validated against real App Store products.
- Supabase environment configuration must be validated with production keys and no secrets committed.
- Legal copy in the app is placeholder-level; final privacy policy, terms, support URL, and data deletion path are required.
- App Store screenshots, age rating, privacy nutrition labels, and review notes are not yet verified.

## Build Environment Note

- The source tree under `/Users/chiburashka/Documents` is FileProvider-managed. In this environment, `xcodebuild` can hang while reading the project directly from that path.
- Verification currently runs from a local copy at `/tmp/simastry-xcode-verify` with DerivedData at `/tmp/simastry-derived-data`.
- For normal release work, move the repo outside FileProvider-managed `Documents` or keep using a non-FileProvider verification copy.

## Required Verification Before Release

- `xcodebuild test` passes on a current iPhone simulator.
- App launches cleanly from a fresh install.
- Sign up, sign in, sign out, and OAuth callback flows work.
- Birth details onboarding completes with missing-time and missing-location states.
- Companion setup creates and persists a companion.
- Messages opens a DM thread, persists local messages, and produces a companion-specific astrology reply.
- Prediction flow redacts identifiers and blocks unsafe/coercive requests.
- Notifications are opt-in and never expose private conversation content.
- Subscription purchase, restore, and unavailable-state flows work.
- Dynamic Type, reduced motion, and small-screen layouts are checked.

## Current Verification

- `xcodebuild build` succeeded from `/tmp/simastry-xcode-verify`.
- `xcodebuild test` succeeded from `/tmp/simastry-xcode-verify`.
- Simulator launch succeeded on iPhone 17 simulator.
- Demo-mode smoke check succeeded: landing -> sign in -> demo mode -> Messages -> DM thread -> send message -> companion reply.

## Next Engineering Gate

Wire companion DM to production AI and backend message persistence, then run a fresh-install simulator smoke test across onboarding, prediction, subscription, notification permission, and DM chat flows.
