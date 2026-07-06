import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert";
import {
  buildConversationRehearsalPrompt,
  type ConversationRehearsalRequest,
  rehearsalPartnerTurnLimit,
  rehearsalTurnLimitReached,
} from "./rehearsalPrompt.ts";

function baseRequest(mode: "partner" | "coach"): ConversationRehearsalRequest {
  return {
    mode,
    personaName: "Dad",
    relationship: "father",
    personaSunSign: "Capricorn",
    personaNotes: "Hates surprises; softens after facts.",
    goal: "Ask for space without a fight",
    coachSpecialistId: mode === "coach" ? "leyla-western" : undefined,
    transcript: [
      { role: "user", content: "Hey — can we talk about the weekend?" },
      { role: "partner", content: "What about it." },
      { role: "user", content: "I need some time to myself, honestly." },
    ],
  };
}

Deno.test("partner prompt is framed as a rehearsal stand-in, never the real person", () => {
  const { system } = buildConversationRehearsalPrompt(baseRequest("partner"));
  assertStringIncludes(system, "REHEARSAL");
  assertStringIncludes(system, "never the real person");
  assertStringIncludes(system, "stand-in for \"Dad\"");
});

Deno.test("partner prompt treats signs and notes as user-supplied symbolism", () => {
  const { system } = buildConversationRehearsalPrompt(baseRequest("partner"));
  assertStringIncludes(system, "Sun Capricorn");
  assertStringIncludes(system, "symbolism only, not verified");
  assertStringIncludes(system, "Hates surprises");
  assertStringIncludes(system, "Do not infer or invent placements");
});

Deno.test("partner prompt with no signs keeps the stand-in neutral", () => {
  const request = baseRequest("partner");
  request.personaSunSign = undefined;
  const { system } = buildConversationRehearsalPrompt(request);
  assertStringIncludes(system, "No signs supplied");
});

Deno.test("coach prompt carries the specialist harness and coaches only the user's side", () => {
  const { system, user } = buildConversationRehearsalPrompt(baseRequest("coach"));
  assertStringIncludes(system, "Leyla - Western Astrologer");
  assertStringIncludes(system, "Western tropical astrology");
  assertStringIncludes(system, "Never coach manipulation");
  assertStringIncludes(system, "Critique only the USER's latest message");
  assertStringIncludes(user, "coaching note");
});

Deno.test("transcript renders with the persona's name and the goal travels in the user turn", () => {
  const { user } = buildConversationRehearsalPrompt(baseRequest("partner"));
  assertStringIncludes(user, "Dad: What about it.");
  assertStringIncludes(user, "Ask for space without a fight");
});

Deno.test("turn limit counts partner replies", () => {
  assert(!rehearsalTurnLimitReached(baseRequest("partner").transcript));
  const long = Array.from({ length: rehearsalPartnerTurnLimit }, () => ({
    role: "partner" as const,
    content: "ok",
  }));
  assert(rehearsalTurnLimitReached(long));
  assertEquals(rehearsalTurnLimitReached([]), false);
});
