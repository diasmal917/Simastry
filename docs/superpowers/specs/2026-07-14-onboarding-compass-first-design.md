# Onboarding — Compass-first pre-auth funnel (design spec)

Owner decisions (2026-07-14, recorded from chat): goal = **skeptic credibility** ("even just
for fun" positioning — the first minutes must feel premium and honest) · approach = **A,
Compass-first** · scope = **full pre-auth funnel** (landing → sign-up; the post-auth
`HomeSetupPhase` chain is out of scope) · branch = continue on
`codex/redesign-compass-account-hub`. Audit and alternatives:
`docs/superpowers/briefs/2026-07-14-onboarding-redesign-brief.md`.

## Design principle

The current landing sells liveness with a canned card (`CrystalLandingView.liveBriefingCard`:
a hardcoded "LIVE BRIEFING" message + takeaway). The app now owns a deterministic, on-device
engine that computes honest, clock-bounded windows from today's sky with **zero personal
data**. Credibility comes from showing the real thing before asking for anything: real
windows on the landing screen, the real instrument as the guest's first surface, and honest
labels everywhere ("computed on this device", "today only", never outcomes). Nothing labeled
live may ever be canned.

## Flow (after)

```
CrystalLanding (real now-line)                          [restyled, real data]
  ├─ "See today's windows" → AgeGate → GuestCompass     [.predict / .decode intents]
  │     GuestCompass: dial + strip + detail (local)
  │       ├─ guest bearing (1/session, local read) → Reading sheet
  │       └─ "Keep your windows" → SignUp   ·   "Add your chart" → BirthDetails
  └─ chart-first CTA → AgeGate → BirthDetails → FirstExpertRead → SignUp   [.astrologer]
```

`FirstReadOnboardingIntent` keeps all three raw values (persisted): `.predict` and `.decode`
both route to GuestCompass; `.astrologer` routes to BirthDetails, exactly as today.
`AppScreen.firstPrediction` remains the routing case and hosts the new view (zero enum
churn); `AppScreen.firstReadChoice` and `.firstRead` are deleted along with their views.

## Components

**1. Landing now-line (edit `CrystalLandingView.swift`, ~210 lines).** Replace
`liveBriefingCard` with a real current-window line: `DayWindowsEngine` computed in a `.task`
with guest `Inputs` — today's date, the current time zone, nil location, and nil
`natalSun`/`natalMoon`/`natalRising`, `GuidanceStyle.practical` — moon-based windows need
no natal data and no location. Rendering reuses the dial-line
format (title + "until h:mm a", token tick) at landing scale, captioned
"Computed from today's sky · on this device". If the compute fails or hasn't landed,
show the existing static hero copy with no LIVE labeling — never a canned briefing.
Both CTAs stay: `landing.crystal.cta` (value-first) and `landing.crystal.chartCTA`
(chart-first). Crystal ball, portraits, wallpapers, glass materials untouched (owner-locked
assets).

**2. `GuestCompassView` (new file, replaces `FirstPredictionView`).** A deliberately small
composition over the existing instrument components — `CompassNowDial`,
`CompassTodayStrip`, `CompassWindowDetailCard` all take plain values (`DayWindowsResult`,
selection binding, `now`), so they mount without `AppViewModel` auth state. Contents, top to
bottom: dial → strip (+detail on tap) → guest bearings row → sign-up footer. No composer for
guests — chips only, which keeps the surface honest (no half-working form) and small.
- **Guest bearings**: work / love / money chips reusing `CompassBearingItem` +
  `CompassBearingsRow`. Tap runs the **local general-lens read** through the same
  `PredictionService().generatePrediction(request:, tier: "free")` call
  `FirstPredictionView` makes today (no network, no credits, no account), shown in
  `SimulationResultView` ("Reading", TAKEAWAY/EVIDENCE). One completed read per session;
  afterwards the chips route to the sign-up footer instead (soft cap — guests have no
  persistence, so this is UX framing, not enforcement).
- **Footer**: primary "Keep your windows — create an account" → `SignUpView`; secondary
  "Add your chart for timing" → `viewModel.continueToBirthDetails(after:)` (existing).
- Motion: the Stage 4 tokens (`instrumentEnter`/`segmentSelect`, reduce-motion parity) and
  the strip's accessibility-size vertical layout come along for free with the components.
- **Identifiers do not come for free**: `CompassNowDial`/`CompassTodayStrip` hardcode
  `compass.now`/`compass.timeline`, which the authed suite pins and non-goals freeze. The
  components gain an identifier-prefix parameter defaulting to `"compass"` (existing IDs
  stay byte-identical); GuestCompassView passes `"guestCompass"` so the guest surface
  exposes `guestCompass.now`/`guestCompass.timeline` without touching the authed contract.

**3. Structure cleanup (in scope; serves the surface).** `FirstReadChoiceView`,
`FirstPredictionView`, `FirstReadView` currently live inside `DecodeTextView.swift`
(1,658 lines). Delete all three with the two legacy `AppScreen` cases; `DecodeTextView.swift`
shrinks to the decode feature it is named for. `GuestCompassView` is its own file.
Deletion sweep the plan must include: `chooseFirstReadIntent` (dead once
`FirstReadChoiceView` goes), the `-SimastryPreviewScreen firstRead` debug hook, the
`.decode: break` arm in `consumeFirstReadOnboardingIntentIfReady`, and orphaned
`firstReadChoice.*`/`firstRead.*` localization keys. `FeedbackSurface.firstRead`
(a different enum) survives.

**4. Restyle-only screens.** `AgeGateView`, `BirthDetailsView`, `FirstExpertReadView`,
`SignUpView`, `SignInView`: adopt current tokens (materials per the glass rule, motion
tokens, sentence casing, `tabBarEndClearance` insets) with **no logic or routing changes**.
Age-gate copy still precedes any guest computation that touches user input.

## Trust rules (the substance of the credibility goal)

- Guest windows are transiting-sky facts only. With `natal: nil` the engine's provenance
  gate already withholds the all-day natal context line — nothing implies personalization
  that doesn't exist.
- Every window keeps `.calculated` evidence, "today only" scope, favors/leans language;
  the guest read stays general-lens (no timing, no confidence) — `PredictionTrustTests`
  and the 366×3 language lint continue to bind unchanged.
- The word LIVE (or any recency claim) may only label actually-computed data.
- The guest path works fully offline; the existing privacy line ("your question never
  leaves this device" phrasing from `FirstPredictionView`) moves to GuestCompassView.

## Error handling

- Landing engine failure → static hero, no line, no fake.
- Guest read failure → the same inline error treatment `FirstPredictionView` uses today.
- Kill/relaunch mid-funnel → `firstReadOnboardingIntent` persistence (existing
  UserDefaults key) restores the branch, as `OnboardingRoutingTests` already asserts.

## Testing

- `OnboardingRoutingTests`: extend — `.decode` now lands on `.firstPrediction`
  (GuestCompass host case); `.predict` and `.astrologer` assertions unchanged.
- New unit tests: guest engine inputs (nil natal/location) produce ≥3 windows and no
  natal-derived context line; the landing line composer matches the dial-line format and
  falls back to nil on an empty result.
- `testCrystalLandingPagerReachesFirstRead`: retarget — landing → CTA → age gate →
  `guestCompass.now` + `guestCompass.timeline` exist without typing → tap a guest bearing →
  "Reading"/"GENERAL LENS" appears. Chart-first CTA keeps a routing assertion.
- Screenshot baselines: landing + guest Compass on 17pro/17e/AX3/AX5 — these are additions
  to `QA/Screenshots/` (it currently holds only the four compass shots).
- The full verification matrix per stage (xcodegen → Debug+Release → `SimastryTests` →
  listed UITests → screenshots) applies, as in the Compass plan.

## Non-goals

Post-auth `HomeSetupPhase` chain · Stage 7 features · any backend or `supabase/` change ·
new persistence · locked art assets · `compass.*` / `accountHub.*` identifier changes ·
localization keys beyond the screens touched (reuse `LocalizationManager` keys where they
exist; new strings follow the existing key pattern).
