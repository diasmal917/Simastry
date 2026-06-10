# Simastry Companion Cast Bible

Recommendation: treat `data/companions.ts` as the app-facing source of truth and this file as the product bible for generation, review, and copy QA.

Rationale: the 24 companions are the product surface. Every sign needs one female and one male companion, but no unfinished portrait should masquerade as final.

Next action: generate and approve missing portraits and Astrogram photo packs one companion at a time, using the forbidden-overlap notes below.

## Product Rules

- Conversation-first astrology, not a horoscope feed.
- Every character must feel like a realistic, very good-looking, casual astrology influencer and a private one-on-one companion.
- Photos must look like iPhone / Instagram posts from real people: available light, imperfect framing, real skin texture, normal asymmetry, varied pose and crop.
- Avoid AI-editorial polish, fantasy styling, plastic skin, model-card imagery, repeated selfie angles, and duplicate face templates.
- Astrology guidance must be grounded in real logic: Sun for core drive, Moon for emotional needs, Rising for first impression, with future room for transits.
- Notification previews must be opt-in, privacy-safe, and never expose private conversation content.

## Current App Status

- Approved portrait assets: Cassian, Amara, Ada, Theo, Arden, Mila, Leona, Mara, Isolde, Elias, Nadia, Silas, Yarrow, Zev.
- Needs-generation portraits: Rina, Noel, Dante, Jonah, Mateo, Vera, Rafi, Naomi, Imani, Liora.
- All 24 companions now exist structurally in `data/companions.ts`.
- Planned companions render as portrait-in-review cards until a unique approved portrait exists.
- Each companion has three Astrogram post concepts/captions in data. Many still need unique photo assets.

## Cast Matrix

| Sign | Female companion | Male companion | Core distinction |
| --- | --- | --- | --- |
| Aries | Amara | Cassian | Amara is bright nerve and sporty heat; Cassian is direct pursuit and rooftop confidence. |
| Taurus | Ada | Theo | Ada is sensual stillness and kitchen-window proof; Theo is patient tactile loyalty. |
| Gemini | Rina | Arden | Rina is social sparkle and fast phrasing; Arden is transit/bookstore wit and hinge-word reads. |
| Cancer | Mila | Noel | Mila is protective tenderness; Noel is quiet rain-window care and emotional shelter. |
| Leo | Leona | Dante | Leona needs a new high-presence Leo lane; Dante is generous musician charisma. |
| Virgo | Mara | Jonah | Mara is practical elegance and detail repair; Jonah is gentle design-studio precision. |
| Libra | Isolde | Mateo | Isolde is composed social nuance; Mateo is graceful fairness and polished tact. |
| Scorpio | Vera | Elias | Vera is controlled undercurrent and power; Elias is private motive and withheld truth. |
| Sagittarius | Nadia | Rafi | Nadia is free, candid movement; Rafi is spacious humor and honest distance. |
| Capricorn | Naomi | Silas | Naomi is velvet discipline and standards; Silas is earned gravity and accountability. |
| Aquarius | Imani | Yarrow | Imani is cool future patterning; Yarrow is detached systems intelligence. |
| Pisces | Liora | Zev | Liora is soft projection clarity; Zev is rainy-bar emotional weather. |

## Generation Queue

Use this order so the visible app reaches full 24-person parity quickly:

1. Generate Rina, Noel, Dante, Jonah.
2. Generate Mateo, Vera, Rafi, Naomi.
3. Generate Imani and Liora.
4. Generate three unique Astrogram posts for each approved companion before expanding to more than three.

## Cast Separation Checklist

Every new portrait must pass this checklist before it is copied into `assets/hero-cast` and marked approved:

- The person cannot be mistaken for Ada, Mila, Nadia, or any other approved companion at thumbnail size.
- Hair shape/color, face structure, skin tone, setting, posture, and emotional temperature must differ from the nearest approved character.
- The image must look like a casual iPhone/Instagram photo, not an AI editorial portrait.
- The companion must keep the sign's emotional role without using costume-like zodiac styling.
- If the image lands in the warm brunette cafe/travel lane, reject it unless it is explicitly for Nadia.

| Companion | Visual lane | Forbidden overlaps | Required differentiators | Portrait status | Astrogram status |
| --- | --- | --- | --- | --- | --- |
| Cassian | Latino / Southern European rooftop Aries heat | Elias polish, Zev softness | Athletic posture, direct eye contact, red/white street energy | Approved | 2 real images, 1 concept |
| Amara | Black Caribbean sporty Aries spark | Leona glamour, Nadia travel | Cropped sporty styling, motion, bright street/court setting | Approved | 1 real image, 2 concepts |
| Ada | Taurus kitchen/window earth sensuality | Nadia travel/cafe, Leona glamour | Olive warmth, moss/cream textures, settled body language | Approved | 1 real image, 2 concepts |
| Theo | Taurus tactile steadiness | Silas severity, Zev softness | Broad calm face, market/record-store settings, grounded hands | Approved | 1 real image, 2 concepts |
| Arden | Gemini bookstore/transit wit | Cassian directness, Yarrow detachment | Messy light hair, quick expression, transit/bookshop language | Approved | 1 real image, 2 concepts |
| Rina | Gemini social sparkle | Isolde polish, Nadia freedom | Short glossy bob, expressive hands, magazine/subway settings | Needs generation | 3 concepts |
| Mila | Cancer guarded softness | Ada sensuality, Nadia openness | Protective posture, rainy/window domestic warmth, guarded eyes | Approved | 2 real images, 1 concept |
| Noel | Cancer quiet shelter | Zev dreaminess, Theo steadiness | Rain-window diner softness, close-cropped hair, careful eye contact | Needs generation | 3 concepts |
| Leona | Leo high-presence glamour, bright public charisma | Ada/Mila/Nadia warm brunette lane, denim/white tank cafe portraits | Blonde/copper curls, red/black styling, rooftop/theater/music/hotel setting, confident public-facing posture | Approved | 1 real image, 2 concepts |
| Dante | Leo musician charisma | Cassian pursuit, Elias intensity | Warm stage-adjacent setting, broad smile, open shirt/gold chain | Needs generation | 3 concepts |
| Mara | Virgo practical elegance | Capricorn severity, Libra polish | South Asian clarity, worktable/studio detail, precise gaze | Approved | 1 real image, 2 concepts |
| Jonah | Virgo gentle precision | Yarrow systems, Theo earth | Wire glasses, design-studio restraint, notebook/repair cues | Needs generation | 3 concepts |
| Isolde | Libra composed social nuance | Leona spotlight, Ada stillness | Moroccan/French gallery elegance, poised side glance | Approved | 2 real images, 1 concept |
| Mateo | Libra polished tact | Dante charisma, Elias privacy | Refined beard, linen/hotel/gallery social ease | Needs generation | 3 concepts |
| Elias | Scorpio private motive | Zev softness, Silas restraint | Low light, intense eyes, withheld expression | Approved | 1 real image, 2 concepts |
| Vera | Scorpio controlled undercurrent | Leona warmth, Ada sensuality | Braids, low-light city intimacy, still gaze | Needs generation | 3 concepts |
| Nadia | Sagittarius long-haired warm brunette travel/cafe lane | Ada grounded stillness, Leona future portraits | Travel/cafe movement, leather/linen, open restless expression | Approved | 4 real images |
| Rafi | Sagittarius spacious humor | Dante stage warmth, Cassian pursuit | Ferry/rooftop/street-food travel musician ease | Needs generation | 3 concepts |
| Silas | Capricorn mature accountability | Theo warmth, Elias intensity | Tailored restraint, time/effort seriousness, no model-card stiffness | Approved | 1 real image, 2 concepts |
| Naomi | Capricorn velvet discipline | Isolde elegance, Mara precision | Sculptural face, long coat, standards/time posture | Needs generation | 3 concepts |
| Yarrow | Aquarius systems distance | Gemini chatter, Virgo precision | Angular face, tech-art edge, off-camera pattern gaze | Approved | 1 real image, 2 concepts |
| Imani | Aquarius cool future pattern | Vera intensity, Rina motion | Shaved/short style, experimental monochrome, warehouse/night-bus setting | Needs generation | 3 concepts |
| Zev | Pisces rainy-bar emotional weather | Nadia face/travel, Silas restraint | East Asian/Mediterranean softness, navy overshirt, listening posture | Approved | 1 real image, 2 concepts |
| Liora | Pisces artist-at-home softness | Mila protectiveness, Ada stillness | Soft curls, paint/studio/shoreline, tender but clear posture | Needs generation | 3 concepts |

## Notification Foundation

Notifications should feel like a message from a companion, but not reveal private conversations.

Allowed:

- Chart-aware nudges based on Sun, Moon, Rising.
- General timing and tone guidance.
- Companion voice and sign logic.

Not allowed:

- Quoting a private message.
- Revealing who the user is talking to.
- Mentioning sensitive conversation memories in preview text.
- Sending without opt-in and quiet-hours controls.

Example:

> Your Cancer Moon might read silence as rejection today. Wait before you answer.

Future implementation should add:

- User opt-in state.
- Quiet hours.
- Chart placements from onboarding.
- Transit-aware templates.
- A privacy-safe memory summary that is never displayed in the notification preview.

## Astrology And AI Chat Foundation

Current implementation:

- `data/astrology.ts` is the deterministic local astrology layer.
- `data/chat-foundation.ts` builds mock companion readings, prompt templates, and privacy-safe notification examples.
- The current mock user chart is Sagittarius Sun, Cancer Moon, Libra Rising.
- No backend or AI API is called in the Expo prototype.

Rules:

- Use Sun as the user's core identity and drive.
- Use Moon as emotional needs, reactions, and safety cues.
- Use Rising as presentation, first instinct, and social tone.
- Use the companion sign as the interpretive lens and conversation style.
- Include sign element, modality, polarity, and ruler as grounding logic, not decorative trivia.
- Do not invent chart placements, transits, or memories that were not provided.
- Do not use random horoscope output.

Future backend prompt builders should preserve:

- companion identity and voice
- companion sign lens
- user Sun/Moon/Rising
- relationship/message context
- deterministic astrology rules
- privacy rules for notification previews
