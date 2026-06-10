import type { Companion } from "@/data/companions";
import {
  describeCompanionLens,
  describeMoon,
  describeRising,
  describeSun,
  getChartBasis,
  getSignMetadata,
  mockUserChart
} from "@/data/astrology";
import type { UserChartProfile } from "@/data/astrology";

export type RelationshipContext = {
  situation: string;
  message: string;
};

export type ChatFoundation = {
  firstResponse: string;
  whyThisReading: Array<{ label: string; body: string }>;
  notificationExamples: string[];
  promptTemplate: string;
  starterThread: ChatTurn[];
  quickPrompts: string[];
  memorySignals: string[];
  connectionCue: string;
};

export type ChatTurn = {
  id: string;
  author: "companion" | "user";
  body: string;
  timestamp: string;
  status?: "seen" | "delivered";
};

const defaultContext: RelationshipContext = {
  situation: mockUserChart.relationshipContext,
  message: mockUserChart.sampleMessage
};

function signPhrase(sign: string) {
  const meta = getSignMetadata(sign);
  return `${meta.sign} ${meta.element.toLowerCase()} ${meta.modality.toLowerCase()} lens`;
}

function signSpecificAdvice(sign: string) {
  const meta = getSignMetadata(sign);
  const adviceBySign: Record<string, string> = {
    Aries: "Do not dilute the want. Make the line clean, then let them meet your pace.",
    Taurus: "Trust what repeats. Warmth is real when it becomes behavior.",
    Gemini: "Answer the pivot, not the performance. Keep it light enough to keep moving.",
    Cancer: "Protect the soft part without making them guess what hurt.",
    Leo: "Let yourself be seen. One warm sentence can do more than five careful ones.",
    Virgo: "Edit the spiral down to the useful detail. The cleanest line is usually the kindest.",
    Libra: "Keep it beautiful, but do not trade truth for smoothness.",
    Scorpio: "Ask the direct question once. Then let the answer reveal its weight.",
    Sagittarius: "Leave the reply room to breathe. Honest does not need to be heavy.",
    Capricorn: "Measure effort across time. Chemistry is not a substitute for follow-through.",
    Aquarius: "Zoom out. The pattern matters more than the single notification.",
    Pisces: "The feeling is real. The story still needs evidence."
  };

  return adviceBySign[meta.sign] ?? "Start with the placement, then choose the cleanest next sentence.";
}

function signSpecificRead(sign: string) {
  const meta = getSignMetadata(sign);
  const readsBySign: Record<string, string> = {
    Aries: "the attraction is real only if it has momentum, not just heat",
    Taurus: "the body knows the difference between steady desire and intermittent attention",
    Gemini: "the wording is playful, but the pivot tells you where the truth is hiding",
    Cancer: "the tone matters because your nervous system is reading safety before logic",
    Leo: "the issue is not attention; it is whether they make you feel visibly chosen",
    Virgo: "the tiny inconsistency is not everything, but it is useful data",
    Libra: "the reply has to keep grace without making you disappear",
    Scorpio: "the unsaid part is carrying more weight than the sentence itself",
    Sagittarius: "space can be healthy, but avoidance likes to borrow the same outfit",
    Capricorn: "effort over time is the only evidence worth building around",
    Aquarius: "one message matters less than the pattern it belongs to",
    Pisces: "the feeling is honest, but the story needs evidence before it becomes truth"
  };

  return readsBySign[meta.sign] ?? "the pattern matters more than the mood";
}

function signSpecificReplyLine(sign: string) {
  const meta = getSignMetadata(sign);
  const repliesBySign: Record<string, string> = {
    Aries: "I like the energy here. Are we keeping the pace real?",
    Taurus: "I like hearing from you, but consistency is what makes this feel good.",
    Gemini: "Okay, I am curious. What did you mean by that part?",
    Cancer: "I liked the warmth between us. I just need the pace to feel emotionally clear.",
    Leo: "I like you, but I am not guessing whether I am being chosen.",
    Virgo: "I am open to this. I just want the energy to match the words.",
    Libra: "I like talking to you. I also want this to feel mutual, not carefully vague.",
    Scorpio: "I would rather ask directly than read between every line. What changed?",
    Sagittarius: "I like the spark. I just need it to have room and honesty.",
    Capricorn: "I am interested, but I pay attention to follow-through.",
    Aquarius: "I like this when it feels easy and real. What pace actually works for you?",
    Pisces: "I like the feeling here. I just need something real enough to trust."
  };

  return repliesBySign[meta.sign] ?? "I like this, but I need the energy to be clear.";
}

function signSpecificCharm(sign: string) {
  const meta = getSignMetadata(sign);
  const charmBySign: Record<string, string> = {
    Aries: "Attractive does not have to mean chaotic.",
    Taurus: "Good chemistry should make your body unclench.",
    Gemini: "A little tension is cute. A pattern of confusion is not.",
    Cancer: "Soft does not mean available for guessing games.",
    Leo: "You are allowed to want the warm, obvious version.",
    Virgo: "The right person does not make clarity feel embarrassing.",
    Libra: "Keep the elegance. Lose the self-erasure.",
    Scorpio: "Intensity is only useful when it comes with truth.",
    Sagittarius: "You can be light and still have standards.",
    Capricorn: "Desire is better when it can keep an appointment.",
    Aquarius: "Distance is only sexy when it is chosen, not dodged.",
    Pisces: "Romance needs a floor, not just a feeling."
  };

  return charmBySign[meta.sign] ?? "Keep it warm, specific, and self-respecting.";
}

function companionFlirt(companion: Companion) {
  const byElement: Record<string, string> = {
    Fire: "I like the spark here, but I am not letting you chase smoke.",
    Earth: "There is chemistry, yes. Now we make it prove itself.",
    Air: "This is fun, but the wording is doing more work than it wants to admit.",
    Water: "The feeling is loud. I want the truth underneath it."
  };

  return byElement[getSignMetadata(companion.sign).element] ?? companion.opener;
}

function buildStarterThread(companion: Companion, profile: UserChartProfile): ChatTurn[] {
  const companionMeta = getSignMetadata(companion.sign);

  return [
    {
      id: "starter-1",
      author: "companion",
      timestamp: "9:41",
      body: `${companion.opener} ${companionFlirt(companion)} ${signSpecificCharm(companion.sign)}`
    },
    {
      id: "starter-2",
      author: "companion",
      timestamp: "9:42",
      body: `Send me the text or situation. I will read it through your ${profile.moon} Moon, your ${profile.rising} Rising, and my ${companion.sign} lens: ${companionMeta.communicationStyle}.`
    }
  ];
}

function buildQuickPrompts(companion: Companion) {
  return [
    "Decode this text",
    "What are they feeling?",
    companion.sign === "Sagittarius" ? "Make it honest but light" : "Write my reply",
    companion.sign === "Scorpio" ? "What are they hiding?" : "Should I wait?"
  ];
}

function buildMemorySignals(companion: Companion, profile: UserChartProfile) {
  return [
    `${profile.moon} Moon: silence can feel personal before it is factual`,
    `${profile.rising} Rising: tone and elegance matter when you answer`,
    `${companion.displayName}: ${companion.identity.chatVoice}`
  ];
}

export function buildAstrologyGroundedResponse(
  companion: Companion,
  profile: UserChartProfile = mockUserChart,
  context: RelationshipContext = defaultContext
) {
  const companionMeta = getSignMetadata(companion.sign);

  return `I’m reading this through my ${signPhrase(companion.sign)}: ${companionMeta.communicationStyle}. Your ${profile.moon} Moon may take silence personally, while your ${profile.rising} Rising wants the reply to land gracefully. ${signSpecificAdvice(companion.sign)}`;
}

export function buildCompanionReply(
  companion: Companion,
  userMessage: string,
  profile: UserChartProfile = mockUserChart
) {
  return buildCompanionReplyParts(companion, userMessage, profile).join(" ");
}

export function buildCompanionReplyParts(
  companion: Companion,
  userMessage: string,
  profile: UserChartProfile = mockUserChart
) {
  const cleanMessage = userMessage.replace(/\s+/g, " ").trim();
  const moonMeta = getSignMetadata(profile.moon);
  const isWaiting = /\b(wait|silent|silence|quiet|slow|left on read|no reply|ghost)\b/i.test(cleanMessage);
  const contextLead = isWaiting
    ? "Do not answer the silence like it is already a verdict."
    : cleanMessage
      ? "I would read the emotional weather before the literal words."
      : "Start with the emotional weather before the literal words.";

  return [
    contextLead,
    `Your ${profile.moon} Moon ${moonMeta.emotionalPattern}. Your ${profile.rising} Rising wants grace without self-erasure.`,
    `My ${companion.sign} lens says ${signSpecificRead(companion.sign)}.`,
    `${signSpecificAdvice(companion.sign)} ${signSpecificCharm(companion.sign)}`,
    `Try: "${signSpecificReplyLine(companion.sign)}"`
  ];
}

export function buildNotificationExamples(companion: Companion, profile: UserChartProfile = mockUserChart) {
  const companionMeta = getSignMetadata(companion.sign);
  const moonMeta = getSignMetadata(profile.moon);

  return [
    `Your ${profile.moon} Moon might read silence as rejection today. Wait before you answer.`,
    `${companion.displayName}'s ${companion.sign} lens says ${companionMeta.relationshipShadow}. Check the pattern before you chase the mood.`,
    `Your ${profile.rising} Rising is tracking tone. Keep the reply graceful, but do not hide the need.`
  ].map((copy) => copy.replace(/\s+/g, " ").trim());
}

export function buildCompanionPromptTemplate(
  companion: Companion,
  profile: UserChartProfile = mockUserChart,
  context: RelationshipContext = defaultContext
) {
  const companionMeta = getSignMetadata(companion.sign);

  return [
    "You are a Simastry companion. Give conversation-first astrology guidance, not a generic horoscope.",
    "",
    `Companion: ${companion.displayName}, ${companion.sign}.`,
    `Companion identity: ${companion.identity.personality}`,
    `Companion voice: ${companion.identity.chatVoice}`,
    `Companion sign lens: ${describeCompanionLens(companion.sign)}`,
    "",
    "User chart:",
    `- ${describeSun(profile.sun)}`,
    `- ${describeMoon(profile.moon)}`,
    `- ${describeRising(profile.rising)}`,
    "",
    "Relationship context:",
    `- Situation: ${context.situation}`,
    `- Message/context being interpreted: ${context.message}`,
    "",
    "Astrology rules:",
    `- Use ${profile.sun} Sun for core identity and direction.`,
    `- Use ${profile.moon} Moon for emotional needs, reactions, and safety cues.`,
    `- Use ${profile.rising} Rising for presentation, first instinct, and social tone.`,
    `- Use ${companion.sign} as the interpretive lens and conversation style.`,
    `- Include sign element (${companionMeta.element}), modality (${companionMeta.modality}), and ruler (${companionMeta.rulingPlanet}) only when useful.`,
    "- Do not invent chart placements or transits that were not provided.",
    "- Do not use random horoscope output.",
    "",
    "Privacy and safety rules:",
    "- Do not expose private conversation content in notification previews.",
    "- Do not name the other person unless the user provided that name in the current chat.",
    "- Keep advice practical, specific, and emotionally grounded.",
    "- If the message suggests risk, manipulation, or distress, recommend a safer slower response.",
    "",
    "Output style:",
    "- Short paragraphs.",
    "- Specific, premium, calm.",
    "- Explain the astrology basis briefly when helpful."
  ].join("\n");
}

export function buildChatFoundation(
  companion: Companion,
  profile: UserChartProfile = mockUserChart,
  context: RelationshipContext = defaultContext
): ChatFoundation {
  return {
    firstResponse: buildAstrologyGroundedResponse(companion, profile, context),
    whyThisReading: getChartBasis(profile, companion.sign),
    notificationExamples: buildNotificationExamples(companion, profile),
    promptTemplate: buildCompanionPromptTemplate(companion, profile, context),
    starterThread: buildStarterThread(companion, profile),
    quickPrompts: buildQuickPrompts(companion),
    memorySignals: buildMemorySignals(companion, profile),
    connectionCue: `${companion.sign} ${getSignMetadata(companion.sign).rulingPlanet} lens • ${companion.identity.personality}`
  };
}

export { mockUserChart };
