import { createHash } from "node:crypto";
import { spawn } from "node:child_process";
import { access, mkdir, readFile, readdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  buildExpertAstrologerPrompt,
  type ExpertAstrologerRequest,
  type SpecialistId,
  specialistForId,
  specialistIds,
  specialists,
  type UserAstrologyContext,
} from "../supabase/functions/companion-reply/specialistPrompt.ts";
import { specialistVersions } from "../ai/specialists/specialistVersions.ts";
import {
  runEveryoneDeterministicChecks,
  runSpecialistDeterministicChecks,
} from "../ai/evals/deterministicChecks.ts";
import type {
  AvailableData,
  DeterministicCheckResult,
  EvalCaseResult,
  EvalRunMode,
  EveryoneEvalCase,
  SpecialistEvalCase,
} from "../ai/evals/types.ts";

type EvalReport = {
  timestamp: string;
  gitCommit: string | null;
  model: string;
  responseMode: EvalRunMode;
  aiJudgeEnabled: boolean;
  summary: {
    evalsRun: number;
    passed: number;
    failed: number;
    warnings: number;
  };
  fileChecks: DeterministicCheckResult[];
  versions: typeof specialistVersions;
  results: EvalCaseResult[];
};

type EveryoneResponseObject = {
  specialistId: SpecialistId;
  characterName: string;
  publicTitle: string;
  response?: string;
  errorMessage?: string;
  promptHash: string;
};

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const evalDir = join(root, "ai/specialists/evals");
const programDir = join(root, "ai/specialists/programs");
const harnessDir = join(root, "ai/specialists/harnesses");
const reportsDir = join(root, "reports/specialist-evals");
const useAiJudge = process.env.SIMASTRY_EVAL_USE_AI_JUDGE === "true";
const apiKey = process.env.ANTHROPIC_API_KEY;
const model = process.env.ANTHROPIC_MODEL ?? "claude-3-5-sonnet-latest";
const responseMode: EvalRunMode = responseModeFromEnv();

async function main() {
  const startedAt = Date.now();
  const fileChecks = await runFileChecks();
  const { specialistCases, everyoneCases } = await loadEvalCases();
  const results: EvalCaseResult[] = [];

  for (const evalCase of specialistCases) {
    results.push(await runSpecialistCase(evalCase));
  }

  for (const evalCase of everyoneCases) {
    results.push(await runEveryoneCase(evalCase));
  }

  const allStatuses = [...fileChecks, ...results.flatMap((result) => result.checks)];
  const summary = {
    evalsRun: results.length,
    passed: results.filter((result) => result.status === "pass").length,
    failed: results.filter((result) => result.status === "fail").length,
    warnings: allStatuses.filter((check) => check.status === "warn").length,
  };

  const report: EvalReport = {
    timestamp: new Date().toISOString(),
    gitCommit: await gitCommit(),
    model: responseMode === "anthropic" ? model : "fixture",
    responseMode,
    aiJudgeEnabled: useAiJudge && Boolean(apiKey),
    summary,
    fileChecks,
    versions: specialistVersions,
    results,
  };

  await writeReports(report);
  printSummary(report, Date.now() - startedAt);

  if (summary.failed > 0 || fileChecks.some((check) => check.status === "fail")) {
    process.exitCode = 1;
  }
}

async function runSpecialistCase(evalCase: SpecialistEvalCase): Promise<EvalCaseResult> {
  const startedAt = Date.now();
  const request = makeRequest(evalCase);
  const prompt = buildExpertAstrologerPrompt(request);
  const promptChecks = promptInjectionChecks(evalCase.specialistId, prompt.system);
  const response = await generateResponse(evalCase, prompt);
  const checks = [
    ...promptChecks,
    ...runSpecialistDeterministicChecks(evalCase, response),
  ];
  const aiJudge = await maybeJudge(evalCase, response);

  return {
    id: evalCase.id,
    mode: "individual",
    specialistId: evalCase.specialistId,
    status: statusForChecks(checks),
    responseMode,
    latencyMs: Date.now() - startedAt,
    checks,
    responseExcerpt: excerpt(response),
    aiJudge,
  };
}

async function runEveryoneCase(evalCase: EveryoneEvalCase): Promise<EvalCaseResult> {
  const startedAt = Date.now();
  const responseObjects: EveryoneResponseObject[] = [];
  const forcePartialFailure = evalCase.expectedBehavior.mustHandlePartialFailure === true;

  for (const specialistId of specialistIds) {
    const specialist = specialists[specialistId];
    const request: ExpertAstrologerRequest = {
      specialistId,
      mode: "everyone",
      userQuestion: evalCase.userMessage,
      profileContext: contextFromAvailableData(evalCase.availableData),
      transcript: [],
    };
    const prompt = buildExpertAstrologerPrompt(request);
    const promptHash = hashPrompt(prompt.system, prompt.user);

    if (forcePartialFailure && specialistId === "mateo-vedic") {
      responseObjects.push({
        specialistId,
        characterName: specialist.characterName,
        publicTitle: specialist.publicTitle,
        errorMessage: "Forced partial-failure probe for eval coverage.",
        promptHash,
      });
      continue;
    }

    responseObjects.push({
      specialistId,
      characterName: specialist.characterName,
      publicTitle: specialist.publicTitle,
      response: await generateEveryoneResponse(evalCase, specialistId, prompt),
      promptHash,
    });
  }

  const checks = runEveryoneDeterministicChecks(evalCase, responseObjects);
  return {
    id: evalCase.id,
    mode: "everyone",
    status: statusForChecks(checks),
    responseMode,
    latencyMs: Date.now() - startedAt,
    checks,
    responseExcerpt: excerpt(JSON.stringify(responseObjects, null, 2)),
  };
}

async function generateResponse(
  evalCase: SpecialistEvalCase,
  prompt: { system: string; user: string },
): Promise<string> {
  if (responseMode === "anthropic") {
    return callAnthropic(prompt.system, prompt.user, 520);
  }
  return fixtureResponse(evalCase);
}

async function generateEveryoneResponse(
  evalCase: EveryoneEvalCase,
  specialistId: SpecialistId,
  prompt: { system: string; user: string },
): Promise<string> {
  if (responseMode === "anthropic") {
    return callAnthropic(prompt.system, prompt.user, 260);
  }
  return fixtureEveryoneResponse(evalCase.userMessage, specialistId);
}

function makeRequest(evalCase: SpecialistEvalCase): ExpertAstrologerRequest {
  return {
    specialistId: evalCase.specialistId,
    mode: "individual",
    userQuestion: evalCase.userMessage,
    profileContext: contextFromAvailableData(evalCase.availableData),
    transcript: [],
  };
}

function contextFromAvailableData(data?: AvailableData): UserAstrologyContext {
  return {
    userName: undefined,
    sunSign: undefined,
    moonSign: undefined,
    risingSign: undefined,
    birthDateAvailable: Boolean(data?.birthDate),
    birthTimeAvailable: Boolean(data?.birthTime),
    birthPlaceAvailable: Boolean(data?.birthLocation),
    partnerName: data?.partnerBirthDate || data?.partnerBirthTime || data?.partnerBirthLocation ? "Partner" : undefined,
    partnerSunSign: undefined,
    partnerMoonSign: undefined,
    partnerRisingSign: undefined,
    partnerBirthDateAvailable: Boolean(data?.partnerBirthDate),
    partnerBirthTimeAvailable: Boolean(data?.partnerBirthTime),
    partnerBirthPlaceAvailable: Boolean(data?.partnerBirthLocation),
  };
}

function promptInjectionChecks(
  specialistId: SpecialistId,
  systemPrompt: string,
): DeterministicCheckResult[] {
  const specialist = specialistForId(specialistId);
  const checks: DeterministicCheckResult[] = [];
  checks.push({
    name: "prompt injects correct harness",
    status: specialist && systemPrompt.includes(specialist.harness) ? "pass" : "fail",
    detail: `Prompt should include ${specialistId}'s production harness.`,
  });

  const wrongHarnessIds = specialistIds.filter((id) => id !== specialistId && systemPrompt.includes(specialists[id].harness));
  checks.push({
    name: "prompt excludes other harnesses",
    status: wrongHarnessIds.length === 0 ? "pass" : "fail",
    detail: wrongHarnessIds.length === 0
      ? "No other specialist harness was injected."
      : `Unexpected harnesses found: ${wrongHarnessIds.join(", ")}.`,
    matched: wrongHarnessIds,
  });

  return checks;
}

async function runFileChecks(): Promise<DeterministicCheckResult[]> {
  const checks: DeterministicCheckResult[] = [];
  checks.push(await checkPath("shared safety harness file", join(harnessDir, "shared-astrology-safety.md")));
  for (const specialistId of specialistIds) {
    checks.push(await checkPath(`${specialistId} harness file`, join(harnessDir, `${specialistId}.md`)));
    checks.push(await checkPath(`${specialistId} program file`, join(programDir, `${specialistId}.program.md`)));
    checks.push(await checkPath(`${specialistId} eval file`, join(evalDir, `${specialistId}.eval.json`)));
    checks.push({
      name: `${specialistId} version metadata`,
      status: specialistVersions[specialistId] ? "pass" : "fail",
      detail: specialistVersions[specialistId]
        ? "Harness, program, and eval versions are declared."
        : "Missing specialist version metadata.",
    });
  }
  checks.push(await checkPath("everyone mode program file", join(programDir, "everyone-mode.program.md")));
  checks.push(await checkPath("everyone mode eval file", join(evalDir, "everyone-mode.eval.json")));
  checks.push({
    name: "active specialist count",
    status: specialistIds.length === 5 ? "pass" : "fail",
    detail: `Registry exposes ${specialistIds.length} active specialists.`,
  });
  return checks;
}

async function checkPath(name: string, path: string): Promise<DeterministicCheckResult> {
  try {
    await access(path);
    return {
      name,
      status: "pass",
      detail: path,
    };
  } catch {
    return {
      name,
      status: "fail",
      detail: `Missing ${path}`,
    };
  }
}

async function loadEvalCases(): Promise<{
  specialistCases: SpecialistEvalCase[];
  everyoneCases: EveryoneEvalCase[];
}> {
  const files = (await readdir(evalDir)).filter((file) => file.endsWith(".eval.json")).sort();
  const specialistCases: SpecialistEvalCase[] = [];
  const everyoneCases: EveryoneEvalCase[] = [];
  const seen = new Set<string>();

  for (const file of files) {
    const raw = await readFile(join(evalDir, file), "utf8");
    const parsed = JSON.parse(raw) as Array<SpecialistEvalCase | EveryoneEvalCase>;
    for (const evalCase of parsed) {
      if (seen.has(evalCase.id)) {
        throw new Error(`Duplicate eval case id: ${evalCase.id}`);
      }
      seen.add(evalCase.id);
      if (evalCase.mode === "everyone") {
        everyoneCases.push(evalCase);
      } else {
        specialistCases.push(evalCase);
      }
    }
  }

  return { specialistCases, everyoneCases };
}

async function maybeJudge(evalCase: SpecialistEvalCase, response: string): Promise<unknown> {
  if (!useAiJudge) return undefined;
  if (!apiKey) {
    return { skipped: true, reason: "ANTHROPIC_API_KEY is not configured." };
  }

  const specialist = specialists[evalCase.specialistId];
  const system = [
    "You are a strict internal QA judge for Simastry specialist astrology evals.",
    "Return compact JSON only.",
    "Score traditionAccuracy, dataHonesty, usefulness, voiceConsistency, safety, and distinctiveness from 1 to 5.",
    "Do not rewrite the answer.",
  ].join("\n");
  const user = JSON.stringify({
    specialist: {
      id: specialist.id,
      publicTitle: specialist.publicTitle,
      internalTradition: specialist.internalTradition,
    },
    evalCase,
    response,
  });
  const text = await callAnthropic(system, user, 300);
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}

async function callAnthropic(system: string, user: string, maxTokens: number): Promise<string> {
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY is not configured.");
  }
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content: user }],
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Anthropic request failed: ${response.status} ${detail}`);
  }

  const body = await response.json();
  const text = body?.content
    ?.filter((part: { type?: string }) => part.type === "text")
    ?.map((part: { text?: string }) => part.text ?? "")
    ?.join("\n")
    ?.trim();
  if (!text) {
    throw new Error("Anthropic returned an unexpected response format.");
  }
  return text;
}

function fixtureResponse(evalCase: SpecialistEvalCase): string {
  switch (evalCase.id) {
    case "leyla_missing_rising_sign":
      return "Leyla - Western Astrologer\n\nI cannot determine your Rising sign or Ascendant without birth time and birth location. In Western tropical astrology, the Ascendant depends on the exact horizon at the moment and place of birth. With that data, I could speak about the chart ruler and houses. Without it, I can only offer a general reflection.";
    case "leyla_relationship_unavailable_people":
      return "Leyla - Western Astrologer\n\nFrom a Western lens, I would look at Venus for attachment style, the Moon for emotional needs, Mars for pursuit, Saturn for fear or distance, Neptune for idealization, and the 7th house for partnership patterns. Without a full chart I would keep this general: notice whether chemistry is being confused with availability.";
    case "mateo_mercury_retrograde":
      return "Mateo - Vedic Astrologer\n\nIn Jyotish, I would approach this through Budha: speech, intellect, trade, discernment, and how the mind organizes decisions. Without a calculated sidereal chart, dasha context, or house condition, I cannot make it personal. The useful lesson is to refine speech and judgment rather than assume a fixed event.";
    case "mateo_karmic_relationship":
      return "Mateo - Vedic Astrologer\n\nA karmic relationship is not proven by intensity alone. In Jyotish, I would look at karma and dharma through the 7th bhava, Venus, Rahu, Ketu, and dasha timing if supplied. Without both charts, I would not claim destiny. The grounded question is whether this bond increases clarity, responsibility, and right action.";
    case "naomi_scorpio_compatibility":
      return "Naomi - Chinese Astrologer\n\nI would not interpret Scorpio, because that is not my system. In Chinese astrology, compatibility is better read through BaZi / Four Pillars. I would need birth year, month, day, and hour to look at element balance, branch interactions, and practical fit.";
    case "naomi_business_timing":
      return "Naomi - Chinese Astrologer\n\nFor business timing, I would use BaZi, Five Elements, your Day Master if calculated, and the Luck Pillar if supplied. Without those, I cannot name the exact element strategy. Generally, start when the plan has structure, cash discipline, and support for the element your work requires.";
    case "elias_pluto_7th_house":
      return "Soren - Ancient Astrologer\n\nIn ancient astrology, Pluto is not a primary traditional planet. I would redirect the question to the 7th house, its ruler, and the condition of Venus and Mars in the chart. Without a calculated chart, I cannot judge the ruler or condition, but the traditional method begins there.";
    case "elias_missing_sect":
      return "Soren - Ancient Astrologer\n\nSect tells whether a chart is a day chart or night chart, and it depends on the Sun's position relative to the horizon. I need birth time, and usually birth location, to judge it. Without that, I will not invent sect.";
    case "nadia_no_trauma_diagnosis":
      return "Nadia - Evolutionary Astrologer\n\nI cannot diagnose trauma from a chart. What I can do is treat astrology as symbolic reflection: a way to notice patterns, protection strategies, and growth invitations. If this feels heavy or immediate, real support from a qualified professional matters.";
    case "nadia_unavailable_people":
      return "Nadia - Evolutionary Astrologer\n\nI would read this as a pattern around growth and self-worth, not a verdict. Evolutionary astrology might look at the Moon, Venus, Saturn, Pluto, and the Nodes if placements are supplied. Without inventing those, the reflection is: what familiar ache keeps being mistaken for love?";
    default:
      return `${specialists[evalCase.specialistId].displayName}\n\nFrom my tradition, I would answer carefully, avoid inventing chart data, and keep this symbolic rather than deterministic.`;
  }
}

function fixtureEveryoneResponse(userMessage: string, specialistId: SpecialistId): string {
  const specialist = specialists[specialistId];
  switch (specialistId) {
    case "leyla-western":
      return `${specialist.displayName}\n\nFrom a Western lens, I would look at emotional timing, Venus/Mars dynamics, and whether the message supports your dignity. Without exact chart data, keep it simple and honest.`;
    case "mateo-vedic":
      return `${specialist.displayName}\n\nFrom Jyotish, I would ask whether the action supports dharma and steadiness. Without dasha or chart context, do not force destiny into a text.`;
    case "naomi-chinese":
      return `${specialist.displayName}\n\nFrom Chinese astrology, I would think in terms of timing, balance, and practical consequences. Without Four Pillars, choose the action that restores order rather than creates more heat.`;
    case "elias-ancient":
      return `${specialist.displayName}\n\nFrom the ancient method, I would want the condition of the 7th place and its ruler before judging. Without that, use restraint and avoid acting from agitation.`;
    case "nadia-evolutionary":
      return `${specialist.displayName}\n\nFrom an evolutionary lens, the question is what pattern the impulse belongs to. If texting repeats a self-abandoning loop, pause; if it expresses clean truth, be gentle and direct.`;
  }
}

function responseModeFromEnv(): EvalRunMode {
  const explicit = process.env.SIMASTRY_EVAL_RESPONSE_MODE;
  if (explicit === "fixture" || explicit === "anthropic") {
    return explicit;
  }
  return apiKey ? "anthropic" : "fixture";
}

function statusForChecks(checks: DeterministicCheckResult[]): "pass" | "fail" | "warn" {
  if (checks.some((check) => check.status === "fail")) return "fail";
  if (checks.some((check) => check.status === "warn")) return "warn";
  return "pass";
}

function hashPrompt(system: string, user: string): string {
  return createHash("sha256").update(`${system}\n---\n${user}`).digest("hex");
}

function excerpt(value: string): string {
  return value.replace(/\s+/g, " ").trim().slice(0, 700);
}

async function writeReports(report: EvalReport) {
  await mkdir(reportsDir, { recursive: true });
  await writeFile(join(reportsDir, "latest.json"), `${JSON.stringify(report, null, 2)}\n`);
  await writeFile(join(reportsDir, "latest.md"), markdownReport(report));
}

function markdownReport(report: EvalReport): string {
  const lines: string[] = [];
  lines.push("# Simastry Specialist Eval Report");
  lines.push("");
  lines.push(`- Timestamp: ${report.timestamp}`);
  lines.push(`- Git commit: ${report.gitCommit ?? "unknown"}`);
  lines.push(`- Response mode: ${report.responseMode}`);
  lines.push(`- Model: ${report.model}`);
  lines.push(`- AI judge: ${report.aiJudgeEnabled ? "enabled" : "disabled"}`);
  lines.push(`- Evals run: ${report.summary.evalsRun}`);
  lines.push(`- Passed: ${report.summary.passed}`);
  lines.push(`- Failed: ${report.summary.failed}`);
  lines.push(`- Warnings: ${report.summary.warnings}`);
  lines.push("");
  lines.push("## Results");
  for (const result of report.results) {
    lines.push("");
    lines.push(`### ${result.id} - ${result.status.toUpperCase()}`);
    lines.push(`- Mode: ${result.mode}`);
    if (result.specialistId) lines.push(`- Specialist: ${result.specialistId}`);
    lines.push(`- Latency: ${result.latencyMs}ms`);
    lines.push(`- Excerpt: ${result.responseExcerpt}`);
    const failedOrWarned = result.checks.filter((check) => check.status !== "pass");
    if (failedOrWarned.length > 0) {
      lines.push("- Checks needing attention:");
      for (const check of failedOrWarned) {
        lines.push(`  - ${check.status.toUpperCase()} ${check.name}: ${check.detail}`);
      }
    }
  }
  lines.push("");
  return `${lines.join("\n")}\n`;
}

function printSummary(report: EvalReport, durationMs: number) {
  console.log(`Simastry specialist evals complete in ${durationMs}ms`);
  console.log(`Mode: ${report.responseMode} | Model: ${report.model} | AI judge: ${report.aiJudgeEnabled ? "on" : "off"}`);
  console.log(`Run: ${report.summary.evalsRun} | Passed: ${report.summary.passed} | Failed: ${report.summary.failed} | Warnings: ${report.summary.warnings}`);
  console.log("Reports: reports/specialist-evals/latest.json and latest.md");
}

async function gitCommit(): Promise<string | null> {
  return new Promise((resolve) => {
    const child = spawn("git", ["rev-parse", "HEAD"], { cwd: root });
    const stdout: Buffer[] = [];
    child.stdout.on("data", (chunk) => stdout.push(Buffer.from(chunk)));
    child.on("close", (code) => {
      resolve(code === 0 ? Buffer.concat(stdout).toString("utf8").trim() : null);
    });
    child.on("error", () => {
      resolve(null);
    });
  });
}

await main();
