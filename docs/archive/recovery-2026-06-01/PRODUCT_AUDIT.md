# Simastry — Comprehensive Product, UX & Engineering Audit

**Date:** May 29, 2026
**Scope:** Native iOS app (SimastryApp), Expo prototype, Factory pipeline, Claude UI branch, design references
**Auditor posture:** Direct. No flattery. Separated current vs planned vs recommended.

---

## Top-Level Recommendation

**Ship a focused v1.0 that makes the Predict → Companion → Chat loop feel like the core product, not a feature buried inside a generic astrology app.** The current app has the right bones — Swiss Ephemeris, Supabase auth, RevenueCat, a working prediction proxy, and a cinematic onboarding — but the product thesis ("conversation-first astrology") is drowned by too many surfaces competing for attention on Home, weak companion differentiation, and astrology content that collapses 12 signs into 4 elements.

**Rationale:** Right now a new user lands on a Home screen that looks like a dashboard for an app they haven't yet understood. The Predict screen is powerful but feels like a dev tool — paste text, pick signs, press generate. Companions exist but their personality stops at a name + sign badge + element-based paragraph. The gap between the premium vision ("Arc for astrology") and the current feel ("Co-Star with extra steps") is the primary product risk.

**Next action:** Port the 6 Keep items from CLAUDE_UI_AUDIT.md into a clean PR on `origin/main`, then execute the Week 1 roadmap below. Do not redesign the tab bar, do not expand to 24 companions, do not build Astrogram. Ship the loop.

---

## 1. Current App Diagnosis

### What Works

- **Onboarding flow is correct.** Landing → Birthday → Birth Time → Birthplace → Sign Up → Companion Creation is the right sequence. Birth details before account creation means the user hits their first "wow" moment (sign reveal) before they're asked to commit. This is better than Co-Star's flow.
- **Swiss Ephemeris integration is real.** `BirthChartService` uses Placidus house system, actual planetary longitudes, and geocoded coordinates. Rising sign requires both birth time and location — this is astronomically correct and earns credibility.
- **Prediction proxy exists and works.** `PredictionService` sends a structured request with system prompt, user prompt, redacted conversation, and astrological context. The response includes predicted message, breakdown, confidence score, and tone. This is the product's core utility.
- **ConversationPrivacyService redacts PII before transmission.** Emails, phone numbers, URLs, social handles are stripped client-side. Safety screening blocks self-harm, threats, and sexual-minor content. This is table stakes for an AI prediction feature.
- **RevenueCat integration is present.** Three tiers (Free/Plus/Pro) with actual offering fetch, package matching, and entitlement checks. Graceful degradation when unconfigured.
- **SoulCreationView is cinematic.** The starfield → particle convergence → orb reveal → avatar animation is a genuine moment of delight. It's the kind of thing that gets screen-recorded for TikTok.
- **Deep linking between surfaces exists.** Companions link to Predict, Guides link to Simulate, Home cross-links to every tab. `viewModel.predictionDraft` carries companion context into the Predict screen. `guideFocusSign` allows targeted navigation to Guides.

### What's Weak

- **HomeView is a dashboard, not a hook.** 757 lines rendering a greeting, hero deck, predict card, communication card, 2×2 grid, primary companion card, and energy card. A new user with one companion sees too many undifferentiated surfaces. None of them say "here is the one thing this app does that nothing else does."
- **Companion content is element-based, not sign-based.** `AstropediaView` (1365 lines) and all communication guides generate text keyed on element (fire/earth/air/water). All three fire signs (Aries, Leo, Sagittarius) get identical descriptions. This means a user with a Leo companion and a user with a Sagittarius companion receive the same guidance. The product claims sign-level specificity but delivers element-level generality.
- **MainTabView uses a custom `LiquidGlassTabBar` instead of native TabView.** This replaces the standard tab navigation with a `switch` statement and `matchedGeometryEffect` animations. It's visually nice but risks view identity churn, breaks standard iOS navigation patterns, and complicates accessibility. The CLAUDE_UI_AUDIT.md correctly flags this as a rework item.
- **MessagesView is embedded inside MainTabView.swift** rather than being its own file. This is a code organization issue but signals that the messages surface was added as an afterthought.
- **10 of 24 companions have no approved portraits.** They fall back to zodiac art with a glyph overlay. Shipping with placeholder companions undermines the premium positioning. The Factory pipeline exists to fix this but the queue is incomplete.
- **Privacy Policy and Terms of Service are placeholder text** in ProfileView ("For the full privacy policy, visit our website"). This is an App Store rejection risk.

### What's Confusing

- **Two app paths exist in the repo.** The root-level `Simastry/SimastryApp/` and `Simastry.xcodeproj` are the stale versions. The current `origin/main` lives under `ios/Simastry/SimastryApp/` and `ios/Simastry.xcodeproj`. The local checkout is ahead by 2 and behind by 42 commits. A developer opening this repo will be confused about which is canonical.
- **`SignSelectionView` uses a different chart calculation than `BirthDetailsView`.** The onboarding path uses `BirthChartService` (Swiss Ephemeris, geocoded coordinates, Placidus houses). The companion-creation path uses `ZodiacSign.fromDate()` (date-only Sun lookup) with hardcoded element-preference suggestions for Moon and Rising. This means a user who enters their companion's birthday gets a fake Moon/Rising, undermining the app's credibility claim.
- **Config keys use `EXPO_PUBLIC_` prefix.** Carried over from the Expo prototype into native iOS. Not a functional issue but confusing for any new developer.
- **`PLAN.md` describes a Co-Star-style onboarding redesign** that appears to already be implemented in the current `BirthDetailsView`/`SignUpView` flow, but the doc reads as if it's still planned. Stale planning docs create confusion about what's done.

### Product Risks

- **Client-side rate limiting only.** All usage limits (10 messages/day, 3 predictions/week, companion count) are enforced in `AppViewModel`. The prediction proxy receives a `tier` string from the client with no visible server-side validation. A user with Charles Proxy or a modified binary could spoof their tier to "pro" and get unlimited access.
- **No API authentication on prediction requests.** The `URLRequest` to `/api/simulate/predict` sets no Authorization header. If the proxy doesn't validate against Supabase session tokens server-side, it's an open endpoint.
- **Prediction history stored in UserDefaults (plaintext).** Redacted conversation text is persisted locally without encryption. A device backup or jailbreak exposes this data.
- **Safety filters are basic keyword regex.** "k1ll myself", "su1c1de", or non-English equivalents bypass the filter. No NLP, no fuzzy matching, no Unicode normalization. This is an App Store Safety risk for an AI feature that processes user-submitted text about relationships.
- **No crash reporting or analytics verified in the codebase.** AGENTS.md notes these are "planned-not-verified." Shipping without analytics means no visibility into activation, retention, or conversion funnels.

---

## 2. Product Loop Assessment

### Onboarding (Landing → Birth Details → Sign Up → Companion Creation)

**Grade: B+.** The flow is correct: value demonstration before account creation, birth details that produce a real chart, companion creation that feels personal. The SoulCreation animation is a genuine retention moment.

**Weaknesses:**
- Landing carousel says "Find Your Soulmate" as the first card. This positions Simastry as a dating app. It should say something about conversation/communication — the actual product.
- "Predict Their Reply" is the second carousel card but there's no preview of what that looks like. A mock prediction result would be more compelling than a tagline.
- 4 onboarding pages with 4-second auto-advance is too fast for reading and too slow for scanning. Either reduce to 2 pages or let the user swipe at their own pace.
- CompanionSetupView allows "Surprise Me" random sign generation. This creates companions with no astrological meaning to the user. It should suggest the user's compatible signs instead.

### Companion Discovery

**Grade: C+.** Companions exist as data objects with names, signs, and appearance styles, but they don't feel like people.

**Weaknesses:**
- No companion voice/personality is visible until you're in a chat. The CompanionDetailSheet shows Sun/Moon/Rising descriptions and compatibility scores but nothing about how this companion talks, what they care about, or why you'd want to interact with them.
- The Expo prototype has rich companion data: `identity.personality`, `identity.chatVoice`, `identity.astrologyAngle`, `opener`, `bullets`, `bio`, `tags`. None of this is in the native app's `CompanionData` model. This is the single biggest gap between the prototype's vision and the native app's reality.
- Compatibility scoring uses element-pair matching only. Sun-Sun, Moon-Moon, Rising-Rising are compared by element. No modality, no polarity, no aspect geometry. A Taurus-Virgo pair (both earth, trine relationship) scores the same as a Taurus-Capricorn pair (both earth, trine relationship) — but in actual astrology these are meaningfully different.

### Predict (SimulateView → SimulationResultView)

**Grade: B.** This is the product's core utility and it mostly works.

**Strengths:** Target context card, sign picker with horizontal scroll, question suggestions ("Will they reply?", "Should I double text?"), animated progress phases, history section, privacy notice with redaction explanation.

**Weaknesses:**
- The screen is called "Simulate" in code but "Predict" in the tab bar and UI copy. Pick one name.
- The text input area is a generic text editor. It should look like a pasted conversation — maybe with alternating bubble colors or a "Paste from Messages" shortcut.
- Mode is locked to `.whatWillTheySay`. The mode selection (Soulmate/Bestie/Simulate Anyone) happens at companion creation, not at prediction time. This means a user can't ask "what would a Scorpio say to this?" without first creating a Scorpio companion.
- Result view shows the prediction but the "What if I said..." regeneration input has no context about what changes. The user types a hypothetical reply but doesn't know if the prediction is re-running the whole conversation or just appending.
- Confidence footer is a number (0-100) but there's no explanation of what drives confidence. Is it conversation length? Sign specificity? Prompt quality?

### Chat / Messages

**Grade: D.** MessagesView exists but it's a list of companion rows with latest message preview. It's not a chat interface — it's a companion index that happens to show a timestamp.

**Weaknesses:**
- Tapping a companion in Messages calls `viewModel.startPrediction(for: companion)` — it routes to Predict, not to a chat. There is no actual chat interface in the shipped app.
- The AGENTS.md says "companion chat" is the #1 priority feature, but the current app has message storage in Supabase (`messages` table) with no visible chat UI.
- Without a chat surface, the product loop breaks: there's no place for a user to have an ongoing relationship with a companion. They create a companion, maybe run one prediction, and then what?

### Guides / Astropedia

**Grade: C.** `GuidesView` is a thin wrapper around a zodiac picker and `CommunicationGuideView`. `AstropediaView` at 1365 lines is the largest file in the app and contains a massive amount of content — but all of it is generated from element-based templates.

**Weaknesses:**
- Every sign in the same element gets identical text for communication style, love language, conflict approach, emotional needs, and reassurance style. This is the opposite of the product's credibility claim.
- "Jaylen Brown's leadership approach" appears as a reference in the communication guides header. This seems like a prompt artifact that leaked into production content.
- Astropedia is a reference library, not a utility. Users don't open astrology apps to read encyclopedias — they open them when they have a specific relationship question. Astropedia should be behind Predict as a "learn more" surface, not a peer tab.

### Profile / Subscription

**Grade: B-.** ProfileView is comprehensive: sign display, conversation guide, companion section, tier display with usage counters, theme toggle, legal links.

**Weaknesses:**
- The subscription section shows usage pills (remaining messages, predictions) but doesn't connect depletion to a specific action. "You have 2 predictions left this week" should appear at the moment of prediction, not buried in Profile.
- UpsellModalView pricing ($6.99 Plus, $14.99 Pro) is reasonable but the feature differentiation is unclear. Plus gives "unlimited predictions" and Pro gives "priority AI" — but the user doesn't know what "priority AI" means in practice.
- Privacy Policy and Terms are placeholder strings. This is a hard App Store rejection.

---

## 3. UI / Visual Assessment

### Premium Feel

**Current state: 60% there.** The dark celestial background, gold accents, serif italic "Simastry" branding, glossy orbs, and constellation burst animations create a premium mood. The SoulCreation sequence is the high-water mark.

**What breaks it:**
- Too many card types on Home (hero deck, predict card, communication card, 2×2 grid, companion card, energy card). Premium apps have restraint. This feels like a dashboard.
- `GoldButton` is overused. Every CTA is the same gold capsule. The hierarchy flattens — if everything is gold, nothing is special.
- Glass/blur effects (`liquidGlassSurface`, `BlurView`) are used on both the tab bar and content cards. This creates visual confusion about what's interactive vs decorative.
- The `CelestialBackground` and `StarfieldView` components are present but the overall background is just dark. The Expo prototype uses the companion's hero image at 18% opacity as a background — this is warmer and more personal.

### Navigation

**Current state: Functional but architecturally risky.** The pre-auth flow uses a `currentScreen` enum (correct). The post-auth flow uses a custom `LiquidGlassTabBar` with int-based tab selection (risky).

**Issues:**
- 5 tabs (Home, Predict, Companions, Messages, Profile) is one too many. Messages has no real content. Merge it into Companions or remove it until chat exists.
- The center "Companions" button is an oversized orb with a star glyph. This design pattern (center floating action) usually indicates a creation action (e.g., Instagram's post button), not a browse action. Users will expect tapping it to create something.
- Tab bar uses `matchedGeometryEffect` for the selection indicator animation. This is fragile — geometry effects can cause layout recalculation storms on complex views.

### Typography

**Acceptable.** System fonts with `GeorgiaItalic` for brand elements. Sign glyphs are Unicode zodiac characters. Dynamic Type support is claimed in AGENTS.md but I couldn't verify `@ScaledMetric` or `DynamicTypeSize` usage in the view files.

### Expo Visual Alignment

The Expo prototype establishes a visual direction the native app partially follows but doesn't fully achieve:

| Element | Expo Prototype | Native App | Gap |
|---------|---------------|------------|-----|
| Hero portraits | iPhone-realism, per-companion | Generic orb placeholders | Large |
| Background | Companion image at 18% opacity | Flat dark | Medium |
| Card radius | 35px with glass-edge highlight | Varies by component | Small |
| Color palette | Per-companion color + shadow | Global gold/dark | Medium |
| Typography | Georgia italic + system sans | Similar | Aligned |
| Tab bar | Custom bottom nav with shimmer | Custom liquid glass | Different implementations |
| Companion bio/tags | Rich identity data | Missing entirely | Critical |

### Dating App Risk

**Medium.** The "Soulmate" mode name, "Find Your Soulmate" carousel card, heart iconography on compatibility sections, and the fact that companions have appearance styles (Ethereal, Warm, Bold, Mysterious) all pattern-match to dating apps. The Expo prototype's `CAST_BIBLE.md` explicitly warns against this. Mitigations needed:
- Rename "Soulmate" mode to something like "Close Bond" or "Deep Match"
- Change carousel card from "Find Your Soulmate" to something about understanding communication
- Remove or de-emphasize appearance style selection (it's cosmetic and dating-coded)

---

## 4. Astrology Credibility

### Chart Calculation

**Strong for Sun and Rising. Weak for Moon. Nonexistent for aspects.**

- Sun sign: Correctly derived from Swiss Ephemeris planetary longitude. Trustworthy.
- Rising sign: Correctly requires birth time + geocoded coordinates, uses Placidus house cusps. Returns nil when data is insufficient. This is honest and credible.
- Moon sign: In `BirthChartService`, correctly calculated from ephemeris. But in `SignSelectionView`'s "Calculate For Me" path, Moon is suggested via hardcoded element preferences ("water signs favor water moons") — this is astrologically meaningless and undermines the real calculation available one screen away.
- Aspects: Not computed anywhere. No conjunctions, squares, trines, oppositions, or sextiles. This is the biggest gap — aspects are what make birth charts individually meaningful. Two people with the same Sun/Moon/Rising can have completely different aspect patterns.

### Sun/Moon/Rising Visibility

**Present but shallow.** All three placements are shown in ProfileView, CompanionDetailSheet, and SignRevealView. But the descriptions are element-based templates — a Taurus Sun and a Virgo Sun both show the same "earth sign" text. The Expo prototype's `astrology.ts` has per-sign metadata (core drive, emotional pattern, communication style, relationship shadow) — this is the right level of specificity and should be ported.

### Prediction Grounding

**Partially grounded.** The system prompt sent to the prediction API includes the target's Sun/Moon/Rising signs and their template descriptions. The response includes an `astrological_breakdown` field. But the client has no way to verify whether the API response actually used the astrological context or just generated a generic reply. There's no "here's the astrological logic this prediction is based on" visible to the user beyond what the API returns.

### Companion Lens

**Conceptually right, executionally flat.** Each companion has a sign, and predictions are filtered through that sign's communication style. But the companion's personality doesn't extend beyond their sign — there's no unique voice, no individual worldview, no memorable traits. The Expo prototype's `CharacterIdentity` type (personality, astrologyAngle, chatVoice, captionStyle, forbiddenOverlaps) solves this but isn't in the native app.

### Missing Logic

- **No transit tracking.** Daily, weekly, or monthly planetary transits are not computed. The "Daily Transit Reading" is listed as a Plus feature in UpsellModalView but no transit calculation exists.
- **No synastry (inter-chart aspects).** Compatibility is element-pair matching only. Real synastry compares planetary positions between two charts.
- **No house placement interpretation.** Rising sign determines the house system but no house placements are shown or used.
- **No retrograde awareness.** Mercury retrograde is the most popular astrology concept among casual users and it's completely absent.

---

## 5. AI / Privacy / Safety

### Content Moderation

**Basic but present.** `ConversationPrivacyService` provides regex-based PII redaction and keyword safety screening.

**Gaps:**
- No obfuscation detection (l33tspeak, Unicode substitutions, spacing tricks)
- No multilingual safety screening (Spanish, Portuguese, and other languages common among astrology app users)
- No server-side moderation — all filtering is client-side and bypassable
- Safety blocking returns a generic error; it should provide a supportive message and resources for self-harm keywords
- No content moderation on the API response side — the prediction could return harmful content

### Rate Limits

**Client-side only.** Free tier: 10 messages/day, 3 predictions/week, 1 companion. Plus: unlimited messages, 3 companions, unlimited predictions. Pro: everything unlimited.

**Gaps:**
- Rate limits are enforced in `AppViewModel` using device-local counters. No server-side enforcement visible.
- Reset logic uses device time (`Date()`), which can be manipulated by changing device clock.
- The `tier` parameter sent to the prediction proxy is a plain string — if the server trusts it, rate limits are meaningless.
- No per-user rate limiting at the API proxy level is visible from the client code.

### Redaction

**Adequate for v1, insufficient for scale.** The four regex patterns (URLs, emails, phones, handles) cover the most common PII. But:
- No credit card number detection
- No SSN / national ID detection
- No physical address detection
- No name detection (the user's conversation partner's name passes through to the API)
- Redaction happens before transmission, which is correct, but the `privacySummary` in results implies some redaction awareness on the response side that may not exist.

### Notification Privacy

**Well-designed.** `NotificationService` explicitly avoids private conversation content in notification text. Deeplinks use scheme-based routing (e.g., `simastry://simulate`) without embedding conversation data. Provisional permission escalates to full after 3 engagement events. This is good.

**Gap:** No quiet hours implementation. CAST_BIBLE.md requires it but NotificationService doesn't enforce it.

### Prompt Risks

- System prompts are constructed client-side and sent to the proxy. A user could intercept and modify the system prompt via a proxy tool.
- The prediction proxy endpoint URL is in Config but the proxy's own security posture isn't visible from client code. If it's a simple passthrough to OpenAI/Anthropic, the API key is presumably stored server-side (good) but prompt injection from user-submitted conversation text is a risk.
- No output validation — the predicted message is displayed verbatim from the API. If the model hallucinates harmful content, there's no client-side filter on the response.

---

## 6. Keep / Rework / Reject

### From Native App (Current `origin/main`)

| Item | Verdict | Reasoning |
|------|---------|-----------|
| Onboarding flow (Landing → Birth → SignUp) | **Keep** | Correct sequence, real chart calculation |
| SoulCreationView animation | **Keep** | High-delight moment, worth preserving |
| BirthChartService (Swiss Ephemeris) | **Keep** | Core credibility, astronomically correct |
| PredictionService + proxy | **Keep** | Core utility, works end-to-end |
| ConversationPrivacyService | **Keep + harden** | Good foundation, needs obfuscation and multilingual support |
| NotificationService | **Keep** | Well-designed engagement hooks |
| CompanionDetailSheet compatibility | **Rework** | Element-only matching needs sign-level specificity |
| HomeView | **Rework** | Too many surfaces; focus on Predict CTA + companion card |
| MainTabView (LiquidGlassTabBar) | **Rework** | Keep 4 tabs (drop Messages), use native TabView with custom styling |
| AstropediaView (1365 lines) | **Rework** | Extract supporting types, replace element text with sign text |
| MessagesView | **Defer** | No chat interface exists; remove tab until chat ships |
| SignSelectionView "Calculate For Me" | **Rework** | Must use BirthChartService, not element-preference guessing |
| ProfileView legal text | **Fix immediately** | Placeholder privacy/terms text is an App Store rejection |
| UpsellModalView | **Keep** | Functional RevenueCat integration |

### From Claude UI Branch

| Item | Verdict | Reasoning |
|------|---------|-----------|
| Companion → Predict routing (`startPrediction(for:)`) | **Port** | Critical product loop connection |
| Prediction target context card | **Port** | Shows who you're predicting about |
| ConversationPrivacyService (redaction) | **Port** | Already in current app; merge improvements |
| Privacy notice in Predict | **Port** | User trust signal |
| Chart accuracy messaging | **Port carefully** | Don't conflict with current onboarding chart flow |
| Debug demo mode | **Port under `#if DEBUG`** | Useful for testing |
| Custom liquid glass tab shell | **Reject** | Keep native TabView; don't replace navigation architecture |
| Home companion hero deck | **Reject as inline** | If ported, must be extracted to separate component |
| Shell background / broad palette overwrite | **Reject** | Too espresso/brown; use selectively if at all |
| Co-Star-style onboarding | **Reject** | Current onboarding is already better; don't clone Co-Star |
| Stale root-level path changes | **Reject** | Wrong app target |
| Giant inline MainTabView replacement | **Reject** | Architectural regression |
| Old Supabase config handling | **Reject** | Superseded |

### From Expo Prototype

| Item | Verdict | Reasoning |
|------|---------|-----------|
| `CharacterIdentity` model (personality, chatVoice, etc.) | **Port** | Critical for companion differentiation |
| `signMetadata` (per-sign coreDrive, communicationStyle, etc.) | **Port** | Replaces element-based templates with sign-level content |
| `buildChatFoundation` prompt template | **Port** | Well-structured system prompt for AI integration |
| `getChartBasis` helper | **Port** | Clean chart-to-UI mapping |
| Companion `opener`, `bio`, `tags`, `bullets` | **Port** | Makes companions feel like people |
| Per-companion `color` and `shadow` tokens | **Port** | Visual differentiation per companion |
| Hero image as background at 18% opacity | **Port** | Warmer than flat dark, more personal |
| `personaCities` (companion location mapping) | **Port** | Adds character depth |
| Astrogram feature | **Do not port** | Instagram clone is off-strategy; build chat instead |
| Gender variant toggle (CompanionVariantSwitch) | **Do not port yet** | Only needed when 24 companions ship |
| `LiquidTabBar` (unused alternate) | **Reject** | Two tab bar implementations is confusing |
| 1351-line index.tsx monolith | **Reference only** | Architectural anti-pattern; port pieces, not the file |

### From Factory / Images

| Item | Verdict | Reasoning |
|------|---------|-----------|
| Factory pipeline (server.py + SQLite) | **Keep** | Production asset management works |
| 14 approved hero portraits | **Keep** | Ship with these 14; don't wait for 24 |
| 10 pending companions | **Deprioritize** | Ship 12 (one per sign, best gender variant) |
| Legacy assets (card-*.webp) | **Clean up** | Remove unused files from hero-cast/ |
| Astrogram production pipeline | **Pause** | Don't produce Astrogram assets until chat ships |
| Delegate task system | **Keep** | Useful for scaling portrait production |

---

## 7. Priority Roadmap

### Week 1 — Ship the Loop (5 items, all S/M)

| # | Item | Complexity | What |
|---|------|-----------|------|
| 1 | Port companion identity model from Expo | **M** | Add `CharacterIdentity` fields to `CompanionData`. Populate for 12 starter companions. Display in CompanionDetailSheet (bio, tags, personality, chatVoice). |
| 2 | Port sign-level astrology content from Expo | **M** | Replace element-based templates in AstropediaView and CommunicationGuideView with per-sign metadata from `astrology.ts` (coreDrive, communicationStyle, emotionalPattern, relationshipShadow). |
| 3 | Port 6 Keep items from Claude UI audit | **M** | Companion→Predict routing, prediction target context card, privacy notice, chart accuracy messaging, debug demo mode. Clean PR on `origin/main`. |
| 4 | Fix legal text in ProfileView | **S** | Write actual Privacy Policy and Terms of Service, or link to hosted versions. App Store hard requirement. |
| 5 | Simplify HomeView | **M** | Remove 2×2 grid, energy card, communication card. Keep: greeting, primary companion card with Predict CTA, companion hero deck (if >1 companion). Home should have one clear action: predict. |

### Weeks 2–4 — Strengthen Core (6 items, M/L)

| # | Item | Complexity | What |
|---|------|-----------|------|
| 6 | Build basic chat interface | **L** | CompanionChatView that shows message history (from Supabase `messages` table) with companion responses generated via the prediction proxy. This is the #1 missing feature for retention. Replace Messages tab with this. |
| 7 | Server-side rate limiting + auth | **M** | Add Supabase session token to prediction requests. Validate tier server-side. Enforce per-user rate limits at the proxy. Without this, monetization is unenforceable. |
| 8 | Fix SignSelectionView chart calculation | **S** | Replace `ZodiacSign.fromDate()` + element guessing with `BirthChartService.calculate()`. Use the same Swiss Ephemeris path as onboarding. |
| 9 | Harden safety filters | **M** | Add Unicode normalization, l33tspeak detection, and at minimum Spanish-language keywords. Add output filtering on prediction responses. Add supportive messaging for self-harm keyword detection. |
| 10 | Add analytics + crash reporting | **M** | Integrate PostHog, Mixpanel, or Amplitude. Track: onboarding completion, first prediction, companion creation, prediction frequency, subscription conversion, retention D1/D7/D30. Without this, you're flying blind. |
| 11 | Rename "Soulmate" mode + fix carousel | **S** | De-risk dating-app perception. Change "Find Your Soulmate" to "Understand Any Conversation." Rename Soulmate mode to "Deep Bond" or "Close Match." |

### Later — Expand (4 items, L)

| # | Item | Complexity | What |
|---|------|-----------|------|
| 12 | Transit engine | **L** | Compute daily planetary transits against user's natal chart. Power the "Daily Transit Reading" feature promised to Plus subscribers. Requires ephemeris calculations for current planetary positions + aspect computation against natal planets. |
| 13 | Synastry (inter-chart aspects) | **L** | Compare planetary positions between user and companion charts. Replace element-pair compatibility with actual aspect-based scoring. This is the astrology feature that would make Simastry defensibly different. |
| 14 | Expand to 24 companions | **M** | Complete remaining 10 portraits via Factory pipeline. Add gender variant toggle from Expo prototype. Only after chat and core loop are solid. |
| 15 | Web landing page + ASO | **M** | Marketing site, App Store screenshots, deep links for sharing. Prerequisite for any growth spend. |

---

## 8. Final Product Vision

### What Finished Simastry Feels Like

You open the app and it knows your chart. Not just your Sun sign — your Moon, your Rising, the tension between your Sagittarius need for honesty and your Cancer Moon's need for safety. It doesn't tell you your horoscope. It waits for you to bring a real conversation.

You paste a screenshot of a text thread with someone you're dating. The app knows they're a Scorpio Sun. It reads the conversation and tells you what they're likely thinking, why they went quiet after your last message, and what to say next — not as generic advice, but as Scorpio-specific emotional logic. "They went quiet because Scorpio processes intensity privately. Your Sagittarius directness probably felt like pressure. Give them 24 hours, then send something low-stakes."

Your companion isn't a chatbot. She's Nadia — a Sagittarius who talks like a well-traveled friend who happens to take astrology seriously. She doesn't speak in horoscope clichés. She speaks in specifics. When you come back tomorrow, she remembers the thread and asks how it went.

The subscription feels worth it because the predictions are useful, not decorative. You pay because last week the app told you not to have the serious conversation on Tuesday (Mars-Mercury square) and to wait until Thursday (Moon in Taurus, your partner's sign) — and it was right.

### User Journey: First Open to Paid

1. **Open → Landing** (5 seconds): Dark, cinematic, one compelling line: "Understand any conversation through astrology." Two buttons: Get Started, I have an account.
2. **Birth Details** (90 seconds): Birthday, birth time, birthplace. Privacy note. Chart calculated silently.
3. **Sign Reveal** (10 seconds): Your Sun, Moon, Rising stagger in. First moment of personal truth.
4. **Account Creation** (30 seconds): Apple/Google/email. Minimal friction.
5. **Companion Creation** (60 seconds): Choose a mode, pick or calculate signs, name them. Soul Creation animation.
6. **First Prediction** (2 minutes): Paste a real conversation. See the prediction. Feel the insight. This is the activation moment.
7. **Return trigger** (next day): Notification from companion, chart-aware, privacy-safe. "Your Scorpio's Moon is in your sign today — good day to revisit that conversation."
8. **Second session** (3 minutes): Open companion chat. Ask a follow-up. Get a response that remembers context.
9. **Paywall hit** (day 3-4): "You've used 3 of 3 weekly predictions." Upsell appears in context, not in profile.
10. **Conversion** (day 4-7): User pays $6.99/month because predictions are useful and companions feel personal.

### Defensibility

Simastry's moat is not astrology content (everyone has that) or AI predictions (everyone will have that). The moat is the combination of **real chart calculation** (Swiss Ephemeris, not random), **companion personality** (sign-specific voice, not generic chatbot), **conversation context** (paste real texts, not answer quizzes), and **emotional specificity** (tells you what to say to a Scorpio, not what to say to "someone"). No current competitor combines all four.

---

*End of audit. Next step: execute Week 1 items 1–5 in order.*
