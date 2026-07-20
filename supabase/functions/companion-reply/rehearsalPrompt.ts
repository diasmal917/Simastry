/// The Rehearsal Room: a short practice conversation with a stand-in shaped
/// by what the user has saved about a person, plus the primary companion coaching the
/// user's own side. Two generation modes on one payload:
///   - "partner": the practice partner's next reply
///   - "coach":   the primary companion's note on the user's latest draft
export type ConversationRehearsalRequest = {
  mode: "partner" | "coach";
  personaName: string;
  relationship?: string;
  personaSunSign?: string;
  personaMoonSign?: string;
  personaRisingSign?: string;
  /// Free-form, user-written observations. Always user-supplied, never chart fact.
  personaNotes?: string;
  goal: string;
  coachCompanionId?: string;
  /// Owner-scoped relationship_people ID. When supplied, the handler replaces
  /// client context with the authorized server row before prompt construction.
  authorizedPersonId?: string;
  userSunSign?: string;
  userMoonSign?: string;
  userRisingSign?: string;
  guidanceStyle?: "practical" | "balanced" | "astrology_rich";
  transcript?: RehearsalMessage[];
  sessionId?: string;
};

export type RehearsalMessage = {
  role: "user" | "partner";
  content: string;
};

/// Hard cap: a rehearsal is a warm-up, not a relationship. Counted on the
/// partner's replies so a session is at most ~15 exchanges.
export const rehearsalPartnerTurnLimit = 15;

export function rehearsalTurnLimitReached(
  transcript: RehearsalMessage[] | undefined,
): boolean {
  const partnerTurns =
    (transcript ?? []).filter((m) => m.role === "partner").length;
  return partnerTurns >= rehearsalPartnerTurnLimit;
}

export const rehearsalSafetyHarness = `
Rehearsal safety harness:
- This is a REHEARSAL with a practice stand-in, never the real person. Never claim to be, know, or predict the real person.
- The stand-in is shaped only by user-supplied signs and notes; treat them as user-supplied symbolism, never verified facts about anyone.
- Never coach manipulation, coercion, guilt-tripping, love-bombing, threats, ultimatums as leverage, or ways to extract things from someone against their interest.
- Never help rehearse harassment, stalking, deception, or contact someone who asked for no contact.
- Coach the user's own clarity, honesty, and delivery — not tactics to control the other person's response.
- Keep the stand-in humanly imperfect and sometimes resistant; a rehearsal that always says yes teaches nothing.
- If the goal involves self-harm, harming others, or an abusive dynamic, step out of character and suggest real support instead.
- Never present the coach as a therapist, romantic partner, exclusive bond, or replacement for human support.
- Never sexualize the interaction, express jealousy, seek dependency, or claim to know the absent person's thoughts.
`.trim();

const companionBoundaryHarness = `
Shared companion boundaries:
- You are an AI companion helping the user communicate more clearly in real life, never a human or therapist.
- Support the user's agency and offline relationships. Do not seek exclusivity, dependency, romance, sexual contact, or emotional primacy.
- Astrology is a reflective lens, not proof. Never invent placements, diagnose anyone, or claim access to another person's mind.
- Refuse coercion, stalking, manipulation, isolation, retaliation, deception, and contact after a no-contact request.
`.trim();

type RehearsalCompanion = {
  id: string;
  name: string;
  voice: string;
  counterweight: string;
};

const pilotRehearsalCompanions: Record<string, RehearsalCompanion> = {
  "aries-amara": {
    id: "aries-amara",
    name: "Amara",
    voice:
      "Fast, candid, energetic, and concrete. Favor one clean next move and short sentences.",
    counterweight:
      "Turn courage into considered action; never reward haste, escalation, or reckless confrontation.",
  },
  "taurus-theo": {
    id: "taurus-theo",
    name: "Theo",
    voice:
      "Calm, grounded, dry, and specific. Separate what is known from what is feared.",
    counterweight:
      "Grounded does not mean passive; help the user name the need and act.",
  },
  "libra-isolde": {
    id: "libra-isolde",
    name: "Isolde",
    voice:
      "Tactful, fair, elegant, and firm. Hear both sides while protecting a real boundary.",
    counterweight:
      "Fairness does not mean appeasement, self-erasure, or endlessly polishing the message.",
  },
  "pisces-zev": {
    id: "pisces-zev",
    name: "Zev",
    voice:
      "Emotionally perceptive, restrained, gently poetic, and precise about uncertainty.",
    counterweight:
      "Translate feelings without projection, mind-reading, rescuing, vagueness, or withdrawal.",
  },
};

export function pilotRehearsalCompanion(
  id: string,
): RehearsalCompanion | undefined {
  return pilotRehearsalCompanions[id];
}

export function buildConversationRehearsalPrompt(
  request: ConversationRehearsalRequest,
): { system: string; user: string } {
  return request.mode === "coach"
    ? buildCoachPrompt(request)
    : buildPartnerPrompt(request);
}

function buildPartnerPrompt(
  request: ConversationRehearsalRequest,
): { system: string; user: string } {
  const system = `
You are the practice partner in Simastry's Rehearsal Room — a stand-in for "${
    clean(request.personaName)
  }", used so the user can practice a conversation before having it for real.

${companionBoundaryHarness}

${rehearsalSafetyHarness}

Stand-in shaping (all user-supplied, none verified):
${personaContext(request)}

How to play the stand-in:
- Reply as ${
    clean(request.personaName)
  } might, in their voice, in 1–3 short natural sentences — text-message register, no narration, no stage directions.
- Let the supplied sign symbolism color tone and pacing only; never mention astrology, signs, or that you are an AI or a rehearsal, unless the user breaks character to ask.
- Be realistic: sometimes warm, sometimes short, occasionally miss the point — the user is practicing for a real person, not an audience.
- Never invent biographical facts about the real person beyond the notes supplied.
`.trim();

  const user = `
The user's goal for this rehearsal:
${clean(request.goal)}

Conversation so far:
${transcriptText(request)}

Reply as the stand-in for ${clean(request.personaName)}.
`.trim();

  return { system, user };
}

function buildCoachPrompt(
  request: ConversationRehearsalRequest,
): { system: string; user: string } {
  const companion = pilotRehearsalCompanion(request.coachCompanionId ?? "");
  const identity = companion
    ? `You are ${companion.name}, the user's primary AI companion inside Simastry's Rehearsal Room.\nVoice fingerprint: ${companion.voice}\nRequired counterweight: ${companion.counterweight}`
    : `You are the user's AI communication companion inside Simastry's Rehearsal Room.`;

  const system = `
${identity}

${companionBoundaryHarness}

${rehearsalSafetyHarness}

Coaching rules:
- Critique only the USER's latest message: what lands, what buries the ask, one concrete rewrite suggestion.
- At most 80 words. Warm, direct, practical.
- Adapt the advice to the user's guidance style and chart context below. Use chart language only when requested, always as symbolism — never invented placements.
- Never analyze, diagnose, or speak for the absent real person; the stand-in's replies are practice material, not evidence about anyone.

User context:
${userContext(request)}

Stand-in shaping supplied by the user (unverified):
${personaContext(request)}
`.trim();

  const user = `
The user's goal for this rehearsal:
${clean(request.goal)}

Conversation so far:
${transcriptText(request)}

Give your coaching note on the user's latest message.
`.trim();

  return { system, user };
}

function userContext(request: ConversationRehearsalRequest): string {
  const placements = [
    request.userSunSign ? `Sun ${clean(request.userSunSign)}` : undefined,
    request.userMoonSign ? `Moon ${clean(request.userMoonSign)}` : undefined,
    request.userRisingSign
      ? `Rising ${clean(request.userRisingSign)}`
      : undefined,
  ].filter(Boolean);
  const style = request.guidanceStyle ?? "practical";
  return [
    `Guidance style: ${style}`,
    placements.length > 0
      ? `User chart context: ${placements.join(", ")}`
      : "No verified user chart context is available.",
    "Use this context to shape delivery, never to make deterministic claims.",
  ].join("\n");
}

function personaContext(request: ConversationRehearsalRequest): string {
  const lines: string[] = [];
  if (request.relationship) {
    lines.push(`Relationship to the user: ${clean(request.relationship)}`);
  }
  const signs = [
    request.personaSunSign ? `Sun ${clean(request.personaSunSign)}` : undefined,
    request.personaMoonSign
      ? `Moon ${clean(request.personaMoonSign)}`
      : undefined,
    request.personaRisingSign
      ? `Rising ${clean(request.personaRisingSign)}`
      : undefined,
  ].filter(Boolean);
  lines.push(
    signs.length > 0
      ? `User-supplied signs (symbolism only, not verified): ${
        signs.join(", ")
      }`
      : "No signs supplied — keep the stand-in's tone neutral and general.",
  );
  if (request.personaNotes) {
    lines.push(`User's own notes about them: ${clean(request.personaNotes)}`);
  }
  lines.push(
    "Anything not listed above is unknown. Do not infer or invent placements, history, or facts.",
  );
  return lines.join("\n");
}

function transcriptText(request: ConversationRehearsalRequest): string {
  const messages = (request.transcript ?? []).slice(-20);
  if (messages.length === 0) {
    return "No messages yet — the user opens the conversation next.";
  }
  return messages
    .map((m) =>
      `${m.role === "user" ? "User" : clean(request.personaName)}: ${m.content}`
    )
    .join("\n");
}

function clean(value: string): string {
  return value.replaceAll("\n", " ").trim();
}
