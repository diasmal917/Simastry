import type { SpecialistId } from "../../supabase/functions/companion-reply/specialistPrompt.ts";

export type AvailableData = {
  birthDate?: string | null;
  birthTime?: string | null;
  birthLocation?: string | null;
  partnerBirthDate?: string | null;
  partnerBirthTime?: string | null;
  partnerBirthLocation?: string | null;
  westernChartProvided?: boolean;
  vedicChartProvided?: boolean;
  baziChartProvided?: boolean;
  ancientChartProvided?: boolean;
  evolutionaryChartProvided?: boolean;
};

export type SpecialistExpectedBehavior = {
  mustStayInTradition: boolean;
  mustNotInventChartData?: boolean;
  shouldMentionDataLimitations?: boolean;
  mustRefuseDiagnosis?: boolean;
  mustAvoidDeterminism?: boolean;
  mustMentionAny?: string[];
  shouldMentionAny?: string[];
  mustNotMention?: string[];
};

export type SpecialistRubric = {
  traditionAccuracy: number;
  dataHonesty: number;
  usefulness: number;
  voiceConsistency: number;
  safety: number;
  distinctiveness?: number;
};

export type SpecialistEvalCase = {
  id: string;
  specialistId: SpecialistId;
  mode: "individual";
  userMessage: string;
  availableData?: AvailableData;
  expectedBehavior: SpecialistExpectedBehavior;
  rubric: SpecialistRubric;
};

export type EveryoneEvalCase = {
  id: string;
  mode: "everyone";
  userMessage: string;
  availableData?: AvailableData;
  expectedBehavior: {
    mustCallAllFiveIndependently: boolean;
    mustReturnFiveResponses: boolean;
    mustKeepResponsesSeparate: boolean;
    mustHandlePartialFailure?: boolean;
    mustNotMergeIntoSingleAnswer: boolean;
    mustNotInventChartData?: boolean;
  };
};

export type EvalCase = SpecialistEvalCase | EveryoneEvalCase;

export type CheckStatus = "pass" | "fail" | "warn";

export type DeterministicCheckResult = {
  name: string;
  status: CheckStatus;
  detail: string;
  matched?: string[];
};

export type EvalRunMode = "fixture" | "anthropic";

export type EvalCaseResult = {
  id: string;
  mode: "individual" | "everyone";
  specialistId?: SpecialistId;
  status: "pass" | "fail" | "warn";
  responseMode: EvalRunMode;
  latencyMs: number;
  checks: DeterministicCheckResult[];
  responseExcerpt: string;
  aiJudge?: unknown;
};
