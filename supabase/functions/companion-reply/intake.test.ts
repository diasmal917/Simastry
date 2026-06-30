import {
  type ExpertAstrologyChartImportRow,
  type ExpertAstrologyIntakeRow,
  type ExpertPersonAstrologyIntakeRow,
  flattenConfirmedChartImportData,
  flattenUserSuppliedTraditionData,
  mergeExpertAstrologyHydration,
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
    expert.dataLimitations?.some((item) => item.includes("do not infer Rising sign")) === true,
    "Expected birth-time limitation.",
  );
});

Deno.test("flattenConfirmedChartImportData keeps only confirmed chart-safe fields", () => {
  const chartImport: ExpertAstrologyChartImportRow = {
    status: "confirmed",
    confirmed_data: {
      western: {
        sunSign: "Scorpio",
        risingSign: "Cancer",
      },
      vedic: {
        nakshatra: "Rohini",
      },
      bazi: {
        dayMaster: "Yang Wood",
      },
      inventedDasha: "Saturn mahadasha",
      plutoPrimaryTraditionalMethod: "Do not pass this through",
    },
  };

  assertEquals(flattenConfirmedChartImportData(chartImport), {
    "western.sunSign": "Scorpio",
    "western.risingSign": "Cancer",
    "vedic.nakshatra": "Rohini",
    "bazi.dayMaster": "Yang Wood",
  });
});

Deno.test("mergeExpertAstrologyHydration labels confirmed chart import as user supplied, not calculated", () => {
  const payload = expertPayload();
  const chartImport: ExpertAstrologyChartImportRow = {
    status: "confirmed",
    source_label: "Astro-Seek screenshot",
    confirmed_data: {
      western: { sunSign: "Scorpio" },
      bazi: { fourPillars: "Jia-Zi / Yi-Chou / Bing-Yin / Ding-Mao" },
    },
    extraction_warnings: ["House cusps were not readable."],
  };

  const merged = mergeExpertAstrologyHydration(payload, {
    selfChartImport: chartImport,
  });
  const expert = merged.expertAstrologerRequest!;

  assertEquals(
    expert.userSuppliedTraditionData?.["uploadedChart.western.sunSign"],
    "Scorpio",
  );
  assertEquals(
    expert.userSuppliedTraditionData?.["uploadedChart.bazi.fourPillars"],
    "Jia-Zi / Yi-Chou / Bing-Yin / Ding-Mao",
  );
  assertEquals(expert.calculatedTraditionData, undefined);
  assert(
    expert.knownDataPoints?.some((item) => item.includes("user-confirmed from Astro-Seek screenshot")) === true,
    "Expected confirmed upload source note.",
  );
  assert(
    expert.dataLimitations?.some((item) => item.includes("not app-calculated")) === true,
    "Expected non-calculated limitation.",
  );
});

Deno.test("mergeExpertAstrologyHydration does not use unconfirmed extracted chart data", () => {
  const payload = expertPayload();
  const chartImport: ExpertAstrologyChartImportRow = {
    status: "needs_review",
    extracted_data: {
      western: { sunSign: "Scorpio" },
      vedic: { nakshatra: "Rohini" },
    },
    confirmed_data: {},
  };

  const merged = mergeExpertAstrologyHydration(payload, {
    selfChartImport: chartImport,
  });
  const expert = merged.expertAstrologerRequest!;

  assertEquals(expert.userSuppliedTraditionData, undefined);
  assert(
    expert.dataLimitations?.some((item) => item.includes("extraction is not confirmed")) === true,
    "Expected unconfirmed extraction limitation.",
  );
  assert(
    expert.knownDataPoints?.some((item) => item.includes("still needs confirmation")) === true,
    "Expected needs-confirmation known data point.",
  );
});

Deno.test("mergeExpertAstrologyHydration adds selected person intake as partner context", () => {
  const payload = expertPayload();
  const personIntake: ExpertPersonAstrologyIntakeRow = {
    person_id: "09ee0e7a-c0f1-4da9-83e2-7e8523680d97",
    display_name: "M.",
    birth_date: "1993-11-05",
    birth_time: null,
    birth_time_unknown: true,
    birth_place: "Austin, TX",
    user_supplied_tradition_data: {
      bazi: { dayMaster: "Yin Fire" },
    },
  };

  const merged = mergeExpertAstrologyHydration(payload, {
    selectedPersonIntake: personIntake,
  });
  const expert = merged.expertAstrologerRequest!;

  assertEquals(expert.profileContext?.partnerName, "M.");
  assertEquals(expert.profileContext?.partnerBirthDateAvailable, true);
  assertEquals(expert.profileContext?.partnerBirthTimeAvailable, false);
  assertEquals(expert.profileContext?.partnerBirthTimeUnknown, true);
  assertEquals(expert.profileContext?.partnerBirthPlaceAvailable, true);
  assertEquals(
    expert.userSuppliedTraditionData?.["person.bazi.dayMaster"],
    "Yin Fire",
  );
  assertEquals(expert.calculatedTraditionData, undefined);
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
