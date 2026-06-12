# Simastry Aggressive Visual Redesign Prompt — Opus 4.8 MAX

You are redesigning the current native Simastry iOS app visually. This is not another conservative audit. You must make a meaningful visual patch unless the app is already literally indistinguishable from the target direction.

Use maximum design judgment. Push the app harder toward Apple Fitness+ for astrology-guided communication: black, premium, image-led, structured, native, calm, glossy, liquid, and consumer-ready.

## Target Repo

Work only in:

`/Users/chiburashka/Documents/Codex/Simastry-current`

Native app source:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/Simastry/SimastryApp`

Xcode project:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/Simastry.xcodeproj`

Tests:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/SimastryTests`

Do not touch:

- `/Users/chiburashka/Documents/Codex/Simastry/expo-prototype`
- `/Users/chiburashka/Documents/Codex/Simastry/Factory`
- old stale root SwiftUI app files outside `Simastry-current`
- Factory image generation logic

## Mission

Aggressively improve the visual design while preserving product architecture.

Reference direction:

- Apple Fitness+ Summary tab style
- Apple Fitness+ trainer card style
- iOS Liquid Glass feel
- Apple-native spacing, hierarchy, typography, cards, materials, and motion

This is a visual redesign and polish pass. You may refactor SwiftUI view composition and design tokens to achieve a stronger visual result, but do not add backend work or invent unrelated product surfaces.

## Hard Product Structure

Keep bottom nav exactly:

- Home
- People
- Messages
- Me

Do not add top-level:

- Predict
- Gram
- Cast
- Guides

Predict remains a Home action.

AI Astrologists live inside Home.

Gram/profile-grid content lives inside AI Astrologists.

People is a private relationship workspace, not public discovery.

Messages should feel like WhatsApp / Instagram DM, not a chatbot demo.

Me includes Aura and Settings.

## Product Language

Visible language should use:

- AI Astrologists
- Communication type
- Chart signals
- Method
- Message guidance
- Predict
- People
- Aura

Avoid visible:

- Soulmate
- dating-app language
- match/distance/nearby/live status
- Guides
- generic horoscope language
- mystical filler

## Method Layer

The design must subtly show why the app is meaningful:

- Sun = core communication drive
- Moon = emotional reaction pattern
- Rising = first response / social presentation
- Companion sign = astrologist lens
- People signs = relationship communication pattern

Use compact method chips, signal rows, why-this-reading panels, and chart-signal summaries.

Do not over-explain. It should feel premium, not like a textbook.

## Native Visual Rules

Prefer native SwiftUI and iOS feel:

- Use existing local design system where possible.
- Improve `SimastryDesign.swift` only when it raises quality across screens.
- Use native material/glass patterns where supported, with graceful fallback.
- Use subtle depth, not neon.
- Use image-led cards and strong typographic hierarchy.
- Keep touch targets comfortable.
- Avoid tiny text, cramped rows, generic dashboards, crypto aesthetics, dating profiles, or AI-wrapper layouts.
- No one-note purple/blue gradients. Gold should be premium accent, not paint spilled everywhere.
- Preserve responsiveness and no text overlap on iPhone-sized screens.

Use Zodiacs SDK icons wherever zodiac icons are visible.

Use existing `ZodiacIconView` and vendored assets:

`/Users/chiburashka/Documents/Codex/Simastry-current/ios/Simastry/SimastryApp/Assets.xcassets/Zodiacs_<sign>.imageset`

Keep `ZodiacSign.glyph` only for fallback, accessibility, and plain-text strings.

## Required Visual Patch Areas

You should make meaningful improvements in at least two of these areas, preferably three or more:

### Home

Make Home closer to Apple Fitness+ Summary.

It should feel like the main daily dashboard:

- Top title: `Summary`
- Communication type card
- Sun / Moon / Rising chips
- Predict CTA as premium full-width action
- AI Astrologists hero tile
- People / Messages continuation surfaces
- compact metric cards: streak, predictions remaining, active astrologist lens, recent communication signal

Make the hierarchy sharper, more Apple-native, and more image-led.

### AI Astrologists

Make this look more like Apple Fitness+ trainer cards.

Use Factory cast portraits strongly. Cards should feel like premium trainer/coach cards, but for astrology communication.

Each astrologist card should show:

- portrait
- name
- sign specialty
- communication lens
- short charismatic/flirty line
- actions: Message, Gram, Predict

Sections:

- For You
- Signs
- Gram

Make it feel curated, not like a dating carousel.

### People

Make People feel like a private Apple-native relationship workspace.

Improve visual treatment of:

- search
- filters
- needs attention
- recent reflections
- person cards
- person detail method panel

Do not make it public discovery.

### Messages

Make Messages feel more like WhatsApp / Instagram DM.

Improve:

- conversation list
- unread state
- selected chat sheet/detail
- bubbles
- composer
- compact method panel

Keep messages private, personal, and emotionally useful.

### Me

Make Me feel like a polished Apple account/profile screen.

Improve:

- communication type chip
- Aura entry
- Settings entry
- sign rows with Zodiacs icons
- wallet read-only disclaimer
- export / clear local data / delete account hierarchy

### Aura

Make Aura feel premium and visual.

It should feel like an Apple-native, mystical-but-grounded visualization of chart signals, not random crypto art.

### Predict

Keep Predict as a Home action.

Make the Predict screen visually consistent with the new Apple Fitness-style dashboard.

## Constraints

Do not break existing tests.

Do not alter working routing unless needed for visual cleanup.

Do not revive Guides.

Do not reintroduce Soulmate as visible text.

Do not make the app feel like dating.

Do not replace Zodiacs icons with glyphs in active UI.

Do not add speculative backend/API work.

Do not delete working features.

Do not make an audit-only response. Apply visual improvements.

## Verification

Run:

```sh
cd /Users/chiburashka/Documents/Codex/Simastry-current
xcodebuild -project ios/Simastry.xcodeproj -scheme Simastry -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/simastry-aggressive-visual-redesign build CODE_SIGNING_ALLOWED=NO
xcodebuild -project ios/Simastry.xcodeproj -scheme Simastry -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/simastry-aggressive-visual-redesign test CODE_SIGNING_ALLOWED=NO
```

Preview target:

`http://localhost:3200/`

Confirm:

- no text overlap on iPhone-sized screens
- bottom nav remains Home / People / Messages / Me
- Home looks like an Apple Fitness-style Summary dashboard
- AI Astrologists look like trainer cards
- Predict opens from Home
- Messages feel like DMs
- People remains private
- Me includes Aura and Settings
- Zodiacs icons render
- no visible Soulmate / Guides / Cast / Gram top-level / Predict tab
- app builds
- tests pass

## Final Report Required

Return:

- visual recommendation
- what changed
- design rating before/after
- files changed
- build result
- test result
- preview URL
- remaining visual risks
- next best polish task
