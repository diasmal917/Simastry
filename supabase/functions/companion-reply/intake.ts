import type { CompanionReplyPayload, UserAstrologyContext } from "./specialistPrompt.ts";

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

export type ExpertPersonAstrologyIntakeRow = {
  person_id?: string | null;
  display_name?: string | null;
  birth_date?: string | null;
  birth_time?: string | null;
  birth_time_unknown?: boolean | null;
  birth_place?: string | null;
  user_supplied_tradition_data?: Record<string, unknown> | null;
  chart_import_id?: string | null;
};

export type ExpertAstrologyChartImportRow = {
  id?: string | null;
  subject_type?: "self" | "person" | string | null;
  person_id?: string | null;
  status?: string | null;
  storage_path?: string | null;
  source_label?: string | null;
  extracted_data?: Record<string, unknown> | null;
  confirmed_data?: Record<string, unknown> | null;
  extraction_warnings?: unknown[] | null;
};

export type ExpertAstrologyHydration = {
  selfIntake?: ExpertAstrologyIntakeRow;
  selectedPersonIntake?: ExpertPersonAstrologyIntakeRow;
  selfChartImport?: ExpertAstrologyChartImportRow;
  selectedPersonChartImport?: ExpertAstrologyChartImportRow;
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

export const allowedChartImportDataFields = [
  "western.sunSign",
  "western.moonSign",
  "western.risingSign",
  "western.venusSign",
  "western.marsSign",
  "western.houses",
  "western.aspects",
  ...allowedUserSuppliedTraditionDataFields,
] as const;

const allowedChartImportFieldSet = new Set<string>(
  allowedChartImportDataFields,
);

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
  return mergeExpertAstrologyHydration(payload, { selfIntake: intake });
}

export function mergeExpertAstrologyHydration(
  payload: CompanionReplyPayload,
  hydration: ExpertAstrologyHydration,
): CompanionReplyPayload {
  const expert = payload.expertAstrologerRequest;
  if (payload.feature !== "expert_astrologer" || !expert) {
    return payload;
  }

  const selfIntake = hydration.selfIntake;
  const persistedTraditionData = flattenUserSuppliedTraditionData(
    selfIntake?.user_supplied_tradition_data,
  );
  const profileContext = mergePersonProfileContext(
    selfIntake ? mergeProfileContext(expert.profileContext, selfIntake) : (expert.profileContext ?? emptyProfileContext()),
    hydration.selectedPersonIntake,
  );
  const knownDataPoints = mergeUniqueStrings(
    expert.knownDataPoints,
    [
      ...(selfIntake ? knownDataPointsForIntake(selfIntake) : []),
      ...knownDataPointsForPersonIntake(hydration.selectedPersonIntake),
      ...knownDataPointsForChartImport("user", hydration.selfChartImport),
      ...knownDataPointsForChartImport(
        "selected person",
        hydration.selectedPersonChartImport,
      ),
    ],
  );
  const dataLimitations = mergeUniqueStrings(
    expert.dataLimitations,
    [
      ...(selfIntake ? dataLimitationsForIntake(selfIntake) : []),
      ...dataLimitationsForPersonIntake(hydration.selectedPersonIntake),
      ...dataLimitationsForChartImport("user", hydration.selfChartImport),
      ...dataLimitationsForChartImport(
        "selected person",
        hydration.selectedPersonChartImport,
      ),
    ],
  );
  const userSuppliedTraditionData = {
    ...(persistedTraditionData ?? {}),
    ...prefixedRecord(
      "uploadedChart",
      flattenConfirmedChartImportData(hydration.selfChartImport),
    ),
    ...prefixedRecord(
      "person.uploadedChart",
      flattenConfirmedChartImportData(hydration.selectedPersonChartImport),
    ),
    ...prefixedRecord(
      "person",
      flattenUserSuppliedTraditionData(
        hydration.selectedPersonIntake?.user_supplied_tradition_data,
      ),
    ),
    ...(expert.userSuppliedTraditionData ?? {}),
  };

  return {
    ...payload,
    expertAstrologerRequest: {
      ...expert,
      profileContext,
      knownDataPoints,
      userSuppliedTraditionData: Object.keys(userSuppliedTraditionData).length > 0 ? userSuppliedTraditionData : undefined,
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
    .map(([key, item]) => [canonicalManualFieldKey(key), String(item).trim().slice(0, 500)] as const)
    .filter(([key, item]) => Boolean(key && item && allowedFieldSet.has(key)));

  const result = Object.fromEntries(entries);
  return Object.keys(result).length > 0 ? result : undefined;
}

export function flattenConfirmedChartImportData(
  chartImport?: ExpertAstrologyChartImportRow,
): Record<string, string> | undefined {
  if (!chartImport || chartImport.status !== "confirmed") return undefined;
  const value = chartImport.confirmed_data;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return undefined;
  }

  const flattened = flattenObject(value as Record<string, unknown>);
  const entries = Object.entries(flattened)
    .map(([key, item]) =>
      [
        canonicalChartImportFieldKey(key),
        String(item).trim().slice(0, 500),
      ] as const
    )
    .filter(([key, item]) => Boolean(key && item && allowedChartImportFieldSet.has(key)));

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
    (partnerBirthTimeUnknown ? undefined : cleanString(intake.partner_birth_time));

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

function mergePersonProfileContext(
  context: UserAstrologyContext,
  intake?: ExpertPersonAstrologyIntakeRow,
): UserAstrologyContext {
  if (!intake) return context;
  const partnerBirthTimeUnknown = context.partnerBirthTimeUnknown ??
    Boolean(intake.birth_time_unknown);
  const partnerBirthTime = context.partnerBirthTime ??
    (partnerBirthTimeUnknown ? undefined : cleanString(intake.birth_time));

  return {
    ...context,
    partnerName: context.partnerName ?? cleanString(intake.display_name),
    partnerBirthDate: context.partnerBirthDate ??
      cleanString(intake.birth_date),
    partnerBirthTime,
    partnerBirthTimeUnknown,
    partnerBirthPlace: context.partnerBirthPlace ??
      cleanString(intake.birth_place),
    partnerBirthDateAvailable: context.partnerBirthDateAvailable ||
      Boolean(intake.birth_date),
    partnerBirthTimeAvailable: context.partnerBirthTimeAvailable ||
      Boolean(partnerBirthTime),
    partnerBirthPlaceAvailable: context.partnerBirthPlaceAvailable ||
      Boolean(cleanString(intake.birth_place)),
  };
}

function knownDataPointsForIntake(intake: ExpertAstrologyIntakeRow): string[] {
  return [
    intake.birth_date ? "User birth date is saved as user-supplied intake." : undefined,
    intake.birth_time ? "User birth time is saved as user-supplied intake." : undefined,
    intake.birth_time_unknown ? "User marked birth time as unknown." : undefined,
    intake.birth_place ? "User birth place is saved as user-supplied intake." : undefined,
    intake.partner_birth_date ? "Partner/person birth date is saved as user-supplied intake." : undefined,
    intake.partner_birth_time ? "Partner/person birth time is saved as user-supplied intake." : undefined,
    intake.partner_birth_time_unknown ? "Partner/person birth time is marked unknown." : undefined,
    intake.partner_birth_place ? "Partner/person birth place is saved as user-supplied intake." : undefined,
    flattenUserSuppliedTraditionData(intake.user_supplied_tradition_data)
      ? "Manual tradition fields are saved as user-supplied, not app-calculated."
      : undefined,
  ].filter(Boolean) as string[];
}

function knownDataPointsForPersonIntake(
  intake?: ExpertPersonAstrologyIntakeRow,
): string[] {
  if (!intake) return [];
  return [
    intake.display_name ? "Selected person label is saved as user-supplied intake." : undefined,
    intake.birth_date ? "Selected person birth date is saved as user-supplied intake." : undefined,
    intake.birth_time ? "Selected person birth time is saved as user-supplied intake." : undefined,
    intake.birth_time_unknown ? "Selected person birth time is marked unknown." : undefined,
    intake.birth_place ? "Selected person birth place is saved as user-supplied intake." : undefined,
    flattenUserSuppliedTraditionData(intake.user_supplied_tradition_data)
      ? "Selected person manual tradition fields are saved as user-supplied, not app-calculated."
      : undefined,
  ].filter(Boolean) as string[];
}

function knownDataPointsForChartImport(
  subjectLabel: string,
  chartImport?: ExpertAstrologyChartImportRow,
): string[] {
  if (!chartImport) return [];
  const source = cleanString(chartImport.source_label) ??
    "uploaded chart screenshot";
  if (chartImport.status !== "confirmed") {
    return [
      `${capitalize(subjectLabel)} chart screenshot is saved with status ${
        safeStatus(chartImport.status)
      } and still needs confirmation before experts can use extracted data.`,
    ];
  }
  return [
    `${capitalize(subjectLabel)} chart screenshot is user-confirmed from ${source}; any confirmed fields are user-supplied/extracted, not app-calculated.`,
  ];
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

function dataLimitationsForPersonIntake(
  intake?: ExpertPersonAstrologyIntakeRow,
): string[] {
  if (!intake) return [];
  return [
    intake.birth_time_unknown
      ? "Selected person birth time is explicitly unknown; do not infer compatibility houses, sect, dashas, pillars, Lots, or exact timing from it."
      : undefined,
  ].filter(Boolean) as string[];
}

function dataLimitationsForChartImport(
  subjectLabel: string,
  chartImport?: ExpertAstrologyChartImportRow,
): string[] {
  if (!chartImport) return [];
  const warnings = (chartImport.extraction_warnings ?? [])
    .map((item) => String(item).trim().slice(0, 220))
    .filter(Boolean)
    .slice(0, 6)
    .map((item) => `${capitalize(subjectLabel)} chart import warning: ${item}`);
  if (chartImport.status !== "confirmed") {
    return [
      `${
        capitalize(subjectLabel)
      } chart screenshot extraction is not confirmed; do not use extracted placements, houses, aspects, dashas, BaZi pillars, sect, Lots, or timing periods as facts.`,
      ...warnings,
    ];
  }
  return [
    `${capitalize(subjectLabel)} confirmed chart import remains user-supplied/extracted, not app-calculated; do not upgrade it to calculated data.`,
    ...warnings,
  ];
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

function canonicalChartImportFieldKey(key: string): string {
  return fieldAliases[key] ?? key;
}

function prefixedRecord(
  prefix: string,
  value?: Record<string, string>,
): Record<string, string> {
  if (!value) return {};
  return Object.fromEntries(
    Object.entries(value).map(([key, item]) => [`${prefix}.${key}`, item]),
  );
}

function cleanString(value?: string | null): string | undefined {
  const trimmed = value?.trim();
  return trimmed ? trimmed.slice(0, 240) : undefined;
}

function safeStatus(value?: string | null): string {
  return cleanString(value)?.replace(/[^a-z_ -]/gi, "").slice(0, 40) ||
    "unknown";
}

function capitalize(value: string): string {
  return value.length === 0 ? value : value[0].toUpperCase() + value.slice(1);
}
