# Consumer visual redesign — design spec

**Date:** 2026-07-08
**Branch:** `polish/visual-pass-five-expert` (baseline `654f4994`)
**Approach:** "Hierarchy redesign" (approved) — keep the 4 tabs and the profile drawer; reorganize each screen around one clear job; consolidate duplicate entry points; unify naming and iconography.

## Goal

Make Simastry feel like Apple built a Liquid Glass iOS 27 astrology app: simple, elegant, practical — complexity abstracted but intuitively accessible, features visibly tied together. Fix the systemic visual inconsistencies found in the 2026-07-08 audit (header misalignment across tabs, Talk clutter, menu-before-content Home, semantic icon confusion, truncation, tab-bar overlap).

## Hard constraints (from owner)

- Approved astrologer portraits and `CouncilKeyArt` stay; do not replace approved assets. Preserve asset dimensions/formats.
- Wallpapers stay: pastel zodiac wallpaper on landing, black mystical cosmic-dust in-app.
- Black liquid-glass tile **material** stays; tile count/content/arrangement may change.
- Tab bar (Home / Predict / Talk / People) and the left profile drawer pattern stay.
- Premium, mystical, realistic — no fantasy/neon/AI-poster styling.
- Every change verified on the iPhone simulator with screenshots (not asset previews).
- Xcode project is generated: edit `Project.json`, run `xcodegen generate`. If repo builds hang (Codex session active), build from a clean mirror copy.

## 1. Foundation (design-system pass)

### 1.1 Header spec — one header for all four tabs
`AppTabFloatingHeader` (App/Views/MainTabView.swift) is the only top chrome on tab roots:

- Anatomy: avatar button (44pt target) · 24pt bold title · `Spacer` · up to **two** 44pt trailing action buttons, all in **one row**, inside each tab's `.safeAreaInset(edge: .top)`.
- Tab roots must NOT add navigation-bar `.toolbar` items (MessagesView.swift:75, PeopleView.swift:116 currently do — their actions move into the header's trailing slot). Pushed/detail screens keep normal nav bars.
- Per-tab trailing slots: Home = compact greeting block (overline date + 15pt "Good evening"; replaces the current oversized `HomeHeaderGreetingSummary`); Predict = none; Talk = search only (the existing message-search sheet, which already doubles as the start-a-conversation people search — no separate compose button, no new surface); People = search, add-person. People's filter control moves inline above the list as chips.
- Result: title Y identical on all tabs by construction.

### 1.2 Avatar spec
Solid 1.2pt ring in the user's sun-sign color (fallback gold) — **no dashed stroke anywhere**. Circle shape everywhere, including the profile drawer (currently a dashed rounded square).

### 1.3 Icon language — one meaning per symbol
- Pastel zodiac discs (`ZodiacSignToken`, App/Views/Components/ZodiacIconView.swift) = **people/sign identity only** (People rows, sign chips). Never feature decoration.
- Feature tiles/rows use SF Symbols in gold on black glass.
- Six shared **category tokens** (icon + stable color), used identically in Predict tiles and expert-intake topic chips: Love `heart.fill`/coral · Marriage `link`/pink · Family `house.fill`/green · Career `chart.line.uptrend.xyaxis`/blue · Money `dollarsign.circle.fill`/gold · Private `lock.fill`/violet. Colors map to existing `SimastryColor` tokens where they exist (`sunCoral`, `celestialBlue`, `gold`, `risingViolet`); add named pink and green members to `SimastryColor` (muted, in-palette) for the two gaps — a token addition, not a new palette.
- `theatermasks.fill` belongs to exactly one feature: Practice.

### 1.4 Naming
- **Practice** = single conversation-practice feature. Absorbs "Quick Simulate" and "Rehearsal Room" (both names retired from UI). Ad-hoc "describe someone new" is Practice's "Someone new" path.
- **"Ask the experts"** = the verb phrase on every CTA opening the five-expert flow. The pinned conversation keeps its entity name "Expert Astrologers". Retire "Open Experts" and expert-flow uses of "Work with an astrologer".
- Sentence case everywhere except proper nouns (fix "Find Others Like You" → "Find others like you", etc.).

### 1.5 Layout constants
- One shared bottom content inset (tab-bar height + breathing room) applied on every scroll surface that sits above the floating tab bar (tab roots and in-tab flows like the expert intake) — content never hides under the bar (currently broken on Home, People, expert intake).
- Copy budgets: tile subtitles ≤3 words; list previews 1 line; sample questions on category tiles one line, no truncation.
- Section headers: one overline style (existing `SimastryFont.overline` treatment) across all tabs.

### 1.6 Glass hierarchy
Exactly three levels: hero card (`simastryGlass`, large radius) · row/tile (`simastryGlass`, 14–16 radius) · pill (`simastryGlassPill`). Existing one-off materials get mapped onto these.

## 2. Talk — "your inbox"

Job: conversations, one primary action.

Top-to-bottom: header (search trailing) → **hero card**: `CouncilKeyArt` group image (not stacked avatars), title "Five experts, one question", one-line sub, single gold CTA **"Ask the experts"** → `CONVERSATIONS` section: pinned "Expert Astrologers" thread row, then person/discovery threads → quiet bordered row **"Practice a conversation"** (masks icon) at the bottom.

Removals/moves:
- "Quick Simulate" button → merges into Practice.
- "What should I reply back?", "Read a message", "Compare all five" buttons → suggestion chips **inside** the ask flow (pre-fill the question box; compare-all-five is the flow's default mode). To be explicit: the "Read a message" chip pre-fills an expert-flow question; it does **not** deep-link to `DecodeTextView` — decode's dedicated entry point is the Home "Decode a text" tile (already wired at HomeView).
- The sparkle/search toolbar pill → header trailing slot (search only, per §1.1).
- Empty state (no threads): same hero + Practice row; no duplicate expert strip, no "Your expert astrologers are ready" block, no "Open Experts" CTA.

## 3. Home — "today's value"

Order: header (compact greeting trailing) → **Today's Note hero** (Leyla portrait, note, "Ask Leyla about this") → **Your daily read** card (focus chip laid out to never collide with the title) → slim **Daily Decider** row (icon + "One tiny next move" + chevron; no longer a tile) → `EXPLORE` section: **4 tiles** on black glass with gold SF Symbols — Ask the experts ("Five traditions") · Practice ("Rehearse a conversation") · Decode a text ("Read between lines") · Birth chart ("Core placements") → any existing content below (situation/people strip) unchanged in this pass.

Removals: "Browse all" label; Journal tile (drawer's "Private journal" is the single entry point); zodiac-glyph discs on feature tiles.

## 4. Predict — "the reading, immediately"

- Remove the Rehearsal Room promo card (SimulateView.swift `rehearsalRoomCard`).
- Remove the "1 Choose — 2 Details — 3 Answer" stepper and the "①" numbered-card chrome; "What are we reading?" becomes a plain section title with the category grid directly beneath; the guided flow itself (details → answer) is unchanged.
- Category tiles use the six shared category tokens (§1.3); sample questions rewritten to fit one line.

## 5. People — "your people"

- Header trailing: search + add. Filters become inline chips above the list.
- The three stacked hero cards compress to one: keep the gold **Best next move** strip; "Relationship memory · N people · private" becomes a caption in the list section header; "Read this group" becomes a compact pill beside that header.
- "Recent reads" + "All people" merge into one list (recency-sorted). One sign indicator per row (the pastel disc); remove the duplicate trailing sign chip and decorative people-glyphs after names.
- Person detail gains a **"Practice a conversation"** action (routes to Practice pre-targeted at that person).

## 6. Expert intake (Ask the experts)

- `CouncilKeyArt` banner at top — the five are visible before the form.
- One headline: **"Ask once. Five traditions answer."** (delete the duplicate gold subhead).
- Context chips: horizontally scrollable with an edge fade.
- Topic chips: the six shared category tokens (§1.3).
- Expert picker ("Who would you like to hear from?"): default all five selected; respects the shared bottom inset (currently half-hidden by the tab bar).

## 7. Practice consolidation (mechanics)

- `RehearsalRoomView` is the surviving surface, user-facing title "Practice".
- `QuickSimulateSheet`'s describe-someone form becomes the "Someone new" path inside Practice's person picker.
- `AppViewModel.openQuickSimulate()` → `openPractice()`; deep link `simastry://simulate` and shortcut destination `simulate` remain as aliases.
- Entry points after consolidation: Talk bottom row · person detail action · Home Explore tile. (Predict promo removed.)

## 8. Small fry (same pass)

- Profile drawer: circular solid-ring avatar; sentence-case items; expert-flow labels name their destination.
- Landing (`CrystalBallView.swift`): add a keep-out band so dispersed zodiac discs never overlap the orbiting expert portraits.
- Upsell, ModeSelection, Discovery, OnboardingProgress surfaces: inherit header/casing/inset/glass tokens — polish only, no restructure.

## Non-goals

- No tab-bar changes (names, order, icons), no drawer→sheet migration.
- No new features, no backend/prompt changes, no monetization flow changes.
- No asset replacement.
- No copy rewrites beyond the surfaces named above.

## Verification requirements

Each implementation stage ends with: build (mirror workaround if repo hangs) → install → launch relevant `-SimastryPreviewScreen`/seed states → screenshot → visually confirm against this spec. Screens to re-check at the end (owner's QA list): landing, home/today, expert astrologers list, individual expert profile, messages, predict, people, profile, upsell. `SimastrySmokeUITests` green before the final commit; accessibility identifiers referenced by UI tests must be preserved or updated in the same change.

## Implementation staging (suggested commit boundaries)

1. Foundation: header unification + avatar + insets + casing (S1/S2 fixes visible on all tabs).
2. Talk restructure + ask-flow suggestion chips.
3. Practice consolidation (Talk row, person action, Home tile, routing).
4. Home reorder + Explore grid.
5. Predict simplification + shared category tokens (Predict + intake).
6. People compression + intake banner/headline.
7. Small fry + full QA sweep.
