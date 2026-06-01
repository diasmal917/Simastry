export type ZodiacSign =
  | "Aries"
  | "Taurus"
  | "Gemini"
  | "Cancer"
  | "Leo"
  | "Virgo"
  | "Libra"
  | "Scorpio"
  | "Sagittarius"
  | "Capricorn"
  | "Aquarius"
  | "Pisces";

export type Element = "Fire" | "Earth" | "Air" | "Water";
export type Modality = "Cardinal" | "Fixed" | "Mutable";
export type Polarity = "Yang" | "Yin";

export type SignMetadata = {
  sign: ZodiacSign;
  element: Element;
  modality: Modality;
  rulingPlanet: string;
  polarity: Polarity;
  coreDrive: string;
  emotionalPattern: string;
  communicationStyle: string;
  relationshipShadow: string;
};

export type UserChartProfile = {
  sun: ZodiacSign;
  moon: ZodiacSign;
  rising: ZodiacSign;
  relationshipContext: string;
  sampleMessage: string;
};

export const signMetadata: Record<ZodiacSign, SignMetadata> = {
  Aries: {
    sign: "Aries",
    element: "Fire",
    modality: "Cardinal",
    rulingPlanet: "Mars",
    polarity: "Yang",
    coreDrive: "act directly and test chemistry through momentum",
    emotionalPattern: "reacts fast when desire or pride is activated",
    communicationStyle: "plain, bold, and impatient with vague signals",
    relationshipShadow: "can chase heat before checking whether the effort is mutual"
  },
  Taurus: {
    sign: "Taurus",
    element: "Earth",
    modality: "Fixed",
    rulingPlanet: "Venus",
    polarity: "Yin",
    coreDrive: "build trust through consistency, comfort, and embodied proof",
    emotionalPattern: "settles slowly and resists being rushed out of safety",
    communicationStyle: "steady, sensual, practical, and allergic to empty promises",
    relationshipShadow: "can confuse patience with waiting too long for proof"
  },
  Gemini: {
    sign: "Gemini",
    element: "Air",
    modality: "Mutable",
    rulingPlanet: "Mercury",
    polarity: "Yang",
    coreDrive: "follow curiosity and read the second meaning in a thread",
    emotionalPattern: "processes feeling through language, jokes, and pivots",
    communicationStyle: "quick, playful, observant, and sensitive to word choice",
    relationshipShadow: "can keep options open so long that clarity gets delayed"
  },
  Cancer: {
    sign: "Cancer",
    element: "Water",
    modality: "Cardinal",
    rulingPlanet: "Moon",
    polarity: "Yin",
    coreDrive: "protect emotional safety and recognize the need beneath reaction",
    emotionalPattern: "absorbs tone personally when attachment feels uncertain",
    communicationStyle: "tender, careful, memory-rich, and protective",
    relationshipShadow: "can retreat or test for care instead of asking directly"
  },
  Leo: {
    sign: "Leo",
    element: "Fire",
    modality: "Fixed",
    rulingPlanet: "Sun",
    polarity: "Yang",
    coreDrive: "be seen, chosen, and met with visible warmth",
    emotionalPattern: "opens with praise and closes when pride is bruised",
    communicationStyle: "warm, expressive, affirming, and high-presence",
    relationshipShadow: "can perform for attention instead of asking for devotion"
  },
  Virgo: {
    sign: "Virgo",
    element: "Earth",
    modality: "Mutable",
    rulingPlanet: "Mercury",
    polarity: "Yin",
    coreDrive: "make the signal useful, precise, and repairable",
    emotionalPattern: "sorts anxiety by looking for details and inconsistencies",
    communicationStyle: "specific, practical, edited, and quietly caring",
    relationshipShadow: "can over-analyze details when reassurance is needed"
  },
  Libra: {
    sign: "Libra",
    element: "Air",
    modality: "Cardinal",
    rulingPlanet: "Venus",
    polarity: "Yang",
    coreDrive: "create balance, mutuality, beauty, and social ease",
    emotionalPattern: "tracks fairness and tone before naming a need",
    communicationStyle: "graceful, diplomatic, charming, and careful with friction",
    relationshipShadow: "can preserve peace so well that the truth gets softened"
  },
  Scorpio: {
    sign: "Scorpio",
    element: "Water",
    modality: "Fixed",
    rulingPlanet: "Mars / Pluto",
    polarity: "Yin",
    coreDrive: "discover motive, trust, desire, and what is being withheld",
    emotionalPattern: "intensifies around ambiguity, loyalty, and power",
    communicationStyle: "private, piercing, spare, and emotionally strategic",
    relationshipShadow: "can test for truth instead of asking for it cleanly"
  },
  Sagittarius: {
    sign: "Sagittarius",
    element: "Fire",
    modality: "Mutable",
    rulingPlanet: "Jupiter",
    polarity: "Yang",
    coreDrive: "seek truth, movement, humor, and room to breathe",
    emotionalPattern: "needs distance and honesty when the mood gets cramped",
    communicationStyle: "candid, playful, spacious, and allergic to over-control",
    relationshipShadow: "can call avoidance freedom when the feeling gets heavy"
  },
  Capricorn: {
    sign: "Capricorn",
    element: "Earth",
    modality: "Cardinal",
    rulingPlanet: "Saturn",
    polarity: "Yin",
    coreDrive: "make effort real, repeatable, bounded, and worth time",
    emotionalPattern: "trusts behavior across time more than emotional intensity",
    communicationStyle: "measured, accountable, dry, and practical",
    relationshipShadow: "can treat vulnerability like a liability until safety is earned"
  },
  Aquarius: {
    sign: "Aquarius",
    element: "Air",
    modality: "Fixed",
    rulingPlanet: "Saturn / Uranus",
    polarity: "Yang",
    coreDrive: "see the system, the pattern, and the future fit",
    emotionalPattern: "steps back from intensity to regain perspective",
    communicationStyle: "detached, original, strategic, and humane",
    relationshipShadow: "can intellectualize distance instead of naming attachment"
  },
  Pisces: {
    sign: "Pisces",
    element: "Water",
    modality: "Mutable",
    rulingPlanet: "Jupiter / Neptune",
    polarity: "Yin",
    coreDrive: "feel the emotional weather and protect compassion without losing truth",
    emotionalPattern: "absorbs mood, longing, and projection before facts settle",
    communicationStyle: "soft, intuitive, imagistic, and clarifying when grounded",
    relationshipShadow: "can romanticize ambiguity until the evidence disappears"
  }
};

export const mockUserChart: UserChartProfile = {
  sun: "Sagittarius",
  moon: "Cancer",
  rising: "Libra",
  relationshipContext: "The user is deciding how to answer a slow or emotionally ambiguous message.",
  sampleMessage: "They have gone quiet after a warm exchange, and the user wants to answer without overreaching."
};

export function getSignMetadata(sign: string): SignMetadata {
  return signMetadata[sign as ZodiacSign] ?? signMetadata.Sagittarius;
}

export function describeSun(sign: ZodiacSign) {
  const meta = getSignMetadata(sign);
  return `Your ${sign} Sun describes core drive: ${meta.coreDrive}.`;
}

export function describeMoon(sign: ZodiacSign) {
  const meta = getSignMetadata(sign);
  return `Your ${sign} Moon describes emotional needs and reactions: ${meta.emotionalPattern}.`;
}

export function describeRising(sign: ZodiacSign) {
  const meta = getSignMetadata(sign);
  return `Your ${sign} Rising describes presentation and first instinct: ${meta.communicationStyle}.`;
}

export function describeCompanionLens(sign: string) {
  const meta = getSignMetadata(sign);
  return `${meta.sign} lens: ${meta.communicationStyle}; it reads the shadow as ${meta.relationshipShadow}.`;
}

export function getChartBasis(profile: UserChartProfile, companionSign: string) {
  const companion = getSignMetadata(companionSign);
  return [
    {
      label: `Your ${profile.sun} Sun`,
      body: getSignMetadata(profile.sun).coreDrive
    },
    {
      label: `Your ${profile.moon} Moon`,
      body: getSignMetadata(profile.moon).emotionalPattern
    },
    {
      label: `Your ${profile.rising} Rising`,
      body: getSignMetadata(profile.rising).communicationStyle
    },
    {
      label: `${companion.sign} lens`,
      body: `${companion.communicationStyle}; ${companion.element.toLowerCase()} ${companion.modality.toLowerCase()}, ruled by ${companion.rulingPlanet}`
    }
  ];
}
