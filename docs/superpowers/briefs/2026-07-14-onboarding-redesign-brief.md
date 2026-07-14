# Onboarding redesign — audit + decision brief (pre-design)

Status: **awaiting owner decisions** — this is the brainstorming input, not a spec.
Author: Fable, 2026-07-14, after landing Compass Stage 6 on `codex/redesign-compass-account-hub`.

## Why now

The consumer visual redesign (2026-07-08 spec) deliberately scoped onboarding surfaces to
"inherit tokens — polish only, no restructure", and the Compass plan (2026-07-12) rebuilt the
product's first-value surface without touching entry. Onboarding is now the only structural
surface that predates both redesigns, and it funnels into a product whose hero — the Now dial,
Today strip, and one-tap bearings — it never shows.

## Current flow (code-verified)

Pre-auth (`AppScreen`, ContentView switch):

1. `LandingView` (1,317 lines) + `CrystalBallView` (624) — crystal pager, "LIVE BRIEFING"
   panel, two CTAs: value-first Compass (`landing.crystal.cta`) and chart-first
   (`landing.crystal.chartCTA`).
2. `AgeGateView` (115) — over-13; preserves the chosen intent (unit-tested).
3. Branch on `FirstReadOnboardingIntent`:
   - `.predict` → `FirstPredictionView` — guest Compass question, local general-lens read.
   - `.astrologer` → `BirthDetailsView` (586) — chart intake first.
   - `.decode` → `FirstReadView` — decode-a-text first read.
4. `FirstExpertReadView` (241) → `SignUpView` (187) / `SignInView` (168).

Post-auth (`HomeSetupPhase`): `modeSelection → signSelection → onboardingInsight →
companionSetup → soulCreation → complete` — a second onboarding after signup.

## Findings

- **F1 — The guest first read predates the instrument.** `FirstPredictionView` is a question
  form: type → submit → general-lens read. The shipped Compass opens with zero-typing value
  (dial + strip, local, free, instant). Onboarding asks for effort before showing the magic
  the product now leads with.
- **F2 — Structure debt.** `FirstReadChoiceView`, `FirstPredictionView`, and `FirstReadView`
  are defined inside `DecodeTextView.swift` (1,658 lines) — onboarding screens hiding in a
  feature file. `AppScreen.firstReadChoice`/`.firstRead` are legacy: kept in routing but out
  of the active flow.
- **F3 — Double onboarding.** Pre-auth funnel plus the five-phase `HomeSetupPhase` chain
  after signup. Two sequential setup gauntlets is the classic drop-off shape.
- **F4 — Existing rails to preserve.** `OnboardingRoutingTests` (age gate preserves intent),
  `testCrystalLandingPagerReachesFirstRead` (guest funnel end-to-end),
  `PredictionTrustTests` (general lens ⇒ no timing/confidence). Any redesign keeps these
  green or updates them in the same commit.
- **F5 — Locked assets.** Owner constraints from the visual redesign: approved portraits,
  `CouncilKeyArt`, wallpapers, black glass tile material untouched. Assume `CrystalBallView`
  key art carries the same protection until the owner says otherwise.

## Decisions needed (owner)

- **D1 — Primary goal.** What should the redesign move: reach-first-value rate, signup
  conversion, chart-data completion, or skeptic credibility? (Shapes everything below.)
- **D2 — Scope.** Landing-only refresh · full pre-auth funnel · pre-auth + the post-auth
  `HomeSetupPhase` chain.
- **D3 — Guest first read.** Replace the question form with the real Compass instrument in
  guest mode (dial + strip free, one guest bearing as the "aha")?
- **D4 — Chart-first CTA.** Keep the dual-CTA landing, or single value-first path with chart
  intake deferred to the account hub (intake + `user_birth_charts` migration already exist)?
- **D5 — Branch.** Continue on `codex/redesign-compass-account-hub` or a fresh branch after
  this one merges?

## Candidate approaches

- **A — Compass-first onboarding (recommended).** Landing keeps the crystal identity but the
  guest path lands on the real instrument in guest mode: dial + strip computed locally
  (engine needs no account), one free guest bearing, sign-up framed as "keep your windows,
  unlock asks". Reuses Stages 1–6 wholesale; onboarding becomes the product instead of a
  brochure about it. Cost: guest-mode plumbing for `SimulateView` (no credits/auth → the
  honest local fallback already exists), retiring `FirstPredictionView`, UITest updates.
  Also clears F2's debt in passing (screens move to their own files; legacy cases deleted).
- **B — Structural polish only.** Keep the funnel shape; rebuild each screen on the design
  system (tokens, motion, casing), extract the onboarding screens out of
  `DecodeTextView.swift`, delete the two legacy `AppScreen` cases. Lowest risk, no funnel
  change — F1 and F3 remain.
- **C — Shortest funnel.** Landing → age gate → sign-up; all setup (chart, mode, companion)
  moves post-auth into the account hub. Fastest to account creation, but abandons the
  prove-it-before-asking guest moment the current flow (and the Compass positioning) is
  built on. Not recommended alone; C's intake-deferral idea pairs well with A via D4.

## Next step

Owner answers D1–D5 (chat is fine) → brainstorm converges → spec to
`docs/superpowers/specs/` → plan → staged execution with the usual gates.
