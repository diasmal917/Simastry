You are Claude Opus 4.8 MAX working in Claude Code.

Use MAX effort.
Use the current native iOS app as the source of truth.
You have full product/design authority for this pass, but preserve functional correctness and the Method Layer.

# Mission

Audit, redesign, and polish Simastry into an Apple Fitness+ quality native iOS app using Apple-native Liquid Glass design principles.

The target is:
- Apple Fitness+ style structure and polish
- iOS Liquid Glass feel
- premium black/glass/luminous aesthetic
- zodiacs SDK icon assets for zodiac signs
- astrology-guided communication, not generic AI chat

Simastry should feel like Apple Fitness+ meets iMessage/Instagram DMs, but for astrology-guided relationship communication.

# Exact Repo And Target

Work only in:

`/Users/chiburashka/Documents/Codex/Simastry-current`

Native iOS project:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/Simastry.xcodeproj`

Native app source:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/Simastry/SimastryApp`

Tests:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/SimastryTests`

Do not use the old Expo prototype as the implementation target:

`/Users/chiburashka/Documents/Codex/Simastry/expo-prototype`

Do not use the stale root native app:

`/Users/chiburashka/Documents/Codex/Simastry/Simastry/SimastryApp`

The only implementation target is the current native app in `Simastry-current`.

# Current Verified State

Before this handoff, the native app passed:

```bash
xcodebuild -project ios/Simastry.xcodeproj -scheme Simastry -destination 'platform=iOS Simulator,id=38224CD2-19D6-409B-874B-23EB61261CF8' -derivedDataPath /tmp/simastry-method-layer-derived-data build CODE_SIGNING_ALLOWED=NO
```

and:

```bash
xcodebuild -project ios/Simastry.xcodeproj -scheme Simastry -destination 'platform=iOS Simulator,id=38224CD2-19D6-409B-874B-23EB61261CF8' -derivedDataPath /tmp/simastry-method-layer-derived-data test CODE_SIGNING_ALLOWED=NO
```

The app was launched with:

```text
-SimastryPreviewSeeded
```

The simulator preview was visible at:

`http://localhost:3200/`

# Current App Structure

Bottom navigation must remain:

1. Home
2. People
3. Messages
4. Me

Do not add top-level Predict.
Do not add top-level Gram.
Do not add top-level Cast.
Do not revive Guides.
Do not add public dating/discovery surfaces.

Predict is a Home action.
Gram lives inside AI Astrologists.
People is a private relationship workspace, not public discovery.

# Important Files

Main shell/navigation:

- `ios/Simastry/SimastryApp/Views/MainTabView.swift`
- `ios/Simastry/SimastryApp/ViewModels/AppViewModel.swift`

Priority screens:

- `ios/Simastry/SimastryApp/Views/HomeView.swift`
- `ios/Simastry/SimastryApp/Views/AIAstrologistsView.swift`
- `ios/Simastry/SimastryApp/Views/MessagesView.swift`
- `ios/Simastry/SimastryApp/Views/PeopleView.swift`
- `ios/Simastry/SimastryApp/Views/ProfileView.swift`
- `ios/Simastry/SimastryApp/Views/AuraView.swift`
- `ios/Simastry/SimastryApp/Views/SimastrySettingsView.swift`
- `ios/Simastry/SimastryApp/Views/SimulateView.swift`

Models and method logic:

- `ios/Simastry/SimastryApp/Models/CommunicationTypeProfile.swift`
- `ios/Simastry/SimastryApp/Models/RelationshipPeople.swift`
- `ios/Simastry/SimastryApp/Models/ZodiacSign.swift`
- `ios/Simastry/SimastryApp/Utilities/CommunicationTemplates.swift`

Zodiac icon component:

- `ios/Simastry/SimastryApp/Views/Components/ZodiacIconView.swift`

Tests:

- `ios/SimastryTests/AppViewModelRegressionTests.swift`

# Zodiacs SDK Icons

The 12 official zodiac PNG assets are already vendored into:

`ios/Simastry/SimastryApp/Assets.xcassets/Zodiacs_<sign>.imageset`

Use:

`ZodiacIconView(sign:size:showsGlow:)`

wherever zodiac icons appear in active UI surfaces.

Do not use raw zodiac glyphs for visible icon UI except fallback, accessibility, and plain-text strings.

If you find visible glyph usage in active UI, replace it with `ZodiacIconView`.

# Product Definition

Simastry is a premium astrology communication app.

It is not:
- arbitrary AI chat
- a generic horoscope app
- a mystical content feed
- a dating app
- a public discovery app

The cast are AI Astrologists with companion-like charisma.
They are flirty, charismatic, fun, emotionally intelligent, and useful to talk to.
They are astrologer-first, not dating profiles.

Visible product language should use:
- AI Astrologists
- Communication type
- Chart signals
- Companion lens
- Message guidance
- Predict
- Why this reading
- Signals used
- Traditional astrology
- Placement logic

Avoid:
- visible Soulmate language
- dating-app match language
- generic horoscope filler
- crystal-shop language
- meme astrology voice
- claims astrology is scientifically proven
- guaranteed predictions
- Guides as a product surface

# Method Layer Requirement

Every feature must preserve the Method Layer.

Simastry is grounded in:
- astronomical chart calculation where placements are involved
- traditional Western tropical astrology for interpretation
- user Sun/Moon/Rising when available
- companion/persona sign lens
- relationship, message, timing, or compatibility context

Every user-facing interpretation should subtly show why it exists through:
- method chips
- why-this-reading panels
- signals-used summaries
- companion lens explanations
- concise source/method notes

Do not over-explain.
Do not create textbook astrology UI.
The method should feel intuitive, premium, and embedded.

Required distinction:

- Astronomy calculates placements.
- Astrology interprets placements.
- Simastry translates that interpretation into communication guidance.

# Functional Guardrails

Do not break:

- Home/People/Messages/Me nav
- Home-hosted Predict
- `startPrediction(for companion/sign)`
- AI Astrologists route from Home
- AI Astrologists → Gram → enlarged post/comments
- Message and Predict actions from AI Astrologists
- Messages list and detail thread
- People private workspace
- Me → Aura
- Me → Settings
- Settings local clear vs delete account separation
- Aura wallet read-only disclaimer
- legacy guide/deep-link safe redirects
- full test suite

Settings must keep:

- `Clear Local Data` = local/device-only data
- `Delete Account` = separate explicit destructive account deletion
- wallet/public address = read-only, only for calculating Aura
- no implication that Simastry can sign, approve, transfer, or move assets

# Design Direction

Redesign the UI to feel like Apple Fitness+ using SwiftUI-native patterns.

The app should feel:

- Apple-native
- premium
- black/glass/luminous
- image-led
- calm
- consumer-friendly
- expensive
- structured
- emotionally meaningful
- astrology-specific without mystical filler

Liquid Glass guidance:

- Use SwiftUI-native material/glass effects where appropriate.
- Use translucent depth, layered blur, subtle borders, and soft highlights.
- Use soft animations and native transitions.
- Keep motion calm and useful.
- Use Apple-like typography: cleaner, lighter, high contrast, readable.
- Preserve dark premium theme.
- Use stable responsive layouts for iPhone sizes.
- No overlapping text.
- No cramped nav.
- No giant icons.
- No cheap filters.
- No excessive glow.
- No neon.
- No sci-fi look.
- No one-note purple/blue gradient theme.

# Screen-Specific Goals

## Home

Home should feel like Apple Fitness+ Summary.

Required:

- Strong `Summary` header
- communication type visible and important
- compact metric cards
- active astrologist lens
- Sun/Moon/Rising chart-signal chips
- premium Predict CTA
- image-led AI Astrologists hero
- native spacing and clear hierarchy

Do not make it feel like SaaS analytics.
Do not make it feel like a horoscope feed.

## AI Astrologists

Make this feel like Apple Fitness+ trainer cards, but for astrology.

Required:

- portrait-forward cards using Factory portraits already in the asset catalog
- strong names
- clear sign specialty
- emotional style
- communication lens
- sections: `For You`, `Signs`, `Gram`
- actions: `Message`, `Gram`, `Predict`
- companion-like charisma, but astrologer-first
- distinct personalities and specialties

The cast are AI Astrologists masquerading as AI companions, not romantic matches.

## Gram

Gram is inside AI Astrologists.

Required:

- profile/grid content like Instagram
- Factory images
- tappable posts
- enlarged post sheet
- caption
- local/mock comments
- Message/Predict actions

Do not make Gram a top-level tab.

## Messages

Messages should feel like Instagram or WhatsApp DMs.

Required:

- clean message list
- strong avatars
- readable previews
- intimate thread view
- compact Method Layer panel
- message composer
- local reply behavior
- no duplicated underlying list row while thread is open
- private notification language

Keep it fast and emotionally direct.
Avoid bloated explanation.

## People

People is a private relationship workspace.

Required:

- private manually saved people
- search
- filters
- needs-attention section
- recent reflections
- all people list
- add person
- person detail
- method panel

It is not contact import.
It is not public discovery.
It is not dating.

The onboarding Sun/Moon/Rising exists partly to determine the user's communication type for People.

## Me

Required:

- clean account/chart identity
- communication type
- easy Settings access
- easy Aura access
- avoid clutter

## Aura

Required:

- premium visual page
- meaningful, not gimmicky
- uses chart signals and optional public wallet read-only context
- keeps wallet limitations clear

## Settings

Required:

- Apple-native grouped settings feel
- private reminders
- appearance
- language
- wallet connect/public address
- read-only wallet disclaimer
- export
- clear local data
- delete account
- method layer note

## Predict

Required:

- Home-hosted action, not nav tab
- premium full-screen route
- uses chart signals and message context
- clear Method Layer
- no overclaiming

# Audit Requirement

Before modifying, audit the app and provide a concise scorecard in your first response/log:

- Product clarity rating /10
- Visual design rating /10
- Apple-native feel rating /10
- Liquid Glass quality rating /10
- Astrology method trust rating /10
- Messaging/chat quality rating /10
- Navigation clarity rating /10
- Conversion/readiness rating /10
- Overall app rating /10

Then implement the redesign.

After implementation, provide a second scorecard using the same categories.

# Implementation Instructions

1. Inspect git status first.
2. Do not revert user/Codex changes unless explicitly necessary and explained.
3. Keep business logic stable unless you find a real bug.
4. Refactor UI components if it improves polish or maintainability.
5. Prefer SwiftUI-native components and state.
6. Use existing assets and models.
7. Do not introduce backend/API dependencies.
8. Do not remove required features.
9. Do not revive stale Guides.
10. Do not port old Expo UI.

# Verification

Run build:

```bash
xcodebuild -project ios/Simastry.xcodeproj -scheme Simastry -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/simastry-opus-derived-data build CODE_SIGNING_ALLOWED=NO
```

Run tests:

```bash
xcodebuild -project ios/Simastry.xcodeproj -scheme Simastry -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/simastry-opus-derived-data test CODE_SIGNING_ALLOWED=NO
```

Launch seeded preview with:

```text
-SimastryPreviewSeeded
```

Preview URL:

`http://localhost:3200/`

# Manual Verification Checklist

Verify:

- Home shows Summary, communication type, AI Astrologists, Predict.
- Bottom nav shows only Home, People, Messages, Me.
- AI Astrologists opens and feels like Apple Fitness+ trainer cards.
- AI Astrologists cards use Factory portraits.
- Gram grid opens large post sheet with caption/comments/actions.
- Messages list and thread feel like DMing.
- Predict opens from Home and from AI Astrologists.
- People private workspace opens.
- People search/filter/add/detail still work.
- Me opens Settings and Aura.
- Settings wallet read-only copy is intact.
- Clear Local Data and Delete Account remain separate.
- Zodiacs SDK icons render wherever zodiac icons appear.
- No visible Soulmate language.
- No Guides product surface.
- No Cast top-level tab.
- No Gram top-level tab.
- No Predict tab.
- No dating/discovery language in active UX.
- No text overlap on iPhone viewport.

# Final Response Requirements

When finished, report:

- initial audit scorecard
- what you changed
- after scorecard
- recommendation
- rationale
- changed files
- verification results
- preview URL
- remaining risks
- next best polish task

Be direct and specific.
