# Simastry — App Store Submission Checklist

## Legal & Compliance
- [ ] Privacy Policy URL is live and accessible at the URL in `AppConfig.swift`
- [ ] Terms of Service URL is live and accessible at the URL in `AppConfig.swift`
- [ ] EULA uses Apple's standard EULA link (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`)
- [ ] Paywall (`UpsellModalView.swift`) includes auto-renewal disclaimer text
- [ ] Paywall includes tappable links to Privacy Policy, Terms of Service, and EULA
- [ ] Landing page (`LandingView.swift`) has tappable links to Terms and Privacy
- [ ] Profile/Settings page (`ProfileView.swift`) has links to full legal policies
- [ ] `PrivacyInfo.xcprivacy` manifest exists and declares collected data types (email, user ID, purchase history, coarse location), UserDefaults API usage, and no tracking

## Authentication
- [ ] Apple Sign-In is implemented (required since Google Sign-In is present)
- [ ] Google Sign-In is implemented and working
- [ ] Email/password sign-in with validation (email format, password length)
- [ ] OAuth flow does NOT set `isAuthenticated = true` before session is confirmed via callback
- [ ] Auth state is restored on app launch via `checkAuthState()`
- [ ] App review demo account credentials are ready for App Store Connect

## Monetization & Subscriptions
- [ ] Pricing is monthly (not weekly): Plus ~$6.99/mo, Pro ~$14.99/mo
- [ ] Restore Purchases button exists and works
- [ ] Free-tier prediction quotas are enforced — `SimulateView` calls `canUsePrediction()` before generating and `consumePrediction()` after
- [ ] Free-tier message quotas are enforced
- [ ] Companion creation limits are enforced — `createCompanion()` calls `canAddCompanion()` and shows upsell if blocked
- [ ] "Simulate Anyone" mode is gated behind Pro tier in `ModeSelectionView`
- [ ] Subscription products are configured in App Store Connect with descriptions and localisation
- [ ] Paid Apps Agreement is accepted in App Store Connect (Business section)

## Core Feature Correctness
- [ ] Birth chart calculation uses actual astronomical data (Swiss Ephemeris or equivalent), not random/fallback values
- [ ] Moon and Rising signs are computed from birth date, time, and place — not manually picked or hardcoded
- [ ] Compatibility scores use real astrological logic (element compatibility, modality harmony) — not `Int.random()`
- [ ] `CompanionDetailSheet` shows a "Why You're Compatible" breakdown with Sun/Moon/Rising insights
- [ ] Prediction/simulation feature produces results via AI (Claude Sonnet 4.6)
- [ ] Companion AI personalities are sign-specific (proactive, personality-driven prompts)

## Accessibility
- [ ] All fonts use Dynamic Type via `SimastryFont` semantic tokens (not fixed `.system(size:)`)
- [ ] VoiceOver accessibility labels on all interactive elements (buttons, cards, pickers)
- [ ] `@Environment(\.accessibilityReduceMotion)` is respected — animations are skipped when enabled
- [ ] Skeleton shimmer loading states exist for content loading
- [ ] Color contrast meets WCAG 4.5:1 minimum (check `mutedSilver` and other muted colors)

## Error Handling & Safety
- [ ] No force-unwraps (`!`) on URLs or optionals in `SupabaseService`
- [ ] All Supabase `try` calls are wrapped in `do/catch` with user-facing toast errors (not silent `try?`)
- [ ] `signOut` is the only acceptable `try?` (non-critical)
- [ ] `NotificationService` is `@MainActor` (no data races on mutable properties)
- [ ] Dark mode preference persists via `UserDefaults`

## Notifications
- [ ] Notification permission is requested at an appropriate time
- [ ] Evening check-in notifications use randomized engaging messages (not generic)
- [ ] Re-engagement notifications exist for inactive users
- [ ] Simulation reminder notifications exist
- [ ] Daily transit notifications reference the user's rising sign
- [ ] No notification reveals sensitive conversation content

## UI/UX
- [ ] Onboarding has a step progress indicator (`OnboardingProgressView`)
- [ ] Home view shows skeleton loading placeholders while data loads
- [ ] Profile "About Me" section includes a shareable "How to Talk to You" conversation guide
- [ ] Communication guide shows sign-specific tips, best approach, and what to avoid
- [ ] Share functionality works for cosmic DNA / conversation guide cards

## App Store Connect Configuration (manual)
- [ ] Age rating questionnaire completed
- [ ] App encryption documentation (uses HTTPS = exempt, select YES for standard encryption exemption)
- [ ] Data collection disclaimers match `PrivacyInfo.xcprivacy` (email, user ID, purchases, coarse location)
- [ ] Third-party SDK disclosures: Supabase, RevenueCat, crash tracking
- [ ] ASO-optimized app name, subtitle, keywords, description, promotional text
- [ ] App icon (1024x1024) uploaded
- [ ] Screenshots showing actual app UI (majority of screenshots)
- [ ] Localised pricing configured

## Testing
- [ ] App builds without errors in Xcode
- [ ] All authentication flows work end-to-end
- [ ] Subscription purchase and restore work in sandbox
- [ ] Free tier limits are enforced correctly
- [ ] Birth chart generates correct signs for known birthdays
- [ ] VoiceOver navigation works through all screens
- [ ] Dynamic Type scales correctly at all accessibility sizes
- [ ] Dark mode works correctly throughout
- [ ] No crashes on first launch or cold start
