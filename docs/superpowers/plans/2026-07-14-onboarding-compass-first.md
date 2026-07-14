# Compass-First Onboarding + Consumer Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the pre-auth funnel show the real Compass instrument (spec: `docs/superpowers/specs/2026-07-14-onboarding-compass-first-design.md`) and make the instrument itself read plainly for people who know no astrology.

**Architecture:** SwiftUI + XcodeGen (`xcodegen generate`; never commit `Simastry.xcodeproj/` or `App/Info.plist`). All builds/tests run from the mirror via `scripts/dev/redesign-verify.sh` (repo-root builds hang while a Codex.app session is active). Instrument components are shared between the authed Compass and the new guest surface via plain-value inputs; guest reads reuse the existing local `PredictionService` (`tier: "free"`), no backend changes.

**Tech Stack:** Swift 6 / SwiftUI, XcodeGen 2.45, iOS 26.2 SDK, XCTest/XCUITest, simctl.

**House verification matrix (every task):** `scripts/dev/redesign-verify.sh build` → `xcodebuild test … -only-testing:SimastryTests` from the mirror → task-listed UITests → screenshots where listed, diffed against `QA/Screenshots/` and replaced/added in-commit → one imperative-mood commit ending with the `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` trailer. UITest command shape:
`xcodebuild test -project Simastry.xcodeproj -scheme Simastry -destination "platform=iOS Simulator,name=iPhone 17 Pro" -derivedDataPath ~/.cache/simastry-verify/DerivedData -only-testing:SimastryUITests/SimastrySmokeUITests/<name> CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO`

---

### Task A: Consumer clarity on the existing instrument (spec C1–C3)

**Files:**
- Modify: `App/Views/CompassInstrumentComponents.swift` (dial kicker/caption; window-kind display icons)
- Modify: `Tests/DayWindowsEngineTests.swift` (extend the 366×3 language lint with a practical-style jargon ban)
- Modify (only if the lint trips): `App/Utilities/DayWindowCopy.swift`
- Baselines: regenerate all 4 `QA/Screenshots/compass-*.png`

- [ ] **Step A1 (test first):** In the 366×3 lint test (`DayWindowsEngineTests.swift:229` area), for the `.practical` style rows add: title+rationale must not contain (case-insensitive) any of `["trine", "sextile", "conjunct", "opposition", "square to", "void-of-course", "void of course", "ingress", "transit", "ruler", "retrograde", "moon in", "hour of"]`. Keep the existing outcome-word ban untouched. Run the single lint test from the mirror. Expected: PASS (practical banks looked clean) — if any string trips, reword that copy-bank string to plain English in the same task; the lint is the permanent guard either way.
- [ ] **Step A2:** `CompassNowDial` — add an overline kicker and a caption, mirroring `CompassDailyGuidanceCard`'s "TODAY" overline treatment (grep it in `CompassComponents.swift` for exact font/tracking/color): kicker `Text("RIGHT NOW")` above the title row; caption `Text("What this hour favors — computed from today's sky.")` (`SimastryFont.captionSmall`, `SimastryColor.mutedSilver`) under `dayProgressArc`. Show both in the placeholder branch too (kicker + shimmer). Append "Computed from today's sky." to the dial's combined `accessibilityLabel`. Do not change `compass.now` or the element structure.
- [ ] **Step A3:** Kill the padlock: in `CompassInstrumentComponents.swift`, change the icon helper so instrument surfaces map by window kind, not raw token: `compassIcon(for window: DayWindow)` → `.quiet` ⇒ `"moon.zzz.fill"`; else `tokenID == "personal"` ⇒ `"sparkles"`; else the token's `systemImage`. Call sites: the dial tick (:89), the horizontal strip segment (:359), and the vertical AX row (:439) — the detail card renders no token icon. `SimastryCategoryToken` itself stays untouched (the composer's Private chip keeps its lock).
- [ ] **Step A4:** Verify: `redesign-verify.sh build` → full `SimastryTests` → UITests `testCompassShowsGlanceableWindowsWithoutTyping`, `testCompassProgressivelyRevealsIntentContext` → regenerate all four compass baselines (`shoot compass-17pro 6 -SimastryPreviewSeeded -SimastryPreviewScreen predict`, 17e via `SIMASTRY_SIM_UDID`, AX3/AX5 via `-UIPreferredContentSizeCategoryName …AccessibilityExtraLarge/…ExtraExtraExtraLarge`) → **look at every PNG**: kicker + caption present, zero padlocks on the timeline, AX layouts intact.
- [ ] **Step A5: Commit** — `"Make the Compass instrument read plainly for newcomers"`.

### Task B: Identifier prefix + GuestCompassView + guest read (spec §2, C4)

**Files:**
- Modify: `App/Views/CompassInstrumentComponents.swift` (add `idPrefix: String = "compass"` to `CompassNowDial`, `CompassTodayStrip`, `CompassWindowDetailCard`; ids become `"\(idPrefix).now"`, `"\(idPrefix).timeline"`, `"\(idPrefix).timeline.segment.<i>"`, `"\(idPrefix).window.detail"`/`.close` — defaults keep authed ids byte-identical)
- Create: `App/Views/GuestCompassView.swift`
- Modify: `App/ContentView.swift:21-22` (`case .firstPrediction:` → `GuestCompassView(viewModel: viewModel)`)
- Modify: `App/ViewModels/AppViewModel.swift` (`completeAgeVerification`: `.decode` → `.firstPrediction` — leave `chooseFirstReadIntent` alone, its only caller is already unreachable and Task D deletes it; add a DEBUG preview value `"guestCompass"` in `applyDebugPreviewStateIfRequested` (:3770), in the pre-auth section, setting `isAgeVerified = true` + `currentScreen = .firstPrediction`, mirroring the `"firstRead"` branch at :3791-3796 that Task D later deletes)
- Modify: `Tests/OnboardingRoutingTests.swift`, `UITests/SimastrySmokeUITests.swift:14-33`
- Modify: localization source holding `firstPrediction.*` keys (grep `"firstPrediction.button"`) — add `guestCompass.*` keys in every language file, same pattern

- [ ] **Step B1 (tests first):** Add `testAgeGatePreservesDecodeIntentIntoGuestCompass` to `OnboardingRoutingTests` (`.decode` ⇒ `.firstPrediction`). Retarget the back half of `testCrystalLandingPagerReachesFirstRead`: after the age gate expect `guestCompass.now` and `guestCompass.timeline` to exist without typing, tap `guestCompass.bearing.work`, then assert the result sheet the way `testCompassBearingRunsReading` (UITests:252-254) does — the "Reading" navigation bar plus the TAKEAWAY/EVIDENCE `CONTAINS[c]` predicates ("GENERAL LENS" was `FirstPredictionView`'s own string and does not exist on `SimulationResultView`). Drop the `firstPrediction.question`/`.submit` steps. Run both. Expected: FAIL (screen/ids don't exist yet).
- [ ] **Step B2:** Thread `idPrefix` through the three components (default `"compass"`). Build; run `testCompassShowsGlanceableWindowsWithoutTyping`. Expected: PASS (authed ids unchanged).
- [ ] **Step B3:** Create `GuestCompassView`: `CelestialBackground` + ScrollView; `TimelineView(.everyMinute)` hosting `CompassNowDial`/`CompassTodayStrip`/`CompassWindowDetailCard` with `idPrefix: "guestCompass"`, windows computed in `.task` exactly the way `SimulateView.recomputeDayWindows` calls the engine but with nil location and nil natal signs, `GuidanceStyle.practical`; three `CompassBearingItem`s (work/love/money, ids `guestCompass.bearing.<slug>`, questions from `FutureQuestionCategory` `.careerSuccess`/`.loveTiming`/`.moneyDirection` day-picked like `SimulateView.bearingQuestion`); tap ⇒ local read via `PredictionService().generatePrediction(request:, tier: "free")` with the request built the way `FirstPredictionView.generatePrediction` builds it (`DecodeTextView.swift:540-570`), result in `SimulationResultView` (nil-optional callbacks), loading + inline error states copied from `FirstPredictionView`; after one completed read, bearing taps route to the sign-up footer instead (`hasUsedGuestRead` @State); footer = `GoldButton("Keep your windows — create an account")` ⇒ the sign-up transition done the way `FirstExpertReadView.swift:195` does it inline (`withAnimation { viewModel.currentScreen = .signUp }` shape — there is no viewmodel method for it) + `SecondaryButton("Add your chart for timing")` ⇒ `viewModel.continueToBirthDetails(after: .predict)`; `FirstPredictionView`'s `privacyLine` text moves here with "free · computed on this device" framing; localized via new `guestCompass.*` keys.
- [ ] **Step B4:** Wire `ContentView` `.firstPrediction` → `GuestCompassView`; reroute `.decode` in the two `AppViewModel` methods; add the `"guestCompass"` preview value.
- [ ] **Step B5:** Verify: build → full `SimastryTests` (routing test now green) → UITests: retargeted landing test + `testCompassShowsGlanceableWindowsWithoutTyping` + `testCompassBearingRunsReading` → shoot the full guest matrix and **add** to `QA/Screenshots/`: `shoot guest-compass-17pro 8 -SimastryPreviewSeeded -SimastryPreviewScreen guestCompass` (the seeded flag is required — `applyDebugPreviewStateIfRequested` hard-guards on it at AppViewModel:3771), `guest-compass-17e` via `SIMASTRY_SIM_UDID`, AX3/AX5 via appending `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityExtraLarge` / `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge`; look: dial kicker, no padlocks, three chips, footer CTAs, privacy line, AX vertical strip.
- [ ] **Step B6: Commit** — `"Land the guest Compass first read"`.

### Task C: Real now-line on the landing screen (spec §1)

**Files:**
- Modify: `App/Views/CrystalLandingView.swift:107-149` (`liveBriefingCard`)
- Modify: `UITests/SimastrySmokeUITests.swift:19` (the `"LIVE BRIEFING"` assertion)
- Modify: `scripts/dev/redesign-verify.sh` (`landing` subcommand: pass optional extra launch args through to `simctl launch` so AX landing shots work)
- Baselines: **add** `landing-17pro.png`, `landing-17e.png`, `landing-17pro-ax3.png`

- [ ] **Step C1 (tests first):** (a) Retarget the landing UITest's front half: assert `landing.nowLine` exists (waitForExistence 10 — compute is async) instead of `"LIVE BRIEFING"`; keep both CTA assertions. (b) Create `Tests/LandingNowLineTests.swift`: the landing line composer returns the dial-format pieces (window title + "until h:mm a") for an active window and nil for an empty/finished result — this forces C2 to extract the line as a small testable helper rather than inline view code. Run both. Expected: FAIL.
- [ ] **Step C2:** Replace `liveBriefingCard` entirely — the canned briefing is deleted, not relabeled (spec: "never a canned briefing"). New structure: a small pure helper (e.g. `LandingNowLine.compose(result:now:)`) feeding a card that renders kicker `RIGHT NOW`, the window's token tick (same treatment as the dial's), the title, `until h:mm a`, and the caption `"Computed from today's sky · on this device."`, id `landing.nowLine`, in the card's existing glass container. Windows compute in a `.task` (same engine call as B3). While computing: the dial's shimmer-placeholder treatment. On failure/empty: the card stays hidden — the static hero copy above it carries the screen, with no fake data and no LIVE wording anywhere.
- [ ] **Step C3:** Verify: build → units (new composer test green) → landing UITest green → add the full landing matrix to `QA/Screenshots/`: `landing-17pro`, `landing-17e` (via `SIMASTRY_SIM_UDID`), `landing-17pro-ax3` / `landing-17pro-ax5` via the new pass-through args (`-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityExtraLarge` / `…AccessibilityExtraExtraExtraLarge`) → look: real window text, no "LIVE BRIEFING" string anywhere, CTAs intact.
- [ ] **Step C4: Commit** — `"Show the real current window on the landing screen"`.

### Task D: Retire legacy screens + sweep (spec §3)

**Files:**
- Modify: `App/Views/DecodeTextView.swift` (delete `FirstReadChoiceView`:72, `FirstPredictionView`:231, `FirstReadView`:892, `FirstReadEntryOption`, `FirstPredictionPrompt`, `firstPredictionPrompts`)
- Modify: `App/Models/AppModels.swift:451-465` (delete `.firstReadChoice`, `.firstRead` + the legacy comment)
- Modify: `App/ContentView.swift` (delete the two cases; fix the `:144` exhaustive list)
- Modify: `App/ViewModels/AppViewModel.swift` (delete `chooseFirstReadIntent`; the `-SimastryPreviewScreen firstRead` hook; the `.decode: break` arm in `consumeFirstReadOnboardingIntentIfReady` — `.decode` now behaves like `.predict` there; keep `FeedbackSurface.firstRead` — different enum)
- Modify: localization files (drop orphaned `firstReadChoice.*`, `firstRead.*`, `firstPrediction.*` keys)

- [ ] **Step D1:** Delete in the order above; `grep -rn "firstReadChoice\|FirstReadView\|FirstPredictionView\|chooseFirstReadIntent" App/` must return nothing afterward.
- [ ] **Step D2:** Verify: build (compiler enforces exhaustiveness) → full `SimastryTests` → UITests: landing test + `testPeoplePredictDraftLandsInReplyFlow`. Expected: all green; `DecodeTextView.swift` shrinks by roughly half.
- [ ] **Step D3: Commit** — `"Retire the legacy first-read screens"`.

### Task E: Restyle the remaining funnel screens (spec §4)

**Files:**
- Modify: `App/Views/AgeGateView.swift`, `App/Views/BirthDetailsView.swift`, `App/Views/FirstExpertReadView.swift`, `App/Views/SignUpView.swift`, `App/Views/SignInView.swift`

- [ ] **Step E1:** Tokens-only pass per screen: materials → `simastryGlass`/`contentSurface` per the glass rule, motion → `SimastryMotion` tokens, sentence-case strings, `tabBarEndClearance`-style bottom insets, 44pt targets. **No logic, routing, or identifier changes** (`ageGate.over13` etc. stay). Astrology jargon in copy gets the C3 plain-first treatment.
- [ ] **Step E2:** Verify: build → full `SimastryTests` → UITests: landing test (crosses AgeGate) + the chart-first routing unit tests. Screenshot spot-check: shoot the landing → (manually via UITest pass) rely on suite for downstream screens; shoot `guest-compass-17pro` again if shared components moved.
- [ ] **Step E3: Commit** — `"Restyle the pre-auth funnel on the design tokens"`.

### Task F: Full QA gate

- [ ] **Step F1:** `redesign-verify.sh build` → full `SimastryTests` → **full** `SimastrySmokeUITests` suite (baseline is 28/28 since fb497e3b; late-run snapshot timeouts ⇒ reboot sim, re-run those tests in isolation before treating as real).
- [ ] **Step F2:** Regenerate/diff every compass + guest + landing baseline; look at each PNG (kicker, no padlocks, real landing line, AX layouts, nothing clipped).
- [ ] **Step F3: Commit** any baseline refreshes — `"Refresh the QA baselines for the Compass-first funnel"` — and push the branch. (Sqim device build deliberately omitted — owner said to disregard the install link for now.)
