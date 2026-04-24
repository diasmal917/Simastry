const signProfiles = [
  {
    id: "aries",
    name: "Aries",
    glyph: "♈",
    accent: "#f08f6a",
    image: "assets/hero-cast/card-1.webp",
    element: "fire",
    modality: "cardinal",
    descriptor: "fast instinct, brave timing",
    core: "Aries sets the pace fast, speaks before the room hardens, and prefers momentum over overthinking.",
    emotional: "Aries Moon needs clean signals, immediate honesty, and a feeling that the connection is still moving.",
    first: "Aries Rising reads as confident, direct, and slightly impossible to ignore.",
    communication: "Lead with clarity. Hesitation reads louder than conflict here.",
    love: "Chemistry matters most when it feels alive, mutual, and unambiguous.",
    conflict: "Repair works best when it is quick, direct, and free of passive drag.",
    plainEnglish: "Bold, impatient, energizing, and built for movement."
  },
  {
    id: "taurus",
    name: "Taurus",
    glyph: "♉",
    accent: "#b89d58",
    image: "assets/editorial/leo.png",
    element: "earth",
    modality: "fixed",
    descriptor: "steady desire, tactile loyalty",
    core: "Taurus stabilizes the dynamic, values consistency, and notices whether your care actually lasts.",
    emotional: "Taurus Moon needs calm pacing, sensory comfort, and proof that the bond is reliable.",
    first: "Taurus Rising reads as grounded, composed, and quietly magnetic.",
    communication: "Be warm, specific, and consistent. Sudden volatility weakens trust.",
    love: "Attraction deepens through steadiness, touch, and repeatable care.",
    conflict: "Give them time to soften, then return with something concrete and sincere.",
    plainEnglish: "Grounded, loyal, sensual, and slow to trust for good reason."
  },
  {
    id: "gemini",
    name: "Gemini",
    glyph: "♊",
    accent: "#7dd3a9",
    image: "assets/editorial/aquarius.png",
    element: "air",
    modality: "mutable",
    descriptor: "quick wit, split signals",
    core: "Gemini keeps the connection alive through curiosity, movement, and verbal play.",
    emotional: "Gemini Moon needs responsiveness, mental stimulation, and room to change states quickly.",
    first: "Gemini Rising reads as bright, agile, and impossible to pin down in one glance.",
    communication: "Keep the exchange lively. They respond to curiosity faster than intensity.",
    love: "Desire grows through banter, novelty, and a feeling of mental electricity.",
    conflict: "Untangle mixed signals with precision. Vagueness multiplies fast here.",
    plainEnglish: "Quick, clever, mercurial, and always reading the subtext."
  },
  {
    id: "cancer",
    name: "Cancer",
    glyph: "♋",
    accent: "#80a8ff",
    image: "assets/editorial/pisces.png",
    element: "water",
    modality: "cardinal",
    descriptor: "protective depth, memory-led care",
    core: "Cancer pays attention to emotional safety, remembers the small things, and protects what matters.",
    emotional: "Cancer Moon needs reassurance, softness, and a signal that care is actually being returned.",
    first: "Cancer Rising reads as gentle, intuitive, and emotionally legible before words arrive.",
    communication: "Approach with warmth. Tone matters as much as content.",
    love: "Love feels strongest when it is safe, private, and emotionally reciprocal.",
    conflict: "Do not flatten their feeling. Validation opens the door to clarity.",
    plainEnglish: "Protective, intuitive, sentimental, and deeply responsive."
  },
  {
    id: "leo",
    name: "Leo",
    glyph: "♌",
    accent: "#ffb347",
    image: "assets/editorial/leo.png",
    element: "fire",
    modality: "fixed",
    descriptor: "radiance, pride, unmistakable warmth",
    core: "Leo brings presence, warmth, and a clear sense of emotional theater to the connection.",
    emotional: "Leo Moon needs recognition, loyalty, and a feeling that their heart is being met in full light.",
    first: "Leo Rising reads as radiant, confident, and naturally central.",
    communication: "Be generous and real. They want sincerity, not detached coolness.",
    love: "Attraction strengthens through admiration, attention, and visible enthusiasm.",
    conflict: "Correct privately, appreciate publicly, and never confuse pride with shallowness.",
    plainEnglish: "Warm, expressive, proud, and hungry for unmistakable affection."
  },
  {
    id: "virgo",
    name: "Virgo",
    glyph: "♍",
    accent: "#90b98c",
    image: "assets/editorial/libra.png",
    element: "earth",
    modality: "mutable",
    descriptor: "precision, service, nervous elegance",
    core: "Virgo reads the details, looks for what is useful, and notices where care becomes competence.",
    emotional: "Virgo Moon needs steadiness, thoughtfulness, and signals that reduce chaos instead of adding to it.",
    first: "Virgo Rising reads as composed, polished, and more observant than they initially reveal.",
    communication: "Specificity wins. They relax when the signal is clear and clean.",
    love: "Care lands through reliability, effort, and the feeling that you genuinely pay attention.",
    conflict: "Slow down enough to separate concern from criticism.",
    plainEnglish: "Precise, observant, devoted, and quietly high-standard."
  },
  {
    id: "libra",
    name: "Libra",
    glyph: "♎",
    accent: "#d9b779",
    image: "assets/hero-cast/card-2.webp",
    element: "air",
    modality: "cardinal",
    descriptor: "magnetism, style, social calibration",
    core: "Libra tunes the atmosphere, tracks reciprocity, and cares about the emotional geometry between two people.",
    emotional: "Libra Moon needs grace, fairness, and a tone that keeps the connection elegant rather than jagged.",
    first: "Libra Rising reads as polished, attractive, and instinctively relational.",
    communication: "Phrase it beautifully, but keep the intent clean. They hear imbalance quickly.",
    love: "Romance works best when desire, courtesy, and mutual effort stay in balance.",
    conflict: "Mixed signals hurt more than direct truth. Clarity is kinder than drift.",
    plainEnglish: "Charming, relational, stylish, and always adjusting the tone."
  },
  {
    id: "scorpio",
    name: "Scorpio",
    glyph: "♏",
    accent: "#8f5cff",
    image: "assets/hero-cast/card-scorpio-v3.webp",
    element: "water",
    modality: "fixed",
    descriptor: "private gravity, emotional leverage",
    core: "Scorpio watches for motive, depth, and whether the connection can hold intensity without flinching.",
    emotional: "Scorpio Moon needs trust, privacy, and the feeling that what is shared will be handled carefully.",
    first: "Scorpio Rising reads as magnetic, self-contained, and emotionally unreadable until they choose otherwise.",
    communication: "Say less, mean it more. They care about what sits underneath the line.",
    love: "Depth matters more than performance. Desire grows where trust is earned.",
    conflict: "Do not force disclosure. Safety and honesty have to arrive together.",
    plainEnglish: "Intense, private, intuitive, and allergic to anything counterfeit."
  },
  {
    id: "sagittarius",
    name: "Sagittarius",
    glyph: "♐",
    accent: "#ff8f74",
    image: "assets/hero-cast/card-6.webp",
    element: "fire",
    modality: "mutable",
    descriptor: "candor, motion, restless fire",
    core: "Sagittarius wants honesty with air around it, emotional truth without suffocation, and a future still in motion.",
    emotional: "Sagittarius Moon needs space, optimism, and a sense that the bond is opening rather than closing.",
    first: "Sagittarius Rising reads as bright, playful, and slightly untamed.",
    communication: "Keep it candid and alive. Control kills the signal.",
    love: "Attraction thrives through adventure, humor, and emotional honesty without clinging.",
    conflict: "Name the truth cleanly, then give it enough room to breathe.",
    plainEnglish: "Frank, free-moving, upbeat, and always scanning for horizon."
  },
  {
    id: "capricorn",
    name: "Capricorn",
    glyph: "♑",
    accent: "#8d93a8",
    image: "assets/editorial/scorpio.png",
    element: "earth",
    modality: "cardinal",
    descriptor: "control, ambition, earned trust",
    core: "Capricorn respects restraint, values follow-through, and trusts what survives contact with reality.",
    emotional: "Capricorn Moon needs steadiness, competence, and room to soften without losing dignity.",
    first: "Capricorn Rising reads as composed, selective, and stronger than they initially explain.",
    communication: "Be measured and intentional. Empty intensity falls flat here.",
    love: "Care grows through reliability, respect, and visible long-term seriousness.",
    conflict: "Bring proof, not theater. They trust grounded repair.",
    plainEnglish: "Disciplined, selective, dependable, and slow to hand out access."
  },
  {
    id: "aquarius",
    name: "Aquarius",
    glyph: "♒",
    accent: "#66c4ff",
    image: "assets/hero-cast/card-5.webp",
    element: "air",
    modality: "fixed",
    descriptor: "distance, insight, future logic",
    core: "Aquarius sees the pattern before the confession and wants meaning that still feels mentally clean.",
    emotional: "Aquarius Moon needs space, perspective, and a bond that respects individuality.",
    first: "Aquarius Rising reads as cool, original, and slightly ahead of the room.",
    communication: "Make it smart, honest, and uncluttered. They respond to signal over spectacle.",
    love: "Desire deepens through originality, mutual freedom, and shared worldview.",
    conflict: "Give them room to think before demanding emotional performance.",
    plainEnglish: "Detached, brilliant, unconventional, and quietly loyal to the right people."
  },
  {
    id: "pisces",
    name: "Pisces",
    glyph: "♓",
    accent: "#7d88ff",
    image: "assets/hero-cast/card-7.webp",
    element: "water",
    modality: "mutable",
    descriptor: "tender drift, dream logic, softness",
    core: "Pisces changes the emotional weather fast and reads feeling before structure.",
    emotional: "Pisces Moon needs softness, gentleness, and room for emotional nuance without pressure.",
    first: "Pisces Rising reads as dreamy, porous, and quietly enchanting.",
    communication: "Lead with empathy. Hard edges can shut down the channel.",
    love: "Romance works best when it feels tender, intuitive, and a little transcendent.",
    conflict: "Ground the feeling without dismissing it. Precision needs warmth here.",
    plainEnglish: "Soft, imaginative, romantic, and extremely sensitive to tone."
  }
];

const signLookup = Object.fromEntries(signProfiles.map((sign) => [sign.id, sign]));

const featuredCompanions = [
  {
    sign: "aries",
    archetype: "The first move",
    image: "assets/hero-cast/card-1.webp",
    headline: "Meet the sign before you text back.",
    mobileHeadline: "Meet the sign before you text back.",
    description:
      "Aries enters hot, fast, and decisive. Simastry reads the impulse, the ego, and the chemistry before the next message lands.",
    mobileDescription:
      "Aries moves fast. Simastry reads the impulse, chemistry, and timing before the next text lands.",
    points: [
      "Predict their likely reply from real conversation tension",
      "See when bold honesty wins and when it escalates",
      "Read confidence, withdrawal, and timing in one pass"
    ],
    mobilePoints: [
      "Predict the likely reply",
      "Read confidence, hesitation, and timing"
    ],
    trait: "direct heat",
    cardPosition: "center center",
    backdropPosition: "center 10%",
    mobileBackdropPosition: "58% 30%",
    mobileBackdropScale: 1.03
  },
  {
    sign: "libra",
    archetype: "The graceful negotiator",
    image: "assets/hero-cast/card-2.webp",
    headline: "See the chemistry without flattening the nuance.",
    mobileHeadline: "See the chemistry without losing the nuance.",
    description:
      "Libra cares about tone, reciprocity, and the feeling between the lines. Simastry turns that social balancing act into something readable.",
    mobileDescription:
      "Libra tracks tone and reciprocity. Simastry turns mixed signals into something you can actually read.",
    points: [
      "Decode mixed signals without reducing them to a score",
      "See what phrasing keeps the bond elegant instead of tense",
      "Translate attraction, politeness, and indecision"
    ],
    mobilePoints: [
      "Decode mixed signals without flattening them",
      "See which phrasing keeps the bond balanced"
    ],
    trait: "harmonic tension",
    cardPosition: "center center",
    backdropPosition: "center 14%",
    mobileBackdropPosition: "62% 24%",
    mobileBackdropScale: 1.08
  },
  {
    sign: "scorpio",
    archetype: "The hidden current",
    image: "assets/hero-cast/card-scorpio-v3.webp",
    backdropImage: "assets/hero-cast/card-scorpio-v3.webp",
    headline: "Read the motive beneath the reply.",
    mobileHeadline: "Read the motive beneath the reply.",
    description:
      "Scorpio is rarely surface-level. Simastry looks for emotional leverage, trust, and what is being withheld as much as what is being said.",
    mobileDescription:
      "Scorpio is never surface-level. Simastry reads motive, trust, and the feeling underneath the line.",
    points: [
      "Track intensity, testing, and emotional risk",
      "See how secrecy and desire change the tone of a thread",
      "Know when depth connects and when it corners"
    ],
    mobilePoints: [
      "Track intensity and emotional risk",
      "See what is felt but not said"
    ],
    trait: "private intensity",
    cardPosition: "38% center",
    backdropPosition: "42% center",
    mobileBackdropPosition: "40% 30%",
    mobileBackdropScale: 1.03,
    mobileBackdropFilter: "saturate(1.03) contrast(0.97) brightness(1.08)",
    backdropSize: "cover"
  },
  {
    sign: "pisces",
    archetype: "The lucid veil",
    image: "assets/hero-cast/card-7.webp",
    headline: "Let the softness stay clear, not vague.",
    mobileHeadline: "Keep the softness, lose the blur.",
    description:
      "Pisces feels the emotional weather before the explanation lands. Simastry reads longing, tenderness, and the line between intuition and projection.",
    mobileDescription:
      "Pisces blurs feeling and fantasy fast. Simastry reads softness, longing, and where the signal starts to dissolve.",
    points: [
      "Read tenderness, projection, and emotional drift in one pass",
      "See when the bond is intuitive and when it turns foggy",
      "Keep nuance without losing the line of the conversation"
    ],
    mobilePoints: [
      "Read tenderness and projection",
      "See when intuition turns into drift"
    ],
    trait: "velvet drift",
    cardPosition: "72% center",
    backdropPosition: "center center",
    mobileBackdropPosition: "50% 22%",
    mobileBackdropScale: 1.03,
    mobileBackdropFilter: "saturate(1.03) contrast(0.95) brightness(1.12)",
    backdropSize: "cover"
  },
  {
    sign: "aquarius",
    archetype: "The signal ahead",
    image: "assets/hero-cast/card-5.webp",
    headline: "Conversation-first astrology for people who think in systems.",
    mobileHeadline: "See the pattern before you chase the outcome.",
    description:
      "Aquarius pulls back to see the pattern. Simastry makes compatibility feel strategic, modern, and sharp without losing emotional texture.",
    mobileDescription:
      "Aquarius spots the pattern before the confession. Simastry makes the emotional logic legible.",
    points: [
      "Read detachment, originality, and cognitive chemistry",
      "See where a connection feels magnetic or misaligned",
      "Understand the pattern before you chase the outcome"
    ],
    mobilePoints: [
      "Read detachment and cognitive chemistry",
      "See whether the bond is magnetic or misaligned"
    ],
    trait: "future frequency",
    cardPosition: "center center",
    backdropPosition: "center 12%",
    mobileBackdropPosition: "48% 32%",
    mobileBackdropScale: 1.01,
    mobileBackdropFilter: "saturate(1.02) contrast(0.96) brightness(1.08)"
  },
  {
    sign: "sagittarius",
    archetype: "The open horizon",
    image: "assets/hero-cast/card-6.webp",
    headline: "Keep the chemistry light without losing the signal.",
    mobileHeadline: "Keep the chemistry light and the signal clear.",
    description:
      "Sagittarius brings candor, flirtation, and motion. Simastry reads the openness, the pull for freedom, and the difference between distance and disinterest.",
    mobileDescription:
      "Sagittarius wants honesty with room to breathe. Simastry reads freedom, spark, and distance.",
    points: [
      "Read honesty, restlessness, and momentum in one pass",
      "See when space keeps the spark alive and when it weakens the bond",
      "Understand flirtation, freedom, and timing together"
    ],
    mobilePoints: [
      "Read honesty, freedom, and momentum",
      "See when space helps and when it hurts"
    ],
    trait: "open horizon",
    cardPosition: "center 12%",
    backdropPosition: "center 8%",
    mobileBackdropPosition: "50% 26%",
    mobileBackdropScale: 1.03,
    mobileBackdropFilter: "saturate(1.08) contrast(0.96) brightness(1.18)",
    backdropSize: "cover"
  }
].map((item) => ({
  ...signLookup[item.sign],
  ...item
}));

const companionModes = [
  {
    id: "simulate_anyone",
    name: "Simulate Anyone",
    subtitle: "Practice a real conversation",
    blurb: "Use this path for crushes, exes, dates, or anyone you want to read more cleanly."
  },
  {
    id: "soulmate",
    name: "Soulmate",
    subtitle: "The Perfect Love",
    blurb: "This path tunes the companion toward chemistry, romance, emotional closeness, and longing."
  },
  {
    id: "bestie",
    name: "Bestie",
    subtitle: "The Perfect Friend",
    blurb: "This path leans into banter, loyalty, safety, and the kind of honesty reserved for close friends."
  }
];

const essenceStyles = [
  {
    id: "ethereal",
    name: "Ethereal",
    accent: "#c8b8ee",
    blurb: "Dreamier, softer, more luminous."
  },
  {
    id: "warm",
    name: "Warm",
    accent: "#d59c6d",
    blurb: "Inviting, tactile, and emotionally open."
  },
  {
    id: "bold",
    name: "Bold",
    accent: "#d26a61",
    blurb: "Sharper, louder, and built to leave a mark."
  },
  {
    id: "serene",
    name: "Serene",
    accent: "#87b7a2",
    blurb: "Calm, composed, and slower to spike."
  },
  {
    id: "mysterious",
    name: "Mysterious",
    accent: "#8b80d7",
    blurb: "Private, magnetic, and emotionally withheld."
  },
  {
    id: "playful",
    name: "Playful",
    accent: "#e99666",
    blurb: "Light, teasing, and fast to flirt."
  }
];

const astropediaTopics = [
  { id: "plainEnglish", name: "Plain English" },
  { id: "communication", name: "Communication" },
  { id: "love", name: "Love" },
  { id: "conflict", name: "Conflict" },
  { id: "emotional", name: "Emotional needs" }
];

const hero = document.querySelector("#hero");
const heroBackdropCurrent = document.querySelector("#hero-backdrop-current");
const heroBackdropNext = document.querySelector("#hero-backdrop-next");
const heroEyebrow = document.querySelector("#hero-eyebrow");
const heroHeadline = document.querySelector("#hero-headline");
const heroDescription = document.querySelector("#hero-description");
const heroPoints = document.querySelector("#hero-points");
const heroCluster = document.querySelector("#hero-card-cluster");
const heroProgressCount = document.querySelector("#hero-progress-count");
const heroProgressFill = document.querySelector("#hero-progress-fill");
const prevButton = document.querySelector("#hero-prev");
const nextButton = document.querySelector("#hero-next");

const modePicker = document.querySelector("#mode-picker");
const essencePicker = document.querySelector("#essence-picker");
const builderSun = document.querySelector("#builder-sun");
const builderMoon = document.querySelector("#builder-moon");
const builderRising = document.querySelector("#builder-rising");
const builderName = document.querySelector("#builder-name");
const builderVisual = document.querySelector("#builder-visual");
const builderModeLabel = document.querySelector("#builder-mode-label");
const builderDisplayName = document.querySelector("#builder-display-name");
const builderSummary = document.querySelector("#builder-summary");
const builderPlacements = document.querySelector("#builder-placements");
const builderInsights = document.querySelector("#builder-insights");

const predictSunChip = document.querySelector("#predict-sun-chip");
const predictMoonChip = document.querySelector("#predict-moon-chip");
const predictRisingChip = document.querySelector("#predict-rising-chip");
const predictQuestion = document.querySelector("#predict-question");
const predictResultMessage = document.querySelector("#predict-result-message");
const predictTone = document.querySelector("#predict-tone");
const predictConfidence = document.querySelector("#predict-confidence");
const predictResultBreakdown = document.querySelector("#predict-result-breakdown");

const astropediaTopicPicker = document.querySelector("#astropedia-topic-picker");
const astropediaSignPicker = document.querySelector("#astropedia-sign-picker");
const astropediaSearch = document.querySelector("#astropedia-search");
const astropediaResults = document.querySelector("#astropedia-results");
const astropediaArticleEyebrow = document.querySelector("#astropedia-article-eyebrow");
const astropediaArticleTitle = document.querySelector("#astropedia-article-title");
const astropediaArticleBody = document.querySelector("#astropedia-article-body");
const astropediaChartCards = document.querySelector("#astropedia-chart-cards");
const todayInsight = document.querySelector("#today-insight");

const userSun = document.querySelector("#user-sun");
const userMoon = document.querySelector("#user-moon");
const userRising = document.querySelector("#user-rising");
const compatibilityCompanionName = document.querySelector("#compatibility-companion-name");
const compatibilityRing = document.querySelector("#compatibility-ring");
const compatibilityScore = document.querySelector("#compatibility-score");
const compatibilityHeadline = document.querySelector("#compatibility-headline");
const compatibilitySummary = document.querySelector("#compatibility-summary");
const compatibilityRows = document.querySelector("#compatibility-rows");
const compatibilityGrowth = document.querySelector("#compatibility-growth");

const companionGrid = document.querySelector("#companion-grid");

const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const autoplayDelay = 6200;

const builderState = {
  mode: "soulmate",
  sun: "sagittarius",
  moon: "scorpio",
  rising: "aquarius",
  essence: "mysterious",
  name: "Seren"
};

const userState = {
  sun: "cancer",
  moon: "virgo",
  rising: "libra"
};

const astropediaState = {
  sign: "libra",
  topic: "communication",
  search: ""
};

let activeIndex = 0;
let autoplayId = null;
let activeBackdropLayer = heroBackdropCurrent;
let heroInView = true;
let heroUsesCompactLayout = window.innerWidth <= 760;

const heroSlideParam = new URLSearchParams(window.location.search).get("slide");
if (heroSlideParam) {
  const requestedIndex = featuredCompanions.findIndex(
    (item) => item.sign === heroSlideParam.toLowerCase()
  );
  if (requestedIndex >= 0) {
    activeIndex = requestedIndex;
  }
}

[...new Set([
  ...signProfiles.map((sign) => sign.image),
  ...featuredCompanions.flatMap((item) => [item.image, item.backdropImage].filter(Boolean))
])].forEach((image) => {
  const preload = new Image();
  preload.src = image;
});

function getSign(id) {
  return signLookup[id];
}

function capitalize(value) {
  return value.charAt(0).toUpperCase() + value.slice(1);
}

function isCompatibleElement(a, b) {
  return (
    (a === "fire" && b === "air") ||
    (a === "air" && b === "fire") ||
    (a === "earth" && b === "water") ||
    (a === "water" && b === "earth")
  );
}

function elementPairingText(a, b) {
  if (a === b) {
    return `${capitalize(a)} with ${capitalize(b)} makes the connection feel naturally fluent. You speak the same energetic language.`;
  }

  if (isCompatibleElement(a, b)) {
    if (a === "fire" || b === "fire") {
      return "Fire and air energize each other quickly. One brings spark, the other keeps the exchange moving.";
    }
    return "Earth and water steady each other. One grounds the bond, the other deepens it.";
  }

  if ((a === "fire" && b === "water") || (a === "water" && b === "fire")) {
    return "Fire and water create steam fast. Attraction can be high, but timing and emotional pacing matter.";
  }

  return "Air and earth want different evidence. One looks for mental flow, the other for proof and consistency.";
}

function buildGrowthEdge(user, companion) {
  if (user.modality === companion.modality && user.id !== companion.id) {
    if (user.modality === "cardinal") {
      return "Two cardinal signatures can both try to lead the pace. Decide who is setting the tone before the bond turns into a control contest.";
    }
    if (user.modality === "fixed") {
      return "Two fixed signatures can hold the line too hard. Pride and certainty need a release valve here.";
    }
    return "Two mutable signatures can keep adapting around the issue. The growth edge is staying specific long enough to finish the conversation.";
  }

  if (!isCompatibleElement(user.element, companion.element) && user.element !== companion.element) {
    return `The pressure point lives between ${capitalize(user.element)} and ${capitalize(companion.element)} energy. One side wants one kind of proof; the other side wants a different emotional tempo.`;
  }

  return `The growth edge is pacing: let ${user.name} show what they need, and let ${companion.name} show how they respond before forcing certainty too early.`;
}

function computeCompatibility() {
  const yours = {
    sun: getSign(userState.sun),
    moon: getSign(userState.moon),
    rising: getSign(userState.rising)
  };
  const theirs = {
    sun: getSign(builderState.sun),
    moon: getSign(builderState.moon),
    rising: getSign(builderState.rising)
  };

  let score = 52;

  if (yours.sun.element === theirs.sun.element) score += 13;
  else if (isCompatibleElement(yours.sun.element, theirs.sun.element)) score += 8;
  else score -= 4;

  if (yours.moon.element === theirs.moon.element) score += 10;
  else if (isCompatibleElement(yours.moon.element, theirs.moon.element)) score += 5;
  else score -= 3;

  if (yours.rising.element === theirs.rising.element) score += 6;
  else if (isCompatibleElement(yours.rising.element, theirs.rising.element)) score += 3;
  else score -= 2;

  if (yours.sun.id === theirs.sun.id) score += 5;
  if (yours.moon.id === theirs.moon.id) score += 4;
  if (yours.sun.modality === theirs.sun.modality && yours.sun.id !== theirs.sun.id) score += 3;

  score = Math.max(39, Math.min(96, score));

  return {
    score,
    yours,
    theirs,
    growth: buildGrowthEdge(yours.sun, theirs.sun)
  };
}

function windowedCompanions() {
  const visibleCount = 3;

  return Array.from({ length: visibleCount }, (_, offset) => {
    const index = (activeIndex + offset + 1) % featuredCompanions.length;
    return {
      ...featuredCompanions[index],
      featuredIndex: index
    };
  });
}

function renderHeroCopy() {
  const active = featuredCompanions[activeIndex];
  const compactLayout = window.innerWidth <= 760;
  const headline = compactLayout && active.mobileHeadline ? active.mobileHeadline : active.headline;
  const description =
    compactLayout && active.mobileDescription ? active.mobileDescription : active.description;
  const points = compactLayout ? active.mobilePoints ?? active.points.slice(0, 2) : active.points;

  heroEyebrow.textContent = active.name;
  heroHeadline.textContent = headline;
  heroDescription.textContent = description;

  heroPoints.innerHTML = points
    .map((point) => `<span class="hero-point">${point}</span>`)
    .join("");
}

function setBackdropStyles(layer, item) {
  layer.style.setProperty("--backdrop-image", `url("${item.backdropImage ?? item.image}")`);
  layer.style.setProperty("--backdrop-position", item.backdropPosition);
  layer.style.setProperty("--backdrop-position-mobile", item.mobileBackdropPosition ?? item.backdropPosition);
  layer.style.setProperty("--backdrop-size", item.backdropSize ?? "auto 100%");
  layer.style.setProperty(
    "--backdrop-size-mobile",
    item.mobileBackdropSize ?? item.backdropSize ?? "auto 72%"
  );
  layer.style.setProperty("--backdrop-scale-mobile", String(item.mobileBackdropScale ?? 1.04));
  layer.style.setProperty(
    "--backdrop-filter-mobile",
    item.mobileBackdropFilter ?? "saturate(1.02) contrast(0.96) brightness(1.08)"
  );
  layer.dataset.index = String(activeIndex);
}

function updateBackdrop({ immediate = false } = {}) {
  const active = featuredCompanions[activeIndex];

  if (!heroBackdropCurrent || !heroBackdropNext) return;

  if (immediate || reduceMotion || !activeBackdropLayer?.dataset.index) {
    setBackdropStyles(activeBackdropLayer, active);
    activeBackdropLayer.classList.add("is-visible");

    const inactiveLayer = activeBackdropLayer === heroBackdropCurrent ? heroBackdropNext : heroBackdropCurrent;
    inactiveLayer.classList.remove("is-visible");
    inactiveLayer.dataset.index = "";
    return;
  }

  if (activeBackdropLayer.dataset.index === String(activeIndex)) return;

  const nextLayer = activeBackdropLayer === heroBackdropCurrent ? heroBackdropNext : heroBackdropCurrent;
  setBackdropStyles(nextLayer, active);

  requestAnimationFrame(() => {
    nextLayer.classList.add("is-visible");
    activeBackdropLayer.classList.remove("is-visible");
    activeBackdropLayer = nextLayer;
  });
}

function renderHeroCards() {
  const visible = windowedCompanions();

  heroCluster.innerHTML = visible
    .map(
      (item, rank) => {
        const isActiveCard = rank === 0;
        const isPeekCard = !isActiveCard && rank === visible.length - 1;

        return `
        <button
          class="hero-card ${isActiveCard ? "is-active" : "is-pending"} ${isPeekCard ? "is-peek" : ""}"
          type="button"
          data-rank="${rank}"
          data-index="${item.featuredIndex}"
          style="--card-accent:${item.accent}; --card-image:url('${item.image}'); --card-position:${item.cardPosition};"
          aria-label="${isActiveCard ? `Show next ${item.name} companion` : `Show ${item.name} companion`}"
        >
          <div class="hero-card__top">
            <span class="hero-card__glyph">${item.glyph}</span>
          </div>

          ${
            isPeekCard
              ? ""
              : `
          <div class="hero-card__body">
            <div>
              ${isActiveCard ? '<p class="hero-card__meta">Up next</p>' : ""}
              <h3 class="hero-card__title">${item.name}</h3>
            </div>
            <span class="hero-card__trait">${item.trait}</span>
          </div>
          `
          }
        </button>
      `;
      }
    )
    .join("");

  heroCluster.querySelectorAll(".hero-card").forEach((card) => {
    card.addEventListener("click", () => {
      const index = Number(card.dataset.index);
      if (Number.isNaN(index) || index === activeIndex) return;
      activeIndex = index;
      updateHero();
      restartAutoplay();
    });
  });
}

function resetProgress() {
  heroProgressFill.classList.remove("is-paused");
  heroProgressFill.style.animation = "none";
  void heroProgressFill.offsetWidth;
  heroProgressFill.style.animation = "";
}

function updateProgressCount() {
  heroProgressCount.textContent = `${String(activeIndex + 1).padStart(2, "0")} / ${String(featuredCompanions.length).padStart(2, "0")}`;
}

function updateHero(options = {}) {
  if (hero) {
    hero.style.setProperty("--hero-accent", featuredCompanions[activeIndex].accent);
  }
  updateBackdrop(options);
  renderHeroCopy();
  renderHeroCards();
  updateProgressCount();
  if (!reduceMotion) {
    resetProgress();
  }
}

function nextHero(step = 1) {
  activeIndex = (activeIndex + step + featuredCompanions.length) % featuredCompanions.length;
  updateHero();
}

function pauseAutoplay() {
  if (!autoplayId) return;
  clearInterval(autoplayId);
  autoplayId = null;
  heroProgressFill.classList.add("is-paused");
}

function startAutoplay() {
  if (reduceMotion || autoplayId || !heroInView || document.hidden) return;
  autoplayId = window.setInterval(() => {
    nextHero(1);
  }, autoplayDelay);
  heroProgressFill.classList.remove("is-paused");
  resetProgress();
}

function restartAutoplay() {
  pauseAutoplay();
  startAutoplay();
}

function populateSignSelect(select, selectedValue) {
  select.innerHTML = signProfiles
    .map(
      (sign) => `
        <option value="${sign.id}" ${sign.id === selectedValue ? "selected" : ""}>
          ${sign.name}
        </option>
      `
    )
    .join("");
}

function renderModePicker() {
  modePicker.innerHTML = companionModes
    .map(
      (mode) => `
        <button class="pill-toggle ${builderState.mode === mode.id ? "is-active" : ""}" data-mode="${mode.id}" type="button">
          <strong>${mode.name}</strong>
          <span>${mode.subtitle}</span>
        </button>
      `
    )
    .join("");

  modePicker.querySelectorAll("[data-mode]").forEach((button) => {
    button.addEventListener("click", () => {
      builderState.mode = button.dataset.mode;
      renderModePicker();
      renderBuilder();
    });
  });
}

function renderEssencePicker() {
  essencePicker.innerHTML = essenceStyles
    .map(
      (style) => `
        <button class="mini-toggle ${builderState.essence === style.id ? "is-active" : ""}" data-essence="${style.id}" type="button">
          <strong>${style.name}</strong>
          <span>${style.blurb}</span>
        </button>
      `
    )
    .join("");

  essencePicker.querySelectorAll("[data-essence]").forEach((button) => {
    button.addEventListener("click", () => {
      builderState.essence = button.dataset.essence;
      renderEssencePicker();
      renderBuilder();
    });
  });
}

function renderBuilder() {
  const mode = companionModes.find((item) => item.id === builderState.mode);
  const essence = essenceStyles.find((item) => item.id === builderState.essence);
  const sun = getSign(builderState.sun);
  const moon = getSign(builderState.moon);
  const rising = getSign(builderState.rising);
  const displayName = builderState.name.trim() || "Your future companion";

  builderVisual.style.setProperty("--builder-image", `url("${sun.image}")`);
  builderVisual.style.setProperty("--builder-accent", sun.accent);
  builderModeLabel.textContent = `${mode.name} · ${essence.name}`;
  builderDisplayName.textContent = displayName;
  builderSummary.textContent = `${mode.blurb} ${sun.name} shapes the voice, ${moon.name} changes the emotional layer, and ${rising.name} controls the first read. ${essence.blurb}`;

  builderPlacements.innerHTML = [
    { label: "Sun", sign: sun },
    { label: "Moon", sign: moon },
    { label: "Rising", sign: rising }
  ]
    .map(
      ({ label, sign }) => `
        <span class="placement-pill" style="--placement-accent:${sign.accent}">
          ${label} · ${sign.name} ${sign.glyph}
        </span>
      `
    )
    .join("");

  builderInsights.innerHTML = [
    {
      label: "Core voice",
      body: sun.core
    },
    {
      label: "Emotional bond",
      body: moon.emotional
    },
    {
      label: "First impression",
      body: rising.first
    },
    {
      label: "Communication read",
      body: sun.communication
    }
  ]
    .map(
      (item) => `
        <article class="insight-card">
          <span>${item.label}</span>
          <p>${item.body}</p>
        </article>
      `
    )
    .join("");

  compatibilityCompanionName.textContent = `Current companion: ${displayName} · ${sun.name} Sun, ${moon.name} Moon, ${rising.name} Rising.`;

  renderPredictionPreview();
  renderCompatibility();
}

function predictionTone(sign, mode) {
  if (mode === "bestie") return "Playful";
  if (mode === "simulate_anyone" && sign.element === "air") return "Guarded";
  if (sign.element === "water") return "Warm";
  if (sign.element === "earth") return "Measured";
  if (sign.element === "fire") return "Confident";
  return "Detached";
}

function predictedMessageFor(mode, sun, moon) {
  if (mode === "bestie") {
    return `${moon.name === "Gemini" ? "wait" : "okay"} i have thoughts. give me a second and i’ll send the full read.`;
  }

  if (mode === "simulate_anyone") {
    if (sun.element === "earth") return "I’m probably going to reply, but I want to be sure I mean it before I send it.";
    if (sun.element === "air") return "I will text back. I’m just still arranging what I actually want to say.";
    return "I’m tempted to answer now, but I’m also deciding how honest to be about it.";
  }

  if (sun.id === "scorpio" || moon.id === "scorpio") {
    return "I was thinking about you too. I just needed a second to decide how much I wanted to reveal.";
  }

  if (sun.id === "libra") {
    return "I’m going to reply. I just want it to feel right, not rushed.";
  }

  if (sun.element === "water") {
    return "Yes, but it will come through feeling first. They need to know the tone is safe.";
  }

  if (sun.element === "fire") {
    return "They’ll probably answer fast if the energy still feels bold and clean.";
  }

  return "They are likely to respond once the message feels grounded, intentional, and easy to trust.";
}

function renderPredictionPreview() {
  const sun = getSign(builderState.sun);
  const moon = getSign(builderState.moon);
  const rising = getSign(builderState.rising);
  const mode = companionModes.find((item) => item.id === builderState.mode);
  const tone = predictionTone(sun, mode.id);
  const confidence = Math.max(74, Math.min(94, 80 + (sun.element === moon.element ? 5 : 0) + (rising.element === sun.element ? 3 : 0)));

  predictSunChip.textContent = `Sun · ${sun.name}`;
  predictMoonChip.textContent = `Moon · ${moon.name}`;
  predictRisingChip.textContent = `Rising · ${rising.name}`;
  predictQuestion.textContent = mode.id === "bestie" ? "Are they actually upset or just busy?" : "Will they reply tonight?";
  predictResultMessage.textContent = predictedMessageFor(mode.id, sun, moon);
  predictTone.textContent = `Tone · ${tone}`;
  predictConfidence.textContent = `${confidence}% confidence`;
  predictResultBreakdown.textContent = `${sun.name} sets the tone, ${moon.name} explains the feeling underneath, and ${rising.name} shapes how the reply lands on the surface.`;
}

function renderAstropediaTopicPicker() {
  astropediaTopicPicker.innerHTML = astropediaTopics
    .map(
      (topic) => `
        <button class="mini-pill ${astropediaState.topic === topic.id ? "is-active" : ""}" type="button" data-topic="${topic.id}">
          ${topic.name}
        </button>
      `
    )
    .join("");

  astropediaTopicPicker.querySelectorAll("[data-topic]").forEach((button) => {
    button.addEventListener("click", () => {
      astropediaState.topic = button.dataset.topic;
      renderAstropediaTopicPicker();
      renderAstropediaArticle();
      renderAstropediaResults();
    });
  });
}

function renderAstropediaSignPicker() {
  astropediaSignPicker.innerHTML = signProfiles
    .map(
      (sign) => `
        <button class="sign-pill ${astropediaState.sign === sign.id ? "is-active" : ""}" type="button" data-sign="${sign.id}" style="--sign-accent:${sign.accent}">
          <span>${sign.glyph}</span>
          <strong>${sign.name}</strong>
        </button>
      `
    )
    .join("");

  astropediaSignPicker.querySelectorAll("[data-sign]").forEach((button) => {
    button.addEventListener("click", () => {
      astropediaState.sign = button.dataset.sign;
      renderAstropediaSignPicker();
      renderAstropediaArticle();
      renderAstropediaResults();
    });
  });
}

function articleFor(sign, topicId) {
  const topic = astropediaTopics.find((item) => item.id === topicId);

  switch (topicId) {
    case "communication":
      return {
        eyebrow: `${sign.name} · Communication guide`,
        title: `How to talk to ${sign.name}`,
        body: sign.communication
      };
    case "love":
      return {
        eyebrow: `${sign.name} · Love`,
        title: `${sign.name} in closeness`,
        body: sign.love
      };
    case "conflict":
      return {
        eyebrow: `${sign.name} · Conflict`,
        title: `${sign.name} when tension rises`,
        body: sign.conflict
      };
    case "emotional":
      return {
        eyebrow: `${sign.name} · Emotional needs`,
        title: `${sign.name} beneath the surface`,
        body: sign.emotional
      };
    default:
      return {
        eyebrow: `${sign.name} · Plain English`,
        title: `${sign.name}, in plain language`,
        body: sign.plainEnglish
      };
  }
}

function astropediaEntries() {
  return signProfiles.flatMap((sign) =>
    astropediaTopics.map((topic) => {
      const article = articleFor(sign, topic.id);
      return {
        sign,
        topic,
        article,
        searchText: `${sign.name} ${topic.name} ${article.title} ${article.body}`.toLowerCase()
      };
    })
  );
}

function renderAstropediaResults() {
  const entries = astropediaEntries();
  const query = astropediaState.search.trim().toLowerCase();

  const results = query
    ? entries.filter((entry) => entry.searchText.includes(query)).slice(0, 6)
    : entries
        .filter((entry) => entry.sign.id === astropediaState.sign || entry.topic.id === astropediaState.topic)
        .slice(0, 6);

  astropediaResults.innerHTML = results
    .map(
      (entry) => `
        <button class="astropedia-result" type="button" data-sign="${entry.sign.id}" data-topic="${entry.topic.id}">
          <span class="astropedia-result__meta">${entry.sign.name} · ${entry.topic.name}</span>
          <strong>${entry.article.title}</strong>
          <p>${entry.article.body}</p>
        </button>
      `
    )
    .join("");

  astropediaResults.querySelectorAll("[data-sign]").forEach((button) => {
    button.addEventListener("click", () => {
      astropediaState.sign = button.dataset.sign;
      astropediaState.topic = button.dataset.topic;
      renderAstropediaSignPicker();
      renderAstropediaTopicPicker();
      renderAstropediaArticle();
      renderAstropediaResults();
    });
  });
}

function renderAstropediaChartCards() {
  const cards = [
    {
      label: "Sun",
      sign: getSign(userState.sun),
      body: getSign(userState.sun).core
    },
    {
      label: "Moon",
      sign: getSign(userState.moon),
      body: getSign(userState.moon).emotional
    },
    {
      label: "Rising",
      sign: getSign(userState.rising),
      body: getSign(userState.rising).first
    }
  ];

  astropediaChartCards.innerHTML = cards
    .map(
      ({ label, sign, body }) => `
        <article class="chart-card" style="--card-accent:${sign.accent}">
          <span>${label} in ${sign.name}</span>
          <strong>${sign.glyph} ${sign.name}</strong>
          <p>${body}</p>
        </article>
      `
    )
    .join("");
}

function renderAstropediaArticle() {
  const sign = getSign(astropediaState.sign);
  const article = articleFor(sign, astropediaState.topic);

  astropediaArticleEyebrow.textContent = article.eyebrow;
  astropediaArticleTitle.textContent = article.title;
  astropediaArticleBody.textContent = article.body;

  const userSunSign = getSign(userState.sun);
  todayInsight.innerHTML = `
    <span class="today-insight__label">Today with ${userSunSign.name}</span>
    <strong>Use Astropedia as a live guide, not a static glossary.</strong>
    <p>${userSunSign.communication}</p>
  `;

  renderAstropediaChartCards();
}

function renderCompatibility() {
  const result = computeCompatibility();

  compatibilityRing.style.setProperty("--compatibility-progress", `${result.score * 3.6}deg`);
  compatibilityScore.textContent = `${result.score}%`;
  compatibilityHeadline.textContent = `${result.yours.sun.name} + ${result.theirs.sun.name} with real nuance`;
  compatibilitySummary.textContent = elementPairingText(result.yours.sun.element, result.theirs.sun.element);

  compatibilityRows.innerHTML = [
    {
      label: "Core identity",
      yours: result.yours.sun,
      theirs: result.theirs.sun,
      body: `${result.yours.sun.name} brings ${result.yours.sun.plainEnglish.toLowerCase()} ${result.theirs.sun.name} brings ${result.theirs.sun.plainEnglish.toLowerCase()}`
    },
    {
      label: "Emotional bond",
      yours: result.yours.moon,
      theirs: result.theirs.moon,
      body: `${result.yours.moon.emotional} ${result.theirs.moon.emotional}`
    },
    {
      label: "First impressions",
      yours: result.yours.rising,
      theirs: result.theirs.rising,
      body: `${result.yours.rising.first} ${result.theirs.rising.first}`
    }
  ]
    .map(
      (row) => `
        <article class="compatibility-row">
          <div class="compatibility-row__header">
            <span>${row.label}</span>
            <strong>${row.yours.name} · ${row.theirs.name}</strong>
          </div>
          <p>${row.body}</p>
        </article>
      `
    )
    .join("");

  compatibilityGrowth.innerHTML = `
    <span class="compatibility-growth__label">Growth edge</span>
    <p>${result.growth}</p>
  `;
}

function renderCompanionGrid() {
  companionGrid.innerHTML = signProfiles
    .map(
      (sign) => `
        <article class="companion-tile" style="--tile-accent:${sign.accent}">
          <span class="companion-tile__glyph">${sign.glyph}</span>
          <h3>${sign.name}</h3>
          <p>${sign.descriptor}</p>
          <span class="companion-tile__tag">${capitalize(sign.element)} sign</span>
        </article>
      `
    )
    .join("");
}

function bindHeroControls() {
  prevButton.addEventListener("click", () => {
    nextHero(-1);
    restartAutoplay();
  });

  nextButton.addEventListener("click", () => {
    nextHero(1);
    restartAutoplay();
  });

  hero.addEventListener("mouseenter", pauseAutoplay);
  hero.addEventListener("mouseleave", startAutoplay);

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      pauseAutoplay();
    } else {
      startAutoplay();
    }
  });
}

function bindHeroVisibility() {
  if (reduceMotion) return;

  let ticking = false;

  const syncHeroMotionState = () => {
    const rect = hero.getBoundingClientRect();
    const visibleHeight = Math.max(0, Math.min(rect.bottom, window.innerHeight) - Math.max(rect.top, 0));
    const visibilityRatio = visibleHeight / Math.max(rect.height, 1);
    heroInView = visibilityRatio >= 0.46;

    if (heroInView) {
      startAutoplay();
    } else {
      pauseAutoplay();
    }
  };

  const requestSync = () => {
    if (ticking) return;
    ticking = true;

    window.requestAnimationFrame(() => {
      ticking = false;
      syncHeroMotionState();
    });
  };

  window.addEventListener("scroll", requestSync, { passive: true });
  window.addEventListener("resize", requestSync);
  syncHeroMotionState();
}

function bindHeroResize() {
  let resizeFrame = null;

  window.addEventListener("resize", () => {
    if (resizeFrame) {
      window.cancelAnimationFrame(resizeFrame);
    }

    resizeFrame = window.requestAnimationFrame(() => {
      resizeFrame = null;
      const nextCompactLayout = window.innerWidth <= 760;

      if (nextCompactLayout === heroUsesCompactLayout) return;

      heroUsesCompactLayout = nextCompactLayout;
      updateHero({ immediate: true });
    });
  });
}

function bindParallax() {
  if (reduceMotion) return;

  hero.addEventListener("pointermove", (event) => {
    const rect = hero.getBoundingClientRect();
    const x = (event.clientX - rect.left) / rect.width - 0.5;
    const y = (event.clientY - rect.top) / rect.height - 0.5;
    hero.style.setProperty("--parallax-x", `${x * -10}px`);
    hero.style.setProperty("--parallax-y", `${y * -10}px`);
  });

  hero.addEventListener("pointerleave", () => {
    hero.style.setProperty("--parallax-x", "0px");
    hero.style.setProperty("--parallax-y", "0px");
  });
}

function bindSectionReveal() {
  const revealables = document.querySelectorAll(".section-reveal");
  if (reduceMotion) {
    revealables.forEach((node) => node.classList.add("is-visible"));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.2 }
  );

  revealables.forEach((node) => observer.observe(node));
}

function requestedSectionTarget() {
  const params = new URLSearchParams(window.location.search);
  const requestedSection = params.get("section");

  if (requestedSection) {
    return document.getElementById(requestedSection);
  }

  const hash = window.location.hash;
  if (!hash) return null;

  return document.querySelector(hash);
}

function revealHashTarget() {
  const target = requestedSectionTarget();
  if (!target) return;

  if (target.classList.contains("section-reveal")) {
    target.classList.add("is-visible");
  }
}

function scrollToSection(target, behavior = "smooth") {
  if (!target) return;

  const headerOffset = 112;
  const top = Math.max(0, target.getBoundingClientRect().top + window.scrollY - headerOffset);
  window.scrollTo({ top, behavior });

  if (target.classList.contains("section-reveal")) {
    target.classList.add("is-visible");
  }
}

function syncHashNavigation() {
  const target = requestedSectionTarget();
  if (!target) return;

  revealHashTarget();

  window.requestAnimationFrame(() => {
    window.requestAnimationFrame(() => {
      scrollToSection(target, "auto");
    });
  });
}

function bindAnchorLinks() {
  document.querySelectorAll('a[href^="#"]').forEach((link) => {
    link.addEventListener("click", (event) => {
      const hash = link.getAttribute("href");
      if (!hash || hash === "#") return;

      const target = document.querySelector(hash);
      if (!target) return;

      event.preventDefault();
      history.replaceState(null, "", hash);
      scrollToSection(target, reduceMotion ? "auto" : "smooth");
    });
  });

  window.addEventListener("hashchange", syncHashNavigation);
}

function bindBuilderInputs() {
  builderSun.addEventListener("change", (event) => {
    builderState.sun = event.target.value;
    renderBuilder();
  });

  builderMoon.addEventListener("change", (event) => {
    builderState.moon = event.target.value;
    renderBuilder();
  });

  builderRising.addEventListener("change", (event) => {
    builderState.rising = event.target.value;
    renderBuilder();
  });

  builderName.addEventListener("input", (event) => {
    builderState.name = event.target.value;
    renderBuilder();
  });

  userSun.addEventListener("change", (event) => {
    userState.sun = event.target.value;
    renderCompatibility();
    renderAstropediaChartCards();
    renderAstropediaArticle();
  });

  userMoon.addEventListener("change", (event) => {
    userState.moon = event.target.value;
    renderCompatibility();
    renderAstropediaChartCards();
    renderAstropediaArticle();
  });

  userRising.addEventListener("change", (event) => {
    userState.rising = event.target.value;
    renderCompatibility();
    renderAstropediaChartCards();
    renderAstropediaArticle();
  });

  astropediaSearch.addEventListener("input", (event) => {
    astropediaState.search = event.target.value;
    renderAstropediaResults();
  });
}

function initializeSelects() {
  populateSignSelect(builderSun, builderState.sun);
  populateSignSelect(builderMoon, builderState.moon);
  populateSignSelect(builderRising, builderState.rising);
  populateSignSelect(userSun, userState.sun);
  populateSignSelect(userMoon, userState.moon);
  populateSignSelect(userRising, userState.rising);
}

updateHero({ immediate: true });
initializeSelects();
renderModePicker();
renderEssencePicker();
renderBuilder();
renderAstropediaTopicPicker();
renderAstropediaSignPicker();
renderAstropediaArticle();
renderAstropediaResults();
renderCompanionGrid();
bindHeroControls();
bindHeroVisibility();
bindHeroResize();
bindParallax();
bindSectionReveal();
bindBuilderInputs();
bindAnchorLinks();
syncHashNavigation();
startAutoplay();
