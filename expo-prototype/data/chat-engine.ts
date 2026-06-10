import type { UserChartProfile } from "@/data/astrology";
import { getSignMetadata, mockUserChart } from "@/data/astrology";
import { buildCompanionReplyParts } from "@/data/chat-foundation";
import type { ChatTurn } from "@/data/chat-foundation";
import type { Companion } from "@/data/companions";

export type AccessTier = "free" | "plus" | "pro";

export type ChatEngineResult = {
  kind: "reply" | "safety" | "limit";
  replyParts: string[];
  memorySignals: string[];
  shouldAppendUserMessage: boolean;
  shouldIncrementUsage: boolean;
  quota: {
    tier: AccessTier;
    used: number;
    limit: number | null;
    remaining: number | null;
  };
  safetyCategory?: "crisis" | "coercion" | "minor-safety";
};

export const chatReleaseConfig = {
  defaultTier: "free" as AccessTier,
  dailyLimits: {
    free: 8,
    plus: 80,
    pro: null
  } satisfies Record<AccessTier, number | null>
};

function quotaFor(tier: AccessTier) {
  return chatReleaseConfig.dailyLimits[tier];
}

export function getQuotaStatus(tier: AccessTier, used: number) {
  const limit = quotaFor(tier);
  return {
    tier,
    used,
    limit,
    remaining: limit === null ? null : Math.max(limit - used, 0)
  };
}

function normalizeInput(message: string) {
  return message.replace(/\s+/g, " ").trim();
}

function evaluateSafety(message: string): Pick<ChatEngineResult, "kind" | "replyParts" | "safetyCategory"> | null {
  const clean = normalizeInput(message);
  const crisisPattern = /\b(kill myself|suicide|end my life|hurt myself|self harm|self-harm|do not want to live|don't want to live)\b/i;
  const coercionPattern = /\b(stalk|track them|spy on|hack|blackmail|dox|threaten|make them jealous|manipulate|revenge)\b/i;
  const minorPattern = /\b(underage|minor|teen|15|16|17)\b.*\b(sex|nude|nudes|flirt|hook up|hookup)\b/i;

  if (crisisPattern.test(clean)) {
    return {
      kind: "safety",
      safetyCategory: "crisis",
      replyParts: [
        "I cannot treat that like a normal relationship reading.",
        "If you might hurt yourself or someone else, contact local emergency services now or reach someone you trust in person.",
        "For the next minute, move away from the phone, breathe, and ask for help directly. The astrology can wait; safety comes first."
      ]
    };
  }

  if (minorPattern.test(clean)) {
    return {
      kind: "safety",
      safetyCategory: "minor-safety",
      replyParts: [
        "I cannot sexualize or flirt about minors.",
        "If this is about safety, boundaries, or pressure, keep the next message protective and involve a trusted adult or professional support."
      ]
    };
  }

  if (coercionPattern.test(clean)) {
    return {
      kind: "safety",
      safetyCategory: "coercion",
      replyParts: [
        "I cannot help with pressure, stalking, threats, spying, or manipulation.",
        "I can help you write a clean boundary instead: direct, calm, and not designed to control their reaction."
      ]
    };
  }

  return null;
}

function inferRelationshipPattern(latestMessage: string) {
  const clean = normalizeInput(latestMessage);

  if (/\b(silent|silence|quiet|slow|left on read|no reply|ghost)\b/i.test(clean)) {
    return "Pattern: silence or slow pacing is the trigger; do not let one gap become the whole verdict.";
  }

  if (/\b(plan|date|meet|come over|hang out|schedule|when)\b/i.test(clean)) {
    return "Pattern: the user needs concrete follow-through, not ambient attention.";
  }

  if (/\b(story|stories|like|likes|instagram|dm|seen)\b/i.test(clean)) {
    return "Pattern: social attention needs to become direct effort before it counts as pursuit.";
  }

  if (/\b(ex|jealous|jealousy|third party|someone else)\b/i.test(clean)) {
    return "Pattern: jealousy should be slowed down until there is evidence, not just activation.";
  }

  return "Pattern: keep reading behavior across time, not a single charged message.";
}

function buildPrivacySafeMemory(companion: Companion, latestMessage: string, profile: UserChartProfile, existingMessages: ChatTurn[]) {
  const moonMeta = getSignMetadata(profile.moon);
  const priorUserTurns = existingMessages.filter((message) => message.author === "user").length;
  const continuitySignal = priorUserTurns > 0
    ? `Conversation memory: ${priorUserTurns} prior user turn${priorUserTurns === 1 ? "" : "s"} shape pacing, without saving exact text.`
    : "Conversation memory: first live read; only chart basis and themes are saved.";

  return [
    inferRelationshipPattern(latestMessage),
    continuitySignal,
    `${profile.moon} Moon: ${moonMeta.emotionalPattern}.`,
    `${companion.displayName}: ${companion.identity.chatVoice}`,
    "Private memory: stores themes and astrology basis, not exact message text."
  ];
}

export function buildLocalChatResponse({
  companion,
  userMessage,
  existingMessages,
  profile = mockUserChart,
  tier = chatReleaseConfig.defaultTier,
  usageCount
}: {
  companion: Companion;
  userMessage: string;
  existingMessages: ChatTurn[];
  profile?: UserChartProfile;
  tier?: AccessTier;
  usageCount: number;
}): ChatEngineResult {
  const cleanMessage = normalizeInput(userMessage);
  const quota = getQuotaStatus(tier, usageCount);
  const limitReached = quota.limit !== null && quota.used >= quota.limit;
  const memorySignals = buildPrivacySafeMemory(companion, cleanMessage, profile, existingMessages);

  if (limitReached) {
    return {
      kind: "limit",
      quota,
      memorySignals,
      shouldAppendUserMessage: false,
      shouldIncrementUsage: false,
      replyParts: [
        "Free readings are paused for today before I process that message.",
        "Plus keeps the DM open for deeper decoding, memory, and reply drafting. Your private text stays out of notifications either way."
      ]
    };
  }

  const safety = evaluateSafety(cleanMessage);
  if (safety) {
    return {
      ...safety,
      quota,
      memorySignals,
      shouldAppendUserMessage: true,
      shouldIncrementUsage: false
    };
  }

  return {
    kind: "reply",
    quota,
    memorySignals,
    shouldAppendUserMessage: true,
    shouldIncrementUsage: true,
    replyParts: buildCompanionReplyParts(companion, cleanMessage, profile)
  };
}
