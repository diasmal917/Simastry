# Audit — `codex/premium-bottom-navigation`

Scope: the 33 commits merged from `codex/premium-bottom-navigation`
(~24k lines, 701 files: redesigned tab navigation, People/Situations,
Panel chat, Moments, Practice/Simulation Room, Sealed Drafts, Decode,
Life Lenses, Method course, invite flow, `companion-reply` edge function,
and 300 new companion images). Static review on Linux — no Xcode build;
every finding below was verified against surrounding code, not just
pattern-matched. Items marked **(pre-existing)** were already on `main`
but still ship in this build.

> **Fixes applied on this branch** (commit after the report): H1 — auth
> check is now tri-state (`SupabaseService.authState()`) and only a
> definitive sign-out wipes local state; H2 — `$(PRODUCT_BUNDLE_IDENTIFIER)`
> restored to `CFBundleURLSchemes`; H3 — both Simulate paths now decide the
> funding source up front and charge exactly one pool, only after success;
> H5 — the developer menu trigger is `#if DEBUG`-gated. The remaining
> findings below are unfixed.

---

## High

**H1. Transient auth failure permanently wipes all local user data.**
`AppViewModel.swift` `checkAuthState()` → `clearAccountScopedLocalState()`.
`SupabaseService.isAuthenticated()` returns `false` whenever
`client.auth.session` *throws* — which includes a failed token refresh
(cold launch offline with an expired access token) or Supabase being
unreachable, not just "signed out". `checkAuthState` runs on every
launch, and on `false` it irreversibly deletes panel messages, panel
memory, all Moments photos (directory removed), relationship people,
saved guides, companion history, sealed drafts, practice threads,
method-course progress, bonus predictions, and the profile image. All of
this data is device-local only, so signing back in restores nothing. The
wipe predates the branch, but the branch wires nearly every new feature
store into it, massively expanding the blast radius. Fix: only wipe on
explicit sign-out; distinguish "no session" from "session check failed".

**H2. Google sign-in can no longer return to the app (regression).**
`SupabaseService.swift:26-27` builds the OAuth redirect as
`app.rork.simastry://auth/callback` (bundle id as scheme). The branch
moved `CFBundleURLTypes` out of `project.pbxproj` into the new
`ios/SupportingFiles/Simastry-Info.plist` — and dropped
`$(PRODUCT_BUNDLE_IDENTIFIER)` from `CFBundleURLSchemes`, leaving only
`simastry`. The browser redirect after Google sign-in can't reopen the
app. Fix: add `$(PRODUCT_BUNDLE_IDENTIFIER)` back to the scheme array
(or change the redirect to `simastry://auth/callback` and update the
Supabase redirect allow-list).

**H3. Paid prediction credits are mischarged.**
`SimulateView.swift:824-831` and `888-895`: when the weekly quota is
exhausted, `bonusPredictions -= 1` runs *before* `generatePrediction`.
If generation throws (network error, privacy block, empty response) the
credit is never refunded — the regular weekly quota, by contrast, is only
consumed after success. On success the path *also* calls
`consumePrediction()`, so a single bonus-funded prediction charges both
pools. Bonus packs are sold for real money ($0.99–$4.99), so this is
charging users for failures and double-billing successes.

**H4. ~364 MB of images in the asset catalog.**
The branch adds 300 companion images (`Factory_*` cards/posts/profiles),
many 1.9–2.2 MB PNGs, for a catalog now totaling ~364 MB — an enormous
App Store download for this app. 38 files are byte-identical duplicates
(e.g. `*_profile.jpg` duplicating `*_card.jpg` / a post image). Fix:
re-encode the PNG photos as JPEG/HEIC at display resolution, alias
duplicates to one imageset, and consider on-demand resources or remote
hosting for the 10-post galleries.

**H5. (pre-existing) Hidden dev menu grants Pro in production.**
`ProfileView.swift:1721-1731, 1880-1896`: triple-tapping the
"Simastry v1.0.0" footer opens a "Developer Menu" with Free/Plus/Pro
buttons calling `applyTierOverride` — no `#if DEBUG` gate, and the
override is upserted to the server profile. With RevenueCat unconfigured
the override is never corrected, permanently unlocking every paid limit.
Predates the branch, but the branch ships far more premium surface gated
on the same field.

## Medium

**M1. (pre-existing) `purchasePredictionPack` grants packs without
charging.** `AppViewModel.swift:213-219` just calls
`addBonusPredictions` (RevenueCat TODO unshipped) while
`PredictionTopUpView` shows real prices on the buy buttons — free product
today, App Store compliance problem the moment IAP review sees prices
without transactions.

**M2. Prediction history survives sign-out and account deletion.**
`PredictionService` stores history (including users' pasted conversation
text) under `simastry_prediction_history`; neither
`clearAccountScopedLocalState()` nor `clearAllLocalData()` removes that
key — every other store was added to the wipe list, this one was missed.
On a shared device, user B sees user A's conversations in Simulate
history, and the branch newly feeds that history into the panel daily
starter and weekly recap.

**M3. Invite rewards are fully client-trusted.**
`AppViewModel+Invites.swift:34-62`: any format-valid code — including a
made-up one opened via `https://simastry.com/invite?code=AAAAAA` — grants
5 bonus predictions with no server check and no confirmation; the
once-only guard is a UserDefaults bool reset by reinstalling.

**M4. Account deletion leaves authored content on the server.**
`deleteAccount` removes companions/profile/social profile, but
`discovery_messages` (message text, both parties' names and signs),
`discovery_blocks`, and `discovery_reports` are never deleted.

**M5. Unsaved person notes are silently destroyed.**
`PeopleView.swift:789`: the detail view re-seeds its editable
`@State` from the model in `onAppear`, which re-fires on every return to
the tab — and the screen's own "Predict their reply" / "Decode their
text" buttons switch tabs. Typed-but-unsaved notes/labels are wiped.

**M6. Practice "Clear rehearsal" races the pending reply.**
`PracticeChatView.swift:75` clears messages without cancelling
`replyTask` (`:245`); the in-flight task then appends the persona reply
and re-persists the thread the user just deleted. Related: a cancelled
task's `try? await Task.sleep` swallows the cancellation, so the LLM call
still runs for a dismissed screen and `isReplying` can leak `true`,
permanently disabling the send button.

**M7. Out-of-quota "See New Response" looks dead.**
`SimulateView.swift:180-183, 892`: `regenerate` sets
`showTopUpSheet = true` while the result sheet (a sibling `.sheet`) is
still presented, so the top-up sheet can't appear.

**M8. Panel/DM threads degrade with age.**
Panel messages are never pruned (practice threads are capped at 40;
panel has no cap), `sortedPanelMessages` re-sorts the whole array every
body evaluation, and both `PanelChatView` and `MessageDetailSheet`
render full history in non-lazy `VStack`s — linear slowdown forever.

**M9. Streak milestone toast is dead (regression).**
`HomeView.swift:19, 167-180`: the redesign deleted the toast view but
kept the trigger; `showStreakMilestone` is written and never read.
Day 3/7/14/30 celebrations silently never show.

**M10. "Manage Subscription" doesn't manage subscriptions.**
`ProfileView.swift:1070-1077`, `SimastrySettingsView.swift:132-143`: for
paid tiers the button opens the purchase upsell modal; there's no path to
Apple's manage/cancel UI even though the app's own ToS text points there.

**M11. Chinese zodiac wrong for Jan–mid-Feb birthdays.**
`NumerologyTemplates.swift:61-65` uses the Gregorian year, ignoring the
Lunar New Year boundary the card's own copy describes (e.g. Feb 1 2000 →
shown Dragon, actually Rabbit).

**M12. Widget sources are dead code.**
`ios/SimastryWidget/` is not a member of any target (only app/tests
targets exist in the pbxproj), despite the new Info.plist comment
claiming the scheme "powers widget tap-through".

**M13. Duplicate panel-guide IDs for same-sign charts.**
`PanelMatcher.swift:24`: the catalog has exactly 2 guides per sign, and
the `?? candidates.first` fallback re-picks a used profile when Sun =
Moon = Rising (a real chart: born near dawn around a new moon).
`Entry.id == profile.id`, so `ForEach` gets duplicate IDs in HomeView,
OnboardingInsightView, MomentsSection, and the panel — SwiftUI
duplicate-ID undefined behavior, and `panelGuideEntry(forParticipantId:)`
can only resolve the first role.

**M14. No-op "Add attachment" button.**
`MessagesView.swift:841-849`: the DM composer's "+" button (with a
VoiceOver label) fires a haptic and nothing else.

**M15. UI bits that silently fail.**
ToastOverlay's un-cancelled 4s dismiss task hides a newer toast after
~1s and can nil it entirely; GlossyOrbView only starts animations in
`onAppear`, so the soul-creation orb's `.active` glow renders frozen;
Moments' photo `loadTransferable` failure gives no feedback;
ShareableCardView's Save does nothing when Photos permission was denied;
PeopleView's photo pickers never reset `selectedPhotoItem`, so
re-selecting the same photo does nothing.

## Low

- **Entitlement dropped when profile fetch fails** — a Pro subscriber
  with a flaky connection gets free-tier limits until a profile fetch
  succeeds; the loaded RevenueCat entitlement is discarded
  (`AppViewModel.swift:893-911`).
- **Repeating notifications with stale day-specific content** —
  `scheduleDailyTransit` (and daily brief / panel starter) install
  repeating 8:30 triggers carrying one computed day's text; the
  `(dayOfYear + 1) % 3` focus math also diverges at the year boundary.
- **Decode-failure destroys data** — `loadSavedGuides`, `loadMessages`,
  `loadPanelMessages` delete the persisted blob on any `JSONDecoder`
  failure instead of preserving it for migration.
- **Prediction draft routing** — a stale mounted Predict screen consumes
  `predictionDraft` so the newly pushed one arrives empty; repeated route
  requests stack duplicate Predict/Decode screens.
- **Deep links during onboarding are dropped** — `presentRoutesIfRequested`
  guards on `homeSetupPhase == .complete` with no re-trigger when the
  phase completes.
- **Localization drift** — en renamed the tile to "Messages"; es ("Predecir")
  and pt-BR ("Prever") still say Predict (`LocalizationManager.swift:85/179/273`).
- **Stale "copied" UI** — DecodeTextView's `copiedReplyIndex` survives
  re-decoding (new replies show "Reply copied"); PersonPlaybookView's
  un-cancelled `asyncAfter` clears a fresh copy indicator early.
- **Panel typing-indicator race** — dedup is checked at schedule time but
  the ID is inserted after the staggered sleep, so rapid sends kill the
  indicator mid-generation (`AppViewModel+PanelChat.swift:282/291`).
- **Untrimmed private label** — `PeopleView.swift:1045` checks the
  trimmed value but stores the raw string.
- **Always-on animations** — 14s `repeatForever` Ken Burns on the
  permanently mounted Today tab (`HomeView.swift:958`); pre-existing
  all-day flame pulse on milestone days (`ProfileView.swift:390`).
- **Doubled appear animation** — `SimulationResultView` applies
  `cascaded()` opacity/offset on top of each section's own
  `appeared`-driven opacity/offset: 36 pt combined offset, two competing
  animation phases.
- **CoupleRead duplicate ForEach IDs** — `id: \.self` over two template
  strings that are identical when both people share name + Sun sign.
- **Dead code** — unreachable "Discovery Coming Soon" branch
  (`ProfileView.swift:619-695`, outer gate added without removing inner
  `else`); `showReferralConfirmation` bound to nothing; `appeared` state
  and `MessageRow.zodiacSign` unused in MessagesView; orphaned
  `GuidesView`/`UsageRingView`/`AstropediaView`/`CompanionsView`;
  `DeepLink.from(url:)` can't parse its own `.home` URL; unneeded
  `NSMotionUsageDescription`; stale pbxproj group comments.
- **Edge function nits** (`companion-reply/index.ts`) — a non-numeric
  `maxTokens` becomes NaN and turns into an opaque 502; server-side
  per-user quota is still a TODO, so client rate limits are advisory; a
  rejected `fetch` (network error) escapes the handler as a CORS-less 500.
- **Test posture** — `RedesignScrollVerificationTests` contains zero
  assertions (screenshot harness only — fine, but it isn't regression
  coverage); several suites rely on wall-clock sleeps and share
  `UserDefaults.standard` while Swift Testing runs suites in parallel
  (flake risk on CI).

## Verified clean

- **Secrets**: no real keys anywhere; `Config.swift` ships empty stubs;
  the Anthropic key exists only as a Supabase edge-function secret read
  via `Deno.env.get`. The edge function caps prompt size and tokens and
  is JWT-gated.
- **Privacy/permissions**: Moments and OCR import use `PhotosPicker` +
  on-device Vision (no permission strings required, correctly none
  declared); the only photo-library write is covered by the present
  `NSPhotoLibraryAddUsageDescription`; notifications are local-only; no
  message content/PII in notification bodies; prediction prompts pass
  through redaction with a blocking path.
- **Project integrity**: objectVersion 77 file-system-synchronized
  groups, so all ~100 new Swift files and test files compile without
  pbxproj entries; `INFOPLIST_FILE` + `GENERATE_INFOPLIST_FILE` merging
  is wired correctly (modulo H2).
- **Codable round-trips**: all model changes are additive
  (optionals/`decodeIfPresent` with defaults); no enum raw values
  changed; persisted stores pair `.iso8601` strategies consistently.
- **Crash surface**: no force unwraps on dynamic data found anywhere in
  the new code; every `% count` index is behind a non-empty guard; all
  sign-keyed template tables cover all 12 signs with matching key
  conventions; all 288 `Factory_*` image assets referenced by the
  24-guide catalog exist.
- **Concurrency**: `AppViewModel` is `@MainActor`; deferred guide work is
  tracked, cancellable, and generation-guarded against the wipe race;
  `GuideReplyService` timeout group is sound.
- **Navigation**: tab remap (legacy 3/4 → 0) verified against every
  `selectedTab` writer; route-request counter patterns are monotonic and
  loop-free; every notification/widget-emitted deep link has a route.

## Suggested priority

1. H1 (data wipe), H2 (Google sign-in), H3 (credit charging) — fix
   before any release.
2. H4 (asset size) — decide hosting/compression strategy before App
   Store submission; H5/M1 — remove the dev menu and gate or wire the
   top-up purchase before review.
3. M2–M4 (privacy/server hygiene), then the UX/medium items.
