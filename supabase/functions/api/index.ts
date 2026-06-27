import "jsr:@supabase/functions-js/edge-runtime.d.ts";

type PredictionRequest = {
  mode?: string;
  tier?: string;
  systemPrompt?: string;
  userPrompt?: string;
};

type SignProfile = {
  sign: string;
  tone: "playful" | "guarded" | "warm" | "cold" | "anxious" | "confident" | "flirty" | "distant";
  cadence: string;
  messageVariants: string[];
  breakdown: string;
};

const jsonHeaders = {
  "Content-Type": "application/json",
  "Connection": "keep-alive",
};

const signProfiles: Record<string, SignProfile> = {
  aries: {
    sign: "Aries",
    tone: "confident",
    cadence: "direct and immediate",
    messageVariants: [
      "Yeah, I want to see where this goes. When are you free?",
      "I am into this. Let's not overthink it.",
      "Okay, that got my attention. Tell me more.",
    ],
    breakdown: "Aries energy tends to answer quickly when interest is sparked, with less hedging and more forward motion.",
  },
  taurus: {
    sign: "Taurus",
    tone: "warm",
    cadence: "steady and grounded",
    messageVariants: [
      "I like hearing from you. I just need things to feel easy and real.",
      "That actually sounds nice. Let's keep it simple.",
      "I am here, just moving at my own pace.",
    ],
    breakdown: "Taurus placements usually respond best to consistency, comfort, and a tone that feels stable rather than pressured.",
  },
  gemini: {
    sign: "Gemini",
    tone: "playful",
    cadence: "curious and quick",
    messageVariants: [
      "Wait, that is interesting. Explain your logic.",
      "Okay, now I have questions.",
      "You cannot just say that and disappear.",
    ],
    breakdown: "Gemini energy tends to keep the thread alive through curiosity, questions, and playful changes in direction.",
  },
  cancer: {
    sign: "Cancer",
    tone: "warm",
    cadence: "emotionally careful",
    messageVariants: [
      "I care, I just did not know how to say it without making it bigger.",
      "That means more to me than I probably showed.",
      "I was quiet because I needed a second, not because I do not care.",
    ],
    breakdown: "Cancer placements often protect their feelings first, then answer with warmth once the emotional temperature feels safe.",
  },
  leo: {
    sign: "Leo",
    tone: "flirty",
    cadence: "expressive and proud",
    messageVariants: [
      "I mean, you do know how to get my attention.",
      "That was cute. I will give you that.",
      "You are making it hard for me to pretend I am not smiling.",
    ],
    breakdown: "Leo energy responds to warmth, recognition, and a little drama, especially when the exchange lets them feel chosen.",
  },
  virgo: {
    sign: "Virgo",
    tone: "guarded",
    cadence: "precise and observant",
    messageVariants: [
      "I get what you mean. I just want to be clear about what we are doing.",
      "That makes sense. I need a little time to think it through.",
      "I noticed that too, I just was not sure if I should bring it up.",
    ],
    breakdown: "Virgo placements usually process the details before reacting, so their reply may be careful but still engaged.",
  },
  libra: {
    sign: "Libra",
    tone: "flirty",
    cadence: "balanced and charming",
    messageVariants: [
      "That is kind of sweet. I am not mad at it.",
      "I like where this conversation is going.",
      "You make it very easy to keep replying.",
    ],
    breakdown: "Libra energy tends to mirror tone and keep the exchange graceful, especially when there is room for charm.",
  },
  scorpio: {
    sign: "Scorpio",
    tone: "guarded",
    cadence: "intense and selective",
    messageVariants: [
      "I saw this. I just wanted to know if you meant it.",
      "I am not ignoring you. I am deciding how honest to be.",
      "That hit closer than I expected.",
    ],
    breakdown: "Scorpio placements usually read beneath the words first, then answer when the emotional signal feels real.",
  },
  sagittarius: {
    sign: "Sagittarius",
    tone: "playful",
    cadence: "open and blunt",
    messageVariants: [
      "Honestly, yes. That sounds fun.",
      "You are overthinking this. I am in.",
      "Okay, plot twist. I like it.",
    ],
    breakdown: "Sagittarius energy favors honesty and momentum, so the reply usually gets lighter when the conversation feels open.",
  },
  capricorn: {
    sign: "Capricorn",
    tone: "guarded",
    cadence: "contained and intentional",
    messageVariants: [
      "I do want to talk. I just take this kind of thing seriously.",
      "That is fair. Let me think before I answer badly.",
      "I am not casual about this, even if I sound calm.",
    ],
    breakdown: "Capricorn placements often keep control of tone, but a measured reply can still signal meaningful investment.",
  },
  aquarius: {
    sign: "Aquarius",
    tone: "distant",
    cadence: "detached but interested",
    messageVariants: [
      "That is a surprisingly good question.",
      "I had not thought about it like that.",
      "You are making me rethink my answer.",
    ],
    breakdown: "Aquarius energy often responds through ideas before emotion, so interest may show up as curiosity rather than softness.",
  },
  pisces: {
    sign: "Pisces",
    tone: "warm",
    cadence: "soft and intuitive",
    messageVariants: [
      "I felt that too, I just did not know if you did.",
      "This is softer than I expected, in a good way.",
      "I think I understand what you mean.",
    ],
    breakdown: "Pisces placements tend to answer from feeling and atmosphere, especially when the message gives them emotional room.",
  },
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: jsonHeaders,
    });
  }

  const url = new URL(req.url);
  if (!url.pathname.endsWith("/simulate/predict")) {
    return json({ error: { message: "Not found" } }, 404);
  }

  if (req.method !== "POST") {
    return json({ error: { message: "Method not allowed" } }, 405);
  }

  let payload: PredictionRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: { message: "Invalid JSON body" } }, 400);
  }

  const systemPrompt = cleanText(payload.systemPrompt);
  const userPrompt = cleanText(payload.userPrompt);
  if (!systemPrompt || !userPrompt) {
    return json({ error: { message: "Prediction prompt is required" } }, 400);
  }

  const sunSign = extractPlacement(systemPrompt, "Sun") ?? "Libra";
  const moonSign = extractPlacement(systemPrompt, "Moon");
  const risingSign = extractPlacement(systemPrompt, "Rising");
  const profile = signProfiles[sunSign.toLowerCase()] ?? signProfiles.libra;
  const conversation = extractSection(userPrompt, "Conversation") || userPrompt;
  const question = extractSection(userPrompt, "What the user wants to know");
  const alternativeReply = extractSection(userPrompt, "Alternative reply the user is considering sending");

  const seed = hashString(`${systemPrompt}\n${userPrompt}`);
  const predictedMessage = buildPredictedMessage(profile, conversation, question, alternativeReply, seed);
  const confidence = buildConfidence(conversation, question, alternativeReply, seed);
  const astrologicalBreakdown = buildBreakdown(profile, moonSign, risingSign, question, alternativeReply);

  return json({
    predicted_message: predictedMessage,
    astrological_breakdown: astrologicalBreakdown,
    confidence,
    tone: profile.tone,
  });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function cleanText(value: unknown): string {
  return typeof value === "string" ? value.trim().slice(0, 12000) : "";
}

function extractPlacement(prompt: string, placement: "Sun" | "Moon" | "Rising"): string | null {
  const match = prompt.match(new RegExp(`${placement} in ([A-Za-z]+)`, "i"));
  if (!match?.[1]) return null;
  return titleCase(match[1]);
}

function extractSection(prompt: string, label: string): string {
  const marker = `${label}:`;
  const start = prompt.indexOf(marker);
  if (start === -1) return "";

  const rest = prompt.slice(start + marker.length).trim();
  const nextSection = rest.search(/\n\n[A-Z][^:\n]{2,90}:\n/);
  return (nextSection === -1 ? rest : rest.slice(0, nextSection)).trim().slice(0, 4000);
}

function buildPredictedMessage(
  profile: SignProfile,
  conversation: string,
  question: string,
  alternativeReply: string,
  seed: number,
): string {
  const lower = `${conversation}\n${question}\n${alternativeReply}`.toLowerCase();
  const variant = profile.messageVariants[seed % profile.messageVariants.length];

  if (alternativeReply) {
    if (lower.includes("sorry") || lower.includes("apolog")) {
      return "I appreciate you saying that. I just needed it to feel honest.";
    }
    return variant;
  }

  if (lower.includes("double text") || lower.includes("reply") || lower.includes("respond")) {
    return profile.tone === "distant" || profile.tone === "guarded"
      ? "I saw your message. I just needed a minute before answering."
      : variant;
  }

  if (lower.includes("interested") || lower.includes("like me") || lower.includes("feel")) {
    return profile.tone === "flirty" || profile.tone === "warm"
      ? "I do like talking to you. I think you know that."
      : variant;
  }

  return variant;
}

function buildConfidence(conversation: string, question: string, alternativeReply: string, seed: number): number {
  const lengthScore = Math.min(16, Math.floor(conversation.length / 180));
  const contextScore = question ? 5 : 0;
  const alternativeScore = alternativeReply ? 4 : 0;
  return Math.max(54, Math.min(87, 58 + lengthScore + contextScore + alternativeScore + (seed % 7)));
}

function buildBreakdown(
  profile: SignProfile,
  moonSign: string | null,
  risingSign: string | null,
  question: string,
  alternativeReply: string,
): string {
  const placements = [
    `${profile.sign} Sun gives the reply a ${profile.cadence} rhythm`,
    moonSign ? `${moonSign} Moon colors the emotional subtext` : null,
    risingSign ? `${risingSign} Rising shapes how direct the message feels` : null,
  ].filter(Boolean).join(". ");

  const context = alternativeReply
    ? "Because you are testing an alternate message, the response leans toward their reaction to your next move."
    : question
      ? "The question points the read toward intent, timing, and emotional availability."
      : "The read focuses on the next likely beat in the thread.";

  return `${placements}. ${profile.breakdown} ${context}`;
}

function hashString(value: string): number {
  let hash = 0;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) - hash + value.charCodeAt(index)) | 0;
  }
  return Math.abs(hash);
}

function titleCase(value: string): string {
  const lower = value.toLowerCase();
  return lower.charAt(0).toUpperCase() + lower.slice(1);
}
