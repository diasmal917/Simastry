import type {
  CompanionReplyPayload,
  UserAstrologyContext,
} from "./specialistPrompt.ts";

export type ExpertAstrologyIntakeRow = {
  birth_date?: string | null;
  birth_time?: string | null;
  birth_time_unknown?: boolean | null;
  birth_place?: string | null;
  partner_birth_date?: string | null;
  partner_birth_time?: string | null;
  partner_birth_time_unknown?: boolean | null;
  partner_birth_place?: string | null;
  user_supplied_tradition_data?: Record<string, unknown> | null;
};

export const allowedUserSuppliedTraditionDataFields = [
  "vedic.nakshatra",
  "vedic.siderealMoonRashi",
  "bazi.dayMaster",
  "bazi.fourPillars",
  "hellenistic.sect",
  "hellenistic.profectionYear",
  "evolutionary.relationshipPatternNotes",
  "evolutionary.reflectionPrompts",
] as const;

const allowedFieldSet = new Set<string>(allowedUserSuppliedTraditionDataFields);

const fieldAliases: Record<string, string> = {
  "knownVedicNakshatra": "vedic.nakshatra",
  "vedic.knownNakshatra": "vedic.nakshatra",
  "nakshatra": "vedic.nakshatra",
  "knownSiderealMoonRashi": "vedic.siderealMoonRashi",
  "vedic.rashi": "vedic.siderealMoonRashi",
  "siderealMoonRashi": "vedic.siderealMoonRashi",
  "knownBaZiDayMaster": "bazi.dayMaster",
  "bazi.knownDayMaster": "bazi.dayMaster",
  "dayMaster": "bazi.dayMaster",
  "knownFourPillars": "bazi.fourPillars",
  "fourPillars": "bazi.fourPillars",
  "knownHellenisticSect": "hellenistic.sect",
  "sect": "hellenistic.sect",
  "knownProfectionYear": "hellenistic.profectionYear",
  "profectionYear": "hellenistic.profectionYear",
  "relationshipPatternNotes": "evolutionary.relationshipPatternNotes",
  "reflectionPrompts": "evolutionary.reflectionPrompts",
};

export function mergeExpertAstrologyIntake(
  payload: CompanionReplyPayload,
  intake?: ExpertAstrologyIntakeRow,
): CompanionReplyPayload {
  const expert = payload.expertAstrologerRequest;
  if (payload.feature !== "expert_astrologer" || !expert || !intake) {
    return payload;
  }

  const persistedTraditionData = flattenUserSuppliedTraditionData(
    intake.user_supplied_tradition_data,
  );
  const profileContext = mergeProfileContext(expert.profileContext, intake);
  const knownDataPoints = mergeUniqueStrings(
    expert.knownDataPoints,
    knownDataPointsForIntake(intake),
  );
  const dataLimitations = mergeUniqueStrings(
    expert.dataLimitations,
    dataLimitationsForIntake(intake),
  );
  const userSuppliedTraditionData = {
    ...(persistedTraditionData ?? {}),
    ...(expert.userSuppliedTraditionData ?? {}),
  };

  return {
    ...payload,
    expertAstrologerRequest: {
      ...expert,
      profileContext,
      knownDataPoints,
      userSuppliedTraditionData:
        Object.keys(userSuppliedTraditionData).length > 0
          ? userSuppliedTraditionData
          : undefined,
      dataLimitations,
    },
  };
}

export function flattenUserSuppliedTraditionData(
  value: unknown,
): Record<string, string> | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }

  const flattened = flattenObject(value as Record<string, unknown>);
  const entries = Object.entries(flattened)
    .map(([key, item]) =>
      [canonicalManualFieldKey(key), String(item).trim().slice(0, 500)] as const
    )
    .filter(([key, item]) => Boolean(key && item && allowedFieldSet.has(key)));

  const result = Object.fromEntries(entries);
  return Object.keys(result).length > 0 ? result : undefined;
}

function mergeProfileContext(
  context: UserAstrologyContext | undefined,
  intake: ExpertAstrologyIntakeRow,
): UserAstrologyContext {
  const base = context ?? emptyProfileContext();
  const birthTimeUnknown = base.birthTimeUnknown ??
    Boolean(intake.birth_time_unknown);
  const partnerBirthTimeUnknown = base.partnerBirthTimeUnknown ??
    Boolean(intake.partner_birth_time_unknown);
  const birthTime = base.birthTime ??
    (birthTimeUnknown ? undefined : cleanString(intake.birth_time));
  const partnerBirthTime = base.partnerBirthTime ??
    (partnerBirthTimeUnknown
      ? undefined
      : cleanString(intake.partner_birth_time));

  return {
    ...base,
    birthDate: base.birthDate ?? cleanString(intake.birth_date),
    birthTime,
    birthTimeUnknown,
    birthPlace: base.birthPlace ?? cleanString(intake.birth_place),
    birthDateAvailable: base.birthDateAvailable || Boolean(intake.birth_date),
    birthTimeAvailable: base.birthTimeAvailable || Boolean(birthTime),
    birthPlaceAvailable: base.birthPlaceAvailable ||
      Boolean(cleanString(intake.birth_place)),
    partnerBirthDate: base.partnerBirthDate ??
      cleanString(intake.partner_birth_date),
    partnerBirthTime,
    partnerBirthTimeUnknown,
    partnerBirthPlace: base.partnerBirthPlace ??
      cleanString(intake.partner_birth_place),
    partnerBirthDateAvailable: base.partnerBirthDateAvailable ||
      Boolean(intake.partner_birth_date),
    partnerBirthTimeAvailable: base.partnerBirthTimeAvailable ||
      Boolean(partnerBirthTime),
    partnerBirthPlaceAvailable: base.partnerBirthPlaceAvailable ||
      Boolean(cleanString(intake.partner_birth_place)),
  };
}

function knownDataPointsForIntake(intake: ExpertAstrologyIntakeRow): string[] {
  return [
    intake.birth_date
      ? "User birth date is saved as user-supplied intake."
      : undefined,
    intake.birth_time
      ? "User birth time is saved as user-supplied intake."
      : undefined,
    intake.birth_time_unknown
      ? "User marked birth time as unknown."
      : undefined,
    intake.birth_place
      ? "User birth place is saved as user-supplied intake."
      : undefined,
    intake.partner_birth_date
      ? "Partner/person birth date is saved as user-supplied intake."
      : undefined,
    intake.partner_birth_time
      ? "Partner/person birth time is saved as user-supplied intake."
      : undefined,
    intake.partner_birth_time_unknown
      ? "Partner/person birth time is marked unknown."
      : undefined,
    intake.partner_birth_place
      ? "Partner/person birth place is saved as user-supplied intake."
      : undefined,
    flattenUserSuppliedTraditionData(intake.user_supplied_tradition_data)
      ? "Manual tradition fields are saved as user-supplied, not app-calculated."
      : undefined,
  ].filter(Boolean) as string[];
}

function dataLimitationsForIntake(intake: ExpertAstrologyIntakeRow): string[] {
  return [
    intake.birth_time_unknown
      ? "User birth time is explicitly unknown; do not infer Rising sign, houses, sect, dashas, pillars, Lots, or exact timing from it."
      : undefined,
    intake.partner_birth_time_unknown
      ? "Partner/person birth time is explicitly unknown; do not infer compatibility houses or exact timing from it."
      : undefined,
  ].filter(Boolean) as string[];
}

function emptyProfileContext(): UserAstrologyContext {
  return {
    birthDateAvailable: false,
    birthTimeAvailable: false,
    birthPlaceAvailable: false,
    partnerBirthDateAvailable: false,
    partnerBirthTimeAvailable: false,
    partnerBirthPlaceAvailable: false,
  };
}

function mergeUniqueStrings(
  existing: string[] | undefined,
  additions: string[],
): string[] | undefined {
  const merged = [...(existing ?? []), ...additions]
    .map((item) => item.trim())
    .filter(Boolean);
  if (merged.length === 0) return undefined;
  return Array.from(new Set(merged));
}

function flattenObject(
  value: Record<string, unknown>,
  prefix = "",
): Record<string, string> {
  const result: Record<string, string> = {};
  for (const [key, item] of Object.entries(value)) {
    const cleanKey = key.trim();
    if (!cleanKey) continue;
    const path = prefix ? `${prefix}.${cleanKey}` : cleanKey;
    if (item && typeof item === "object" && !Array.isArray(item)) {
      Object.assign(
        result,
        flattenObject(item as Record<string, unknown>, path),
      );
    } else if (
      typeof item === "string" || typeof item === "number" ||
      typeof item === "boolean"
    ) {
      result[path] = String(item);
    }
  }
  return result;
}

function canonicalManualFieldKey(key: string): string {
  return fieldAliases[key] ?? key;
}

function cleanString(value?: string | null): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed.slice(0, 240) : undefined;
}
