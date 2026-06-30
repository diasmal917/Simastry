import {
  type ExpertAstrologyIntakeRow,
  flattenUserSuppliedTraditionData,
  mergeExpertAstrologyIntake,
} from "./intake.ts";
import type { CompanionReplyPayload } from "./specialistPrompt.ts";

Deno.test("flattenUserSuppliedTraditionData keeps only canonical manual fields", () => {
  const flattened = flattenUserSuppliedTraditionData({
    vedic: {
      nakshatra: "Rohini",
      siderealMoonRashi: "Vrishabha",
    },
    knownFourPillars: "Jia-Zi / Yi-Chou / Bing-Yin / Ding-Mao",
    relationshipPatternNotes: "I tend to rush reconciliation.",
    calculatedDasha: "Do not pass this through",
  });

  assertEquals(flattened, {
    "vedic.nakshatra": "Rohini",
    "vedic.siderealMoonRashi": "Vrishabha",
    "bazi.fourPillars": "Jia-Zi / Yi-Chou / Bing-Yin / Ding-Mao",
    "evolutionary.relationshipPatternNotes": "I tend to rush reconciliation.",
  });
});

Deno.test("mergeExpertAstrologyIntake hydrates availability without creating calculated data", () => {
  const payload = expertPayload();
  const intake: ExpertAstrologyIntakeRow = {
    birth_date: "1994-05-12",
    birth_time: null,
    birth_time_unknown: true,
    birth_place: "Los Angeles, CA",
    user_supplied_tradition_data: {
      bazi: { dayMaster: "Yang Wood" },
      knownHellenisticSect: "day chart",
    },
  };

  const merged = mergeExpertAstrologyIntake(payload, intake);
  const expert = merged.expertAstrologerRequest!;

  assertEquals(expert.profileContext?.birthDateAvailable, true);
  assertEquals(expert.profileContext?.birthTimeAvailable, false);
  assertEquals(expert.profileContext?.birthTimeUnknown, true);
  assertEquals(expert.profileContext?.birthPlaceAvailable, true);
  assertEquals(
    expert.userSuppliedTraditionData?.["bazi.dayMaster"],
    "Yang Wood",
  );
  assertEquals(
    expert.userSuppliedTraditionData?.["hellenistic.sect"],
    "day chart",
  );
  assertEquals(expert.calculatedTraditionData, undefined);
  assert(
    expert.knownDataPoints?.includes(
      "Manual tradition fields are saved as user-supplied, not app-calculated.",
    ) === true,
    "Expected user-supplied manual field note.",
  );
  assert(
    expert.dataLimitations?.some((item) =>
      item.includes("do not infer Rising sign")
    ) === true,
    "Expected birth-time limitation.",
  );
});

function expertPayload(): CompanionReplyPayload {
  return {
    kind: "chat",
    feature: "expert_astrologer",
    maxTokens: 520,
    expertAstrologerRequest: {
      specialistId: "mateo-vedic",
      mode: "individual",
      userQuestion: "What timing lens can you use?",
      profileContext: {
        birthDateAvailable: false,
        birthTimeAvailable: false,
        birthPlaceAvailable: false,
        partnerBirthDateAvailable: false,
        partnerBirthTimeAvailable: false,
        partnerBirthPlaceAvailable: false,
      },
      transcript: [],
      knownDataPoints: ["Question is ready for this consultation."],
      missingDataPoints: [],
      readinessSummary: "Can answer now, better with more data.",
      dataLimitations: [],
    },
  };
}

function assert(condition: boolean, message: string) {
  if (!condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
  }
}
