# Consumer Visual Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved hierarchy redesign (spec: `docs/superpowers/specs/2026-07-08-consumer-visual-redesign-design.md`) — unified tab header, Talk-as-inbox, value-first Home, de-chromed Predict, compressed People, Practice consolidation, shared category tokens.

**Architecture:** SwiftUI app, XcodeGen project (`Project.json` → `xcodegen generate`; never commit `Simastry.xcodeproj/` or `App/Info.plist`). All UI changes verified on the iPhone 17 Pro simulator via DEBUG launch args + screenshots. UITests (`UITests/SimastrySmokeUITests.swift`) are the regression harness — identifier changes land in the same task as the UI change.

**Tech Stack:** Swift 6 / SwiftUI, XcodeGen 2.45, iOS 26.2 SDK, simctl.

**Baseline:** branch `polish/visual-pass-five-expert`, commit `a65d8747`.

**Hard constraints (owner):** approved portraits + `CouncilKeyArt` untouched; wallpapers untouched; black glass tile material stays; tab bar and profile drawer pattern stay; premium/mystical/realistic; every stage screenshot-verified on the simulator.

---

## Verification harness (used by every task)

**The repo build HANGS while a Codex.app session is active** (xcodebuildmcp contention). Always build from a scratch mirror.

### Task 0: Commit the verify script

**Files:**
- Create: `scripts/dev/redesign-verify.sh`

- [ ] **Step 1: Create the script** (exact content):

```bash
#!/bin/zsh
# Build Simastry from a clean mirror (repo builds hang while Codex is active),
# install on the iPhone 17 Pro sim, launch with the given args, screenshot.
# Usage:
#   scripts/dev/redesign-verify.sh build
#   scripts/dev/redesign-verify.sh shoot <name> <wait-seconds> [launch-args...]
#   scripts/dev/redesign-verify.sh landing <name>       # fresh-install, signed-out
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${SIMASTRY_VERIFY_DIR:-$HOME/.cache/simastry-verify}"
MIRROR="$WORK/mirror"; DD="$WORK/DerivedData"; OUT="$WORK/shots"
BUNDLE="app.bitrig.new.97a916bd-b131-48aa-a70e-082a3526b819"
SIM="${SIMASTRY_SIM_UDID:-$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 17 Pro \(/{print $2; exit}')}"
APP="$DD/Build/Products/Debug-iphonesimulator/Simastry.app"
mkdir -p "$MIRROR" "$OUT"

case "${1:-}" in
build)
  rsync -a --delete \
    --exclude '.git' --exclude 'build' --exclude 'output' --exclude 'website' \
    --exclude 'reports' --exclude 'node_modules' --exclude 'Simastry.xcodeproj' \
    "$REPO/" "$MIRROR/"
  cd "$MIRROR" || exit 1
  xcodegen generate --spec Project.json || exit 1
  xcodebuild -project Simastry.xcodeproj -scheme Simastry -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build > "$WORK/build.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then echo "BUILD FAILED"; grep -m8 -B2 "error:" "$WORK/build.log"; exit 1; fi
  tail -2 "$WORK/build.log"
  xattr -cr "$APP"
  find "$APP" \( -name '*.dylib' -o -name '*.framework' -o -name '*.appex' \) -print0 |
    while IFS= read -r -d '' i; do codesign --force --sign - "$i" 2>/dev/null; done
  codesign --force --sign - "$APP/Simastry" 2>/dev/null
  codesign --force --sign - "$APP" 2>/dev/null
  xcrun simctl boot "$SIM" 2>/dev/null; open -a Simulator
  xcrun simctl install "$SIM" "$APP" || exit 1
  echo "BUILD+INSTALL OK ($SIM)"
  ;;
shoot)
  name=$2; wait=$3; shift 3
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null
  xcrun simctl launch "$SIM" "$BUNDLE" "$@" >/dev/null || { echo "LAUNCH FAIL"; exit 1; }
  python3 -c "import time,sys; time.sleep(float(sys.argv[1]))" "$wait"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$OUT/$name.png"
  ;;
landing)
  name=$2
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null
  xcrun simctl uninstall "$SIM" "$BUNDLE"; xcrun simctl install "$SIM" "$APP"
  xcrun simctl launch "$SIM" "$BUNDLE" >/dev/null
  python3 -c "import time; time.sleep(8)"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$OUT/$name.png"
  ;;
*) echo "usage: build | shoot <name> <wait> [args...] | landing <name>"; exit 2;;
esac
```

- [ ] **Step 2:** `chmod +x scripts/dev/redesign-verify.sh`
- [ ] **Step 3: Baseline sanity run:**

```bash
scripts/dev/redesign-verify.sh build
scripts/dev/redesign-verify.sh shoot baseline-home 7 -SimastryPreviewSeeded
```
Expected: `BUILD+INSTALL OK`, then a PNG path. **Open the PNG and look at it** — it must match the current Home (6-tile grid).

- [ ] **Step 4: Commit**

```bash
git add scripts/dev/redesign-verify.sh
git commit -m "Add the redesign verification harness script"
```

**Screenshot reference states** (used below): Home `-SimastryPreviewSeeded` · Predict `… -SimastryPreviewScreen predict` (wait 9) · Talk `… -SimastryPreviewScreen panelInbox` · Expert intake `… -SimastryPreviewScreen astrologists` (wait 9) · People `… -SimastryPreviewTab 1` · Profile drawer `… -SimastryPreviewScreen invite` (wait 8) · Landing `landing` subcommand.

**Running a single UITest** (from the MIRROR, same hang caveat):

```bash
cd "$HOME/.cache/simastry-verify/mirror"
xcodebuild test -project Simastry.xcodeproj -scheme Simastry \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:SimastryUITests/SimastrySmokeUITests/<testName> 2>&1 | tail -20
```
(Re-run `scripts/dev/redesign-verify.sh build` first whenever repo files changed, to refresh the mirror. UITests build their own app — the unsigned-build workaround is already handled because tests run from the mirror where the provenance xattr has not been stamped by a GUI launch.)

---

## Stage 1 — Foundation: one header, solid avatar, insets, casing

### Task 1: Header trailing-slot API + solid avatar ring + compact greeting

**Files:**
- Modify: `App/Views/MainTabView.swift:68-157` (`AppTabFloatingHeader`, `HomeHeaderGreetingSummary`)
- Modify: `App/Views/Components/ProfileImageView.swift:56` (dashed stroke)
- Modify: `App/Views/ProfileView.swift:313` (drawer avatar dash + shape)

- [ ] **Step 1:** In `MainTabView.swift`, give `AppTabFloatingHeader` a generic trailing slot. Replace the struct declaration and body plumbing:

```swift
struct AppTabFloatingHeader<Trailing: View>: View {
    @Bindable var viewModel: AppViewModel
    @ViewBuilder var trailing: () -> Trailing

    init(viewModel: AppViewModel, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.viewModel = viewModel
        self.trailing = trailing
    }
    // body unchanged except: replace the current
    //     if viewModel.selectedTab == .today { HomeHeaderGreetingSummary() }
    // block with:
    //     if viewModel.selectedTab == .today { HomeHeaderGreetingSummary() }
    //     trailing()
}
```

Existing call sites (`AppTabFloatingHeader(viewModel: viewModel)`) keep compiling via the default argument.

- [ ] **Step 2:** Shrink the greeting (`HomeHeaderGreetingSummary`, MainTabView.swift:126-157): date line stays `SimastryFont.overline`; greeting line changes from `SimastryFont.displayMedium` to `.font(.system(size: 15, weight: .medium))`. Keep the `frame(width: 154)`? No — drop the fixed width, use `.fixedSize()`; the smaller type no longer needs reserved width.
- [ ] **Step 3:** Solid avatar ring: in `ProfileImageView.swift:56` replace `StrokeStyle(lineWidth: 1.5, dash: [6, 4])` with `StrokeStyle(lineWidth: 1.5)`. In `ProfileView.swift:313` replace `StrokeStyle(lineWidth: 1.5, dash: [4, 4])` with `StrokeStyle(lineWidth: 1.5)`, and make the drawer avatar container a `Circle()` if it is currently a `RoundedRectangle` (check the shape at ProfileView.swift:300-320 and swap both the clip shape and the stroke shape to `Circle()`).
- [ ] **Step 4:** Build + verify: `scripts/dev/redesign-verify.sh build && scripts/dev/redesign-verify.sh shoot t1-home 7 -SimastryPreviewSeeded && scripts/dev/redesign-verify.sh shoot t1-drawer 8 -SimastryPreviewSeeded -SimastryPreviewScreen invite`
  Expected in the PNGs: solid (not dashed) ring on the header avatar; drawer avatar circular with solid ring; greeting visibly smaller than the "Home" title.
- [ ] **Step 5: Commit** — `git add -A App/ && git commit -m "Unify the tab header API and solidify the avatar ring"`

### Task 2: Talk + People lose their nav toolbars (title alignment fix)

**Files:**
- Modify: `App/Views/MessagesView.swift:69` (header mount), `:74-102` (delete `.toolbar` block), `:195` (`toolbarActionIcon` — reuse)
- Modify: `App/Views/PeopleView.swift:106` (header mount), `:111-142` (delete `.toolbar` + `.searchable` + `MinimizedSearchToolbar`), inline filter chips + search field above the list
- Test: `UITests/SimastrySmokeUITests.swift:456` (`talk.toolbar.newMessageButton`), `:people.toolbar.addPersonButton` usages

- [ ] **Step 1:** MessagesView — delete the whole `.toolbar { … }` block (lines 74-102) and `.toolbarColorScheme(.dark, for: .navigationBar)` on the tab root. Change the header mount to:

```swift
.safeAreaInset(edge: .top, spacing: 0) {
    AppTabFloatingHeader(viewModel: viewModel) {
        Button {
            HapticManager.buttonPress()
            showMessageSearch = true
        } label: {
            toolbarActionIcon(systemName: "magnifyingglass")
        }
        .accessibilityLabel("Search experts and users")
        .accessibilityIdentifier("talk.toolbar.newMessageButton")
        .buttonStyle(.plain)
    }
}
```
(Keep the identifier string — the smoke test at UITests line 456 taps it. The sparkle/experts toolbar button is deleted; the Stage-2 hero CTA covers that entry. Until Stage 2 lands, the Expert Astrologers inbox row still provides access — acceptable within the same PR.)

- [ ] **Step 2:** PeopleView — delete the `.toolbar { … }` block (filter menu + add button), `.searchable(...)`, and `.modifier(MinimizedSearchToolbar())`. Mount header actions:

```swift
.safeAreaInset(edge: .top, spacing: 0) {
    AppTabFloatingHeader(viewModel: viewModel) {
        Button {
            withAnimation(SimastrySpring.snappy) { isSearchExpanded.toggle() }
        } label: { headerActionIcon("magnifyingglass") }
        .accessibilityLabel("Search people")
        .buttonStyle(.plain)

        Button {
            presentAddPerson()
        } label: { headerActionIcon("plus") }
        .accessibilityLabel("Add person")
        .accessibilityIdentifier("people.toolbar.addPersonButton")
        .buttonStyle(.plain)
    }
}
```
Add `@State private var isSearchExpanded = false`. Add a `headerActionIcon(_:)` helper mirroring MessagesView's `toolbarActionIcon` (44pt target, gold glyph on `simastryGlassPill`-style circle) — put it in `MainTabView.swift` next to `AppTabFloatingHeader` as a shared `HeaderActionIcon` view so both tabs use one implementation (DRY).
- [ ] **Step 3:** PeopleView — above the list content, add (a) when `isSearchExpanded`, a `TextField("Search people or signs", text: $searchText)` styled with `.simastryGlassPill()`, and (b) a horizontal chip row replacing the filter menu: an "All" chip plus one chip per `RelationshipType.allCases` binding `selectedType` (chip = `simastryGlassPill(interactive: true)`, gold text when selected). The existing `searchText`/`selectedType` filtering logic is already wired — only the controls move.
- [ ] **Step 4:** Build + verify: `scripts/dev/redesign-verify.sh build && scripts/dev/redesign-verify.sh shoot t2-talk 7 -SimastryPreviewSeeded -SimastryPreviewScreen panelInbox && scripts/dev/redesign-verify.sh shoot t2-people 7 -SimastryPreviewSeeded -SimastryPreviewTab 1 && scripts/dev/redesign-verify.sh shoot t2-home 7 -SimastryPreviewSeeded`
  Expected: **"Talk", "People", "Home" titles at the identical Y position** (compare the three PNGs side by side — this is the headline fix); search/add icons inside the title row; filter chips above the People list.
- [ ] **Step 5:** Run the two affected smoke tests (`testMessageSearchSheet…` covering `talk.toolbar.newMessageButton`, and the add-person flow covering `people.toolbar.addPersonButton`) per the harness note. Expected: PASS.
- [ ] **Step 6: Commit** — `"Move tab actions into the shared header; align all tab titles"`

### Task 3: Casing + drawer labels

**Files:**
- Modify: `App/Views/ProfileView.swift:1040` ("Find Others Like You" → "Find others like you"; scan the drawer menu at :894-940 for any other Title Case)

- [ ] **Step 1:** Fix the strings. `grep -n "Find Others Like You" App/Views/ProfileView.swift` → replace both occurrences (menu row ~574 area and title ~1040) with "Find others like you".
- [ ] **Step 2:** Build + shoot the drawer (`t3-drawer`, args as Task 1) — confirm sentence case.
- [ ] **Step 3: Commit** — `"Sentence-case the drawer menu"`

---

## Stage 2 — Talk restructure

### Task 4: Experts hero card + inbox-first layout

**Files:**
- Modify: `App/Views/MessagesView.swift` — `body` (:32-64 empty/list branches), `talkActions` (:254-326), `messageList` (:407-440)
- Create (in-file): `TalkExpertsHeroCard` view struct in MessagesView.swift
- Test: `UITests/SimastrySmokeUITests.swift:526-535` (quick-simulate flow — updated in Task 6)

- [ ] **Step 1:** Add the hero (uses the approved council group image — do not crop/replace the asset):

```swift
private struct TalkExpertsHeroCard: View {
    let onAsk: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("CouncilKeyArt")
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .clipped()
            VStack(spacing: 4) {
                Text("Five experts, one question")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Each tradition reads it separately.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
                Button {
                    HapticManager.buttonPress()
                    onAsk()
                } label: {
                    Label("Ask the experts", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SimastryPrimaryButtonStyle())
                .padding(.top, 8)
                .accessibilityIdentifier("talk.askExpertsButton")
            }
            .padding(14)
        }
        .background(SimastryColor.surfaceElevated.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .simastryGlass(cornerRadius: 22)
    }
}
```
(If `SimastryPrimaryButtonStyle` is not gold-filled, check `SimastryDesign.swift:676` and use the gold-filled style the landing "Get Started" uses.)

- [ ] **Step 2:** Restructure `talkActions` → rename to `legacyTalkActions` and keep ONLY for `!AppConfig.expertAstrologersEnabled` (the legacy panel build). For the experts path, both branches of `body` compose:
  - empty branch: `TalkExpertsHeroCard(onAsk: { openExpertAstrologers() })` → `CONVERSATIONS` overline header → `ExpertAstrologerInboxRow` → (existing empty/loading states) → practice row (Step 3).
  - `messageList`: replace the leading `talkActions` row with the hero card row; add a `Text("CONVERSATIONS")` overline (font `SimastryFont.overline`, color `SimastryColor.textTertiary`, tracking 1.4) as a list row above `ExpertAstrologerInboxRow`; append the practice row after the `ForEach`.
  - Delete the "Quick Simulate", "What should I reply back?", "Read a message", "Ask an expert", "Compare all five" buttons from the experts path entirely.
- [ ] **Step 3:** Practice row (bottom of both branches, experts path):

```swift
private var practiceRow: some View {
    Button {
        HapticManager.buttonPress()
        activeTalkSheet = .practiceHub
    } label: {
        HStack(spacing: 12) {
            Image(systemName: "theatermasks.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SimastryColor.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Practice a conversation")
                    .font(SimastryFont.titleSmall)
                    .foregroundStyle(SimastryColor.offWhite)
                Text("Rehearse with a stand-in.")
                    .font(SimastryFont.captionSmall)
                    .foregroundStyle(SimastryColor.mutedSilver)
            }
            Spacer(minLength: 6)
            Image(systemName: "chevron.right")
                .font(SimastryFont.caption)
                .foregroundStyle(SimastryColor.mutedSilver)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simastryGlass(cornerRadius: 16)
        .contentShape(.rect)
    }
    .buttonStyle(SpringPressStyle())
    .accessibilityIdentifier("talk.practiceButton")
}
```
`.practiceHub` is added to `TalkSheet` in Task 5 — for THIS task, wire it to the existing `.quickSimulate` case so the build stays green, with a `// Task 5 rewires to Practice` comment.
- [ ] **Step 4:** Suggestion chips inside the ask flow: in `App/Views/ExpertAstrologersView.swift`, above the topic chips in the question card, add a two-chip suggestions row that pre-fills the question `TextField`/`TextEditor` binding: "What should I reply back?" and "Help me read a message I got". Style: `simastryGlassPill(interactive: true)`. (This preserves the two deleted Talk buttons' intent; compare-all-five is already the flow's default.)
- [ ] **Step 5:** Build + verify: shoot `t4-talk-empty` (fresh seed shows threads; for the empty state also shoot after `xcrun simctl uninstall`+reinstall+seeded launch — the seeded state includes threads, so verify the list branch primarily) and `t4-talk` (panelInbox args). Expected: council group photo hero with single gold CTA; overline CONVERSATIONS; inbox rows; practice row at the bottom; none of the five old buttons.
- [ ] **Step 6:** Run smoke test for the expert flow (the test tapping `talk.toolbar.expertAstrologersButton` — if a test references that deleted identifier, update it to `talk.askExpertsButton` now). `grep -n "talk.toolbar.expertAstrologersButton" UITests/SimastrySmokeUITests.swift` → update taps. Run those tests. Expected: PASS.
- [ ] **Step 7: Commit** — `"Rebuild Talk as an inbox with one Ask-the-experts hero"`

---

## Stage 3 — Practice consolidation

### Task 5: One Practice feature (Rehearsal Room absorbs Quick Simulate)

**Files:**
- Modify: `App/Views/RehearsalRoomView.swift` (user-facing title → "Practice"; person picker gains "Someone new")
- Modify: `App/Views/MessagesView.swift` (`TalkSheet` :4-15, sheet switch :147-153, `QuickSimulateSheet` :591+ — form extracted/reused; `presentQuickSimulateIfRequested` :358)
- Modify: `App/ViewModels/AppViewModel.swift:661-665` (`openQuickSimulate` → `openPractice` + alias), deep-link `case "simulate"` :1240, `navigateToDeepLink .simulate` :1317, shortcut `case "simulate"` :1336
- Modify: `App/Views/SimulateView.swift:245-279` (delete `rehearsalRoomCard`), `:291` (remove from stack), `:326-328` (remove sheet), `:16` (remove `showRehearsalRoom`)
- Modify: `App/Views/PeopleView.swift:464+` (`RelationshipPersonDetailView` — add "Practice a conversation" action row)
- Test: `UITests/SimastrySmokeUITests.swift:38-66` (rehearsal test entry), `:526-535` (quick-simulate test)

- [ ] **Step 1 (test first):** Update `testRehearsalRoomRunsAPracticeTurn` (UITests :38): entry changes from Predict (`predict.rehearsalRoomButton`, swipe-reveal) to Talk: navigate to the Talk tab, tap `talk.practiceButton`, then the existing `rehearsal.*` identifiers continue unchanged. Update `testQuickSimulate…` (:526): replace `talk.quickSimulateButton` with `talk.practiceButton` → tap the "Someone new" option (`practice.someoneNewButton`) → the existing name-field flow (`talk.quickSimulate.nameField` → rename to `practice.new.nameField`, `talk.quickSimulate.startButton` → `practice.new.startButton`).
- [ ] **Step 2:** Run both tests. Expected: FAIL (identifiers don't exist yet) — confirms the tests exercise the new paths.
- [ ] **Step 3:** `AppViewModel.swift` — rename `openQuickSimulate()` to `openPractice()` (662-665 body unchanged: selects `.messages` tab + bumps the route request; rename `quickSimulateRouteRequest` → `practiceRouteRequest` and update its two observers in MessagesView). Keep deep-link/shortcut `"simulate"` cases calling `openPractice()`.
- [ ] **Step 4:** `MessagesView.swift` — `TalkSheet`: replace `.quickSimulate` with `.practiceHub`; the sheet presents `RehearsalRoomView(viewModel: viewModel)` (it becomes the Practice hub). Keep `.practice(person)` case (direct person session) unchanged.
- [ ] **Step 5:** `RehearsalRoomView.swift` — title strings "Rehearsal Room" → "Practice" (`grep -n "Rehearsal" App/Views/RehearsalRoomView.swift` and update user-facing strings only, not type names). In its person picker, add a leading "Someone new" option (`accessibilityIdentifier("practice.someoneNewButton")`) that presents the describe-someone form: move `QuickSimulateSheet`'s form body (name, signs, MBTI, texting styles — MessagesView.swift:591-660) into a new file-private `PracticeNewPersonForm` inside RehearsalRoomView.swift (delete `QuickSimulateSheet` from MessagesView). On start, it creates the ad-hoc `RelationshipPerson` exactly as `QuickSimulateSheet.onStart` did and enters the same practice session UI. Identifiers: `practice.new.nameField`, `practice.new.startButton`.
- [ ] **Step 6:** `SimulateView.swift` — delete `rehearsalRoomCard` (245-279), its use (291), the sheet (326-328), and `showRehearsalRoom` (16).
- [ ] **Step 7:** `PeopleView.swift` `RelationshipPersonDetailView` — add an action row "Practice a conversation" (masks icon, `simastryGlass` row, identifier `people.detail.practiceButton`) that presents `RehearsalRoomView` pre-targeted at the person (pass the person through the existing practice-session entry — check how `.practice(person)` constructs the session in MessagesView:151-152 and reuse that initializer).
- [ ] **Step 8:** Run the two updated tests. Expected: PASS.
- [ ] **Step 9:** Build + verify: shoot `t5-predict` (predict args — promo card gone, flow starts immediately), `t5-talk` (practice row opens Practice hub — screenshot after `simctl launch` + a scripted tap is not possible via simctl; verify via the UITest run in Step 8 plus a manual screenshot of the sheet using `-SimastryPreviewScreen` if available, otherwise the test suffices).
- [ ] **Step 10: Commit** — `"Consolidate Quick Simulate and Rehearsal Room into Practice"`

---

## Stage 4 — Home reorder

### Task 6: Value-first Home + 4-tile Explore grid

**Files:**
- Modify: `App/Views/HomeView.swift:596-630` (section order), `:803-880` (`homeShortcutItems`, `handleHomeShortcut`), `:2105` ("Browse all"), the `HomeShortcutItem`/tile view (find via `grep -n "struct HomeShortcutItem\|cardSign" App/Views/HomeView.swift`) and `dailyDeciderCard` (find via `grep -n "dailyDeciderCard" App/Views/HomeView.swift`)
- Test: smoke tests referencing `home.shortcut.*` (grep first)

- [ ] **Step 1:** Reorder `homeContent` sections (HomeView:605-627) to:

```swift
if debugExpertsFirst { homeSection { panelCard } }
homeSection { dailyExpertNoteCard }          // hero: Leyla's note
homeSection { todaysReadCard }
homeSection { dailyDeciderCard.id("home.dailyDecider") }
homeSection { homeShortcutGrid }             // now titled "Explore"
homeSection { situationCard }
// …rest unchanged
```
- [ ] **Step 2:** `homeShortcutItems` → exactly 4 items, kinds `.askExperts`, `.practice` (rename `.simulate` in `HomeShortcutKind`), `.decode`, `.birthChart`:
  - askExperts: title "Ask the experts", subtitle "Five traditions"
  - practice: title "Practice", subtitle "Rehearse a conversation", systemImage "theatermasks.fill", identifier "home.shortcut.practice", handler `viewModel.openPractice()`
  - decode: title "Decode a text", subtitle "Read between lines"
  - birthChart: unchanged
  Delete the `.dailyDecider` and `.journal` items and their `handleHomeShortcut` cases (journal remains reachable via the drawer "Private journal"; the decider via its own section row).
- [ ] **Step 3:** Tile visuals: in the tile view, remove the `cardSign` pastel zodiac disc; render the `systemImage` as a gold glyph in a gold-tinted glass circle (match `rehearsalRoomCard`'s old icon treatment: `.foregroundStyle(SimastryColor.gold)`, 42pt circle, `SimastryColor.gold.opacity(0.12)` fill). Remove `cardSign`/`accent` from `HomeShortcutItem` if now unused. Keep the black glass container material untouched.
- [ ] **Step 4:** `Text("Browse all")` (:2105) → `Text("Explore")` — check the surrounding view to see whether this is the grid's section title; if it is a different "browse" surface, instead retitle the shortcut grid's `homeSection` header and leave :2105 alone. The grid section header must read "Explore" in the overline style used by other sections.
- [ ] **Step 5:** `dailyDeciderCard` → compact row: header row = wand icon (gold) + "Daily Decider" + "One tiny next move" caption + chevron; tapping expands/opens the existing decider content exactly as the card did (if the card body is inline content, wrap it in a tap-to-expand `DisclosureGroup`-style state; if it navigates, keep navigation). Do not change the decider feature itself.
- [ ] **Step 6:** Update smoke tests referencing removed identifiers: `grep -n "home.shortcut" UITests/SimastrySmokeUITests.swift` → `home.shortcut.simulate` → `home.shortcut.practice`; remove/retarget journal/decider tile tests (decider tests should target the section row id `home.dailyDecider`). Run them: PASS.
- [ ] **Step 7:** Build + verify: shoot `t6-home` (seeded, wait 7). Expected: Leyla's note first, daily read second, slim decider row, "EXPLORE" header with exactly 4 gold-icon tiles, no zodiac discs on tiles, nothing clipped by the tab bar.
- [ ] **Step 8: Commit** — `"Reorder Home around today's value; Explore grid of four"`

---

## Stage 5 — Predict de-chrome + shared category tokens

### Task 7: Category tokens (shared Predict ↔ intake)

**Files:**
- Create: `App/Views/Components/CategoryToken.swift`
- Modify: `App/Utilities/SimastryDesign.swift:36-65` (add two colors)

- [ ] **Step 1:** Add to `SimastryColor`:

```swift
static let orchidPink = Color(red: 214/255, green: 130/255, blue: 172/255)
static let sageGreen  = Color(red: 126/255, green: 168/255, blue: 120/255)
```
(Muted, in-palette with `sunCoral`/`risingViolet` — no neon.)
- [ ] **Step 2:** Create `CategoryToken.swift`:

```swift
import SwiftUI

/// The six shared reading categories. One icon + one color per category,
/// used identically by Predict's grid and the expert-intake topic chips.
enum SimastryCategoryToken: String, CaseIterable, Identifiable {
    case love, marriage, family, career, money, personal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .love: "Love"
        case .marriage: "Marriage"
        case .family: "Family"
        case .career: "Career"
        case .money: "Money"
        case .personal: "Private"
        }
    }

    var systemImage: String {
        switch self {
        case .love: "heart.fill"
        case .marriage: "link"
        case .family: "house.fill"
        case .career: "chart.line.uptrend.xyaxis"
        case .money: "dollarsign.circle.fill"
        case .personal: "lock.fill"
        }
    }

    var color: Color {
        switch self {
        case .love: SimastryColor.sunCoral
        case .marriage: SimastryColor.orchidPink
        case .family: SimastryColor.sageGreen
        case .career: SimastryColor.celestialBlue
        case .money: SimastryColor.gold
        case .personal: SimastryColor.risingViolet
        }
    }
}

struct CategoryTokenChip: View {
    let token: SimastryCategoryToken

    var body: some View {
        Image(systemName: token.systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(token.color)
            .frame(width: 38, height: 38)
            .background(token.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
```
- [ ] **Step 3:** Build (`scripts/dev/redesign-verify.sh build`). Expected: BUILD OK (component compiles, unused yet).
- [ ] **Step 4: Commit** — `"Add the shared reading-category tokens"`

### Task 8: Predict simplification

**Files:**
- Modify: `App/Views/SimulateView.swift:291` (remove `predictStepRail` from the stack), `:388-405ish` (delete `predictStepRail`), `:513` region (numbered "What are we reading?" card → plain section title), category tile view (find via `grep -n "FutureQuestionCategory\|categoryTile\|categoryGrid" App/Views/SimulateView.swift`) — map each `FutureQuestionCategory` to its `SimastryCategoryToken` for icon+color; one-line sample questions
- Modify: `App/Views/ExpertAstrologersView.swift` topic chips (find via `grep -n "Love\|Relationships\|Timing\|Life Direction" App/Views/ExpertAstrologersView.swift`) → render with `CategoryTokenChip` + title

- [ ] **Step 1:** Delete `predictStepRail` and its call. Replace the numbered guided-section chrome for step 1: the card header becomes plain `Text("What are we reading?")` in the section-title style with subtitle "Pick the shape of the question." — no numbered badge. (Locate the numbered-badge component: `grep -n "stepBadge\|guidedSection\|title: \"What are we reading" App/Views/SimulateView.swift` and remove only the number chrome, keeping the card.)
- [ ] **Step 2:** Category tiles: replace each tile's colored icon chip with `CategoryTokenChip(token:)` mapped from the tile's `FutureQuestionCategory` (add a `var token: SimastryCategoryToken` extension mapping in SimulateView.swift or on the category enum; Private ↔ `.personal`, and map the remaining five by name). Rewrite sample questions to fit one line at default type size (max ~34 chars), e.g. Family: "What should I understand here?", Private: "What should I know right now?".
- [ ] **Step 3:** Intake topic chips (ExpertAstrologersView): replace the six plain text chips with icon+title chips using the same tokens (Relationships→`.love`? No — the intake's set is Love/Relationships/Career/Family/Timing/Life Direction; keep the intake's *labels* but where a label matches a token (Love, Career, Family) use that token's icon+color; for Relationships use `.love` color family with `person.2.fill`, Timing `clock.fill`/gold, Life Direction `location.north.line.fill`/violet — visually one system without forcing the six names to change).
- [ ] **Step 4:** Build + verify: shoot `t8-predict` (predict args, wait 9) and `t8-intake` (astrologists args, wait 9). Expected: Predict opens straight into "What are we reading?" + tiles (no promo, no stepper, no "①"); tile icons semantically sane (link for Marriage, house for Family); no truncated sample questions; intake topic chips visually match Predict's category language.
- [ ] **Step 5:** Run any Predict smoke tests (`grep -n "predict\." UITests/SimastrySmokeUITests.swift`); update selectors only if they referenced the step rail. Expected: PASS.
- [ ] **Step 6: Commit** — `"De-chrome Predict; adopt the shared category tokens"`

---

## Stage 6 — People compression + intake polish

### Task 9: People — people first

**Files:**
- Modify: `App/Views/PeopleView.swift` — hero cards region (`:255` RELATIONSHIP MEMORY stat card, `:208-230` Read this group, `:323` Best next move), sections `:291-310` (merge "All people"/"Recent reads"), person row (single sign indicator — find the row view via `grep -n "struct.*PersonRow\|RelationshipAvatarView" App/Views/PeopleView.swift`)

- [ ] **Step 1:** Keep the "Best next move" strip as the only hero (move it to the top position). Delete the RELATIONSHIP MEMORY stat card; its facts become the list section header caption: `PEOPLE · 4 · private` (overline style; count from `viewModel.relationshipPeople.count`). "Read this group" becomes a trailing compact pill on that same header row (keeps its action + accessibility label).
- [ ] **Step 2:** Merge sections: one list, recency-sorted (use the existing "Recent reads" ordering source for the top of the list; then the rest alphabetically — inspect `allPeopleSection`/`recentReads` sorting and combine). One section header ("PEOPLE …" as above).
- [ ] **Step 3:** Row cleanup: exactly one sign indicator per row — keep the leading pastel disc avatar (`RelationshipAvatarView`), delete the trailing sign chip and the decorative person-glyphs after names.
- [ ] **Step 4:** Build + verify: shoot `t9-people`. Expected: Best-next-move on top, single merged list under one header with count caption + Read-group pill, rows with one disc each, list not clipped by tab bar.
- [ ] **Step 5:** Run People smoke tests; update selectors if they referenced deleted cards. Expected: PASS.
- [ ] **Step 6: Commit** — `"Compress People to a single hero and one list"`

### Task 10: Intake — meet the five first

**Files:**
- Modify: `App/Views/ExpertAstrologersView.swift:142-147` (headlines), `:214+` (context chips fade), `:271+` (picker default), `:481` (CouncilKeyArt already present — reposition to top if not)

- [ ] **Step 1:** Check where `Image("CouncilKeyArt")` (:481) renders. If it is not the top element of the intake scroll, add the banner at the top: full-width, `scaledToFill`, height 140, rounded 22, above the headline. (Asset untouched.)
- [ ] **Step 2:** Headline: replace both lines (:142 "Consult one expert — or hear perspectives from all five." and :147 gold subhead) with the single `Text("Ask once. Five traditions answer.")` in the headline style of :142.
- [ ] **Step 3:** Context chips row: wrap in `ScrollView(.horizontal)` if not already; add trailing edge fade (`.mask { LinearGradient(stops: [.init(color: .black, location: 0.86), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing) }`).
- [ ] **Step 4:** Expert picker: confirm default selection = all five (inspect the selection state initializer; set it to all five if not). Confirm the picker block sits above the `tabBarEndClearance` spacer (:92) — the audit showed it clipped; if the spacer is misplaced (not the last element), move it to be the scroll content's final element.
- [ ] **Step 5:** Build + verify: shoot `t10-intake` (astrologists args, wait 9; scroll state is top — the banner + single headline must be visible; re-shoot `panelChat` args to confirm the pre-filled question path still renders). Expected: council banner top, one headline, faded chip row, picker fully above the tab bar (verify by a second screenshot after the UITest scrolls, or rely on the smoke intake test).
- [ ] **Step 6:** Run the intake smoke test (`testExpertAstrologersIntakePersists…`). Expected: PASS.
- [ ] **Step 7: Commit** — `"Lead the expert intake with the council"`

---

## Stage 7 — Small fry + full QA

### Task 11: Landing disc keep-out + remaining polish

**Files:**
- Modify: `App/Views/Components/CrystalBallView.swift:373-470` (zodiac field vs expert beads)
- Modify: `App/Views/UpsellModalView.swift`, `App/Views/ModeSelectionView.swift`, `App/Views/DiscoveryView.swift`, `App/Views/Components/OnboardingProgressView.swift` — inset/casing/glass-token adherence only (no restructure)

- [ ] **Step 1:** Disc/portrait collision fix: the 0.82·d radius guard only separates the discs from the experts horizontally; both ellipses cross near the top/bottom center. In `zodiacRing(at:front:)`, after computing a disc's x/y offset, compute the five expert bead positions at the same `t` (extract the expert-position math into a shared helper if it is currently inline in the expert layer) and apply a radial push: if `hypot(dx, dy) < 46`, offset the disc along `(dx, dy)` normalized to distance 46 from that bead. Deterministic, no state, preserves the dispersal.
- [ ] **Step 2:** Build + verify: `scripts/dev/redesign-verify.sh landing t11-landing` **three times** (animation phases differ) — in all three PNGs, no disc may overlap a portrait.
- [ ] **Step 3:** Sweep the four polish files for: bottom `tabBarEndClearance` where scroll content meets the bar, Title Case strings (→ sentence case), ad-hoc materials (→ `simastryGlass`/`simastryGlassPill`). Small diffs only.
- [ ] **Step 4: Commit** — `"Keep the zodiac field clear of the experts; polish pass"`

### Task 12: Full QA sweep + smoke suite

- [ ] **Step 1:** `scripts/dev/redesign-verify.sh build`
- [ ] **Step 2:** Shoot ALL owner QA surfaces and **look at every PNG**: `qa-landing` (landing) · `qa-home` (seeded) · `qa-predict` (predict) · `qa-talk` (panelInbox) · `qa-intake` (astrologists) · `qa-people` (tab 1) · `qa-drawer` (invite) · `qa-upsell` (no preview arg exists — open the drawer shot and confirm the upgrade entry; upsell modal itself is verified via UITest if covered, else note it for device QA) · plus `qa-panelchat` (panelChat args).
  Checklist per shot: title Y identical across tabs; no dashed rings; no truncation; nothing under the tab bar; icons semantic; naming consistent (Practice / Ask the experts).
- [ ] **Step 3:** Full smoke suite from the mirror: `xcodebuild test … -only-testing:SimastryUITests/SimastrySmokeUITests 2>&1 | tail -30`. Expected: all PASS (known flake: `testExpertAstrologersIntakePersists…` is order-dependent — re-run in isolation if it fails in the full run).
- [ ] **Step 4:** Final commit with a `Verified:` line listing the build, the screenshots reviewed, and the suite result, matching house style (see `git log` for examples).
- [ ] **Step 5:** Push the branch. Owner reviews on-device via their Sqim flow.

---

## Execution notes

- **Never** edit `Simastry.xcodeproj/` or `App/Info.plist` (generated; gitignored). New files (`CategoryToken.swift`, `scripts/dev/redesign-verify.sh`) are picked up by `xcodegen generate` via `Project.json`'s source globs — verify `CategoryToken.swift` appears in the generated project on first build.
- **Every commit message**: imperative summary + body + `Verified:` line (what was built/screenshotted/tested).
- **If a repo-root build is ever attempted and hangs**: that's the Codex contention — kill it, use the harness script.
- Screens are seeded via `AppViewModel.applyDebugPreviewStateIfRequested` (AppViewModel.swift:3578) — if a task needs a state with no preview arg, prefer adding a small DEBUG-only arg there over manual tapping, and note it in the commit.
