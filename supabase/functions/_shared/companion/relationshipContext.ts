import { boundedContextObject, boundedContextText } from "./context.ts";
import {
  redactAllowedThirdPartyJson,
  redactThirdPartyText,
  type ThirdPartyJsonAllowlist,
} from "./safety.ts";

export type RelationshipPersonRow = Readonly<{
  id: string;
  display_name: string;
  relationship_kind: string | null;
  pronouns: string | null;
  birth_chart: Record<string, unknown> | null;
  notes: string | null;
  communication_guide: Record<string, unknown> | null;
}>;

export type CommunicationOutcomeRow = Readonly<{
  action_text: string;
  action_state: string;
  planned_for: string | null;
  acted_at: string | null;
  result_kind: string | null;
  result_summary: string | null;
  result_source: string | null;
  result_recorded_at: string | null;
  follow_up_state: string;
  updated_at: string;
}>;

export type AuthorizedPersonContext = Readonly<{
  displayName: string;
  relationshipKind: string | null;
  pronouns: string | null;
  birthChart: Record<string, unknown> | null;
  communicationGuide: Record<string, unknown> | null;
  notes: string | null;
  situation: Record<string, unknown> | null;
}>;

type GuideFoundation = Readonly<{
  source: "server_deterministic_sun_sign";
  sign: string;
  bestApproach: string;
  avoid: string;
  limitation: string;
}>;

const guideBySign: Readonly<
  Record<
    string,
    Readonly<{
      bestApproach: string;
      avoid: string;
    }>
  >
> = Object.freeze({
  aries: {
    bestApproach:
      "Be direct, candid, and concise while leaving room for their choice.",
    avoid: "Avoid passive aggression, baiting, or escalating urgency.",
  },
  taurus: {
    bestApproach:
      "Be steady, concrete, and patient; give them time to respond.",
    avoid: "Avoid surprise pressure or treating a slower pace as refusal.",
  },
  gemini: {
    bestApproach:
      "Be curious, specific, and flexible enough to clarify as the conversation moves.",
    avoid:
      "Avoid repetition, lectures, or assuming a quick change of topic means indifference.",
  },
  cancer: {
    bestApproach:
      "Lead with warmth, name the emotional stakes, then make a clear request.",
    avoid: "Avoid dismissing emotion or using withdrawal to force reassurance.",
  },
  leo: {
    bestApproach:
      "Acknowledge real effort, speak warmly, and give feedback in private.",
    avoid:
      "Avoid humiliation, empty flattery, or turning recognition into leverage.",
  },
  virgo: {
    bestApproach: "Be precise, prepared, and practical about the next step.",
    avoid: "Avoid vagueness or dismissing careful questions as overthinking.",
  },
  libra: {
    bestApproach:
      "Frame the issue fairly, name both needs, and keep the boundary clear.",
    avoid:
      "Avoid aggression, false equivalence, or polishing the message until the ask disappears.",
  },
  scorpio: {
    bestApproach:
      "Be honest, discreet, and clear about what is known versus inferred.",
    avoid:
      "Avoid tests, manipulation, or pushing for disclosure before consent.",
  },
  sagittarius: {
    bestApproach:
      "Be frank, spacious, and focused on the larger purpose of the conversation.",
    avoid:
      "Avoid controlling language or treating independence as lack of care.",
  },
  capricorn: {
    bestApproach:
      "Respect their time, state the practical stakes, and follow through.",
    avoid:
      "Avoid vagueness, unreliability, or demanding instant emotional display.",
  },
  aquarius: {
    bestApproach:
      "Respect autonomy, engage the idea directly, and make the request without pressure.",
    avoid:
      "Avoid forcing convention or treating a different processing style as emotional absence.",
  },
  pisces: {
    bestApproach:
      "Use gentle clarity, validate impact, and keep the concrete request visible.",
    avoid:
      "Avoid harshness, projection, rescuing, or assuming sensitivity reveals hidden intent.",
  },
});

const chartPlacementAllowlist: ThirdPartyJsonAllowlist = Object.freeze({
  sign: true,
  resolvedSign: true,
  resolved_sign: true,
  possibleSigns: true,
  possible_signs: true,
  isResolved: true,
  is_resolved: true,
});

const birthChartAllowlist: ThirdPartyJsonAllowlist = Object.freeze({
  sunSign: true,
  sun_sign: true,
  moonSign: true,
  moon_sign: true,
  risingSign: true,
  rising_sign: true,
  sun: chartPlacementAllowlist,
  moon: chartPlacementAllowlist,
  rising: chartPlacementAllowlist,
  placements: Object.freeze({
    sun: chartPlacementAllowlist,
    moon: chartPlacementAllowlist,
    rising: chartPlacementAllowlist,
  }),
});

const communicationGuideSectionAllowlist: ThirdPartyJsonAllowlist = Object
  .freeze({
    heading: true,
    title: true,
    body: true,
    tips: true,
    avoid: true,
    bestApproach: true,
    best_approach: true,
  });

const communicationGuideAllowlist: ThirdPartyJsonAllowlist = Object.freeze({
  method: true,
  foundationSign: true,
  foundation_sign: true,
  title: true,
  tips: true,
  avoid: true,
  bestApproach: true,
  best_approach: true,
  situationStatus: true,
  situation_status: true,
  situationUpdatedAt: true,
  situation_updated_at: true,
  sections: communicationGuideSectionAllowlist,
  foundation: communicationGuideSectionAllowlist,
});

/**
 * Resolve a saved person only when the current message contains one unique,
 * exact display-name reference. A bounded/partial candidate set is deliberately
 * not resolved because a duplicate outside the bound could make it ambiguous.
 */
export function explicitlyReferencedPerson(
  message: string,
  candidates: readonly RelationshipPersonRow[],
  candidateSetComplete: boolean,
): RelationshipPersonRow | null {
  if (!candidateSetComplete) return null;
  const matches = candidates.filter((person) =>
    containsExactNameReference(message, person.display_name)
  );
  return matches.length === 1 ? matches[0] : null;
}

export function deterministicCommunicationGuide(
  birthChart: Record<string, unknown> | null,
): GuideFoundation | null {
  const sign = signFromChart(birthChart, "sun");
  const guide = sign ? guideBySign[sign] : undefined;
  if (!sign || !guide) return null;
  return Object.freeze({
    source: "server_deterministic_sun_sign",
    sign,
    bestApproach: guide.bestApproach,
    avoid: guide.avoid,
    limitation:
      "Sun-sign symbolism is a transparent starting point, not proof of personality or intent.",
  });
}

export function sanitizedThirdPartyBirthChart(
  value: Record<string, unknown> | null,
): Record<string, unknown> | null {
  return boundedContextObject(
    redactAllowedThirdPartyJson(value, birthChartAllowlist),
    12_000,
  );
}

export function sanitizedThirdPartyCommunicationGuide(
  value: Record<string, unknown> | null,
): Record<string, unknown> | null {
  return boundedContextObject(
    redactAllowedThirdPartyJson(value, communicationGuideAllowlist),
    10_000,
  );
}

export function buildAuthorizedPersonContext(
  person: RelationshipPersonRow,
  outcome: CommunicationOutcomeRow | null,
): AuthorizedPersonContext {
  const deterministic = deterministicCommunicationGuide(person.birth_chart);
  const saved = sanitizedThirdPartyCommunicationGuide(
    person.communication_guide,
  );
  const communicationGuide = deterministic || saved
    ? Object.freeze({ deterministic, saved })
    : null;
  const hasRecordedResult = outcome?.result_source === "user_recorded" &&
    Boolean(outcome.result_recorded_at);
  const situation = outcome
    ? boundedContextObject({
      action: boundedContextText(
        redactThirdPartyText(outcome.action_text),
        1_000,
      ),
      actionState: outcome.action_state,
      plannedFor: outcome.planned_for,
      actedAt: outcome.acted_at,
      resultKind: hasRecordedResult ? outcome.result_kind : null,
      resultSummary: hasRecordedResult && outcome.result_summary
        ? boundedContextText(
          redactThirdPartyText(outcome.result_summary),
          1_000,
        )
        : null,
      resultSource: hasRecordedResult ? "user_recorded" : null,
      resultRecordedAt: hasRecordedResult ? outcome.result_recorded_at : null,
      followUpState: outcome.follow_up_state,
      updatedAt: outcome.updated_at,
    }, 6_000)
    : null;
  return Object.freeze({
    displayName: boundedContextText(
      redactThirdPartyText(person.display_name),
      120,
    ),
    relationshipKind: person.relationship_kind
      ? boundedContextText(
        redactThirdPartyText(person.relationship_kind),
        80,
      )
      : null,
    pronouns: person.pronouns
      ? boundedContextText(redactThirdPartyText(person.pronouns), 80)
      : null,
    birthChart: sanitizedThirdPartyBirthChart(person.birth_chart),
    communicationGuide,
    notes: person.notes
      ? boundedContextText(redactThirdPartyText(person.notes), 2_000)
      : null,
    situation,
  });
}

function containsExactNameReference(
  message: string,
  displayName: string,
): boolean {
  const haystack = message.normalize("NFKC").toLocaleLowerCase();
  const needle = displayName.trim().normalize("NFKC").toLocaleLowerCase();
  if (
    Array.from(needle).filter((character) => /[\p{L}\p{N}]/u.test(character))
      .length < 2
  ) {
    return false;
  }
  let start = haystack.indexOf(needle);
  while (start >= 0) {
    const before = start === 0 ? "" : haystack[start - 1];
    const end = start + needle.length;
    const after = end >= haystack.length ? "" : haystack[end];
    if (!isWordCharacter(before) && !isWordCharacter(after)) return true;
    start = haystack.indexOf(needle, start + needle.length);
  }
  return false;
}

function isWordCharacter(value: string): boolean {
  return value.length > 0 && /[\p{L}\p{N}]/u.test(value);
}

function signFromChart(
  chart: Record<string, unknown> | null,
  placement: "sun" | "moon" | "rising",
): string | null {
  if (!chart) return null;
  const values = [
    chart[`${placement}Sign`],
    chart[`${placement}_sign`],
    asRecord(chart[placement])?.sign,
    asRecord(chart[placement])?.resolvedSign,
    asRecord(chart[placement])?.resolved_sign,
  ];
  for (const value of values) {
    if (typeof value !== "string") continue;
    const normalized = value.trim().toLocaleLowerCase();
    if (guideBySign[normalized]) return normalized;
  }
  return null;
}

function asRecord(value: unknown): Record<string, unknown> | undefined {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : undefined;
}
