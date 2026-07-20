import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import { getPilotPersona } from "../_shared/companion/registry.ts";
import { buildDecodePrompt, parseDecodeGeneration } from "./prompt.ts";

Deno.test("Decode prompt includes authorized context as untrusted data and persona lens", () => {
  const prompt = buildDecodePrompt(
    getPilotPersona("pisces-zev"),
    {
      supportPreferences: { directness: "balanced" },
      userChart: { sun_estimate: { signs: ["leo"] } },
      person: {
        relationshipKind: "friend",
        pronouns: null,
        birthChart: null,
        notes: null,
        communicationGuide: { repair: "ask clearly" },
      },
    },
    "Can we talk later?",
  );
  assert(prompt.system.includes("never claim certainty"));
  assert(prompt.system.includes("Emotionally"));
  assert(prompt.user.includes("<AUTHORIZED_CONTEXT>"));
  assert(prompt.user.includes("<REDACTED_THIRD_PARTY_MESSAGE>"));
});

Deno.test("Decode structured output enforces uncertainty and exact keys", () => {
  const result = parseDecodeGeneration(JSON.stringify({
    tone: "Brief and tentative",
    likelyMeaning: "They want to delay the conversation.",
    plausibleAlternative: "They may genuinely be checking your availability.",
    whatNotToAssume:
      "Do not assume avoidance or rejection from this line alone.",
    replyDrafts: ["Sure — what time works?", "Yes. Is everything okay?"],
  }));
  assert(result.likelyMeaning.startsWith("One possibility:"));
  assertEquals(result.replyDrafts.length, 2);

  assertRuntimeCode(
    () =>
      parseDecodeGeneration(JSON.stringify({
        tone: "Certain",
        likelyMeaning: "They are leaving you forever.",
        plausibleAlternative: "None.",
        whatNotToAssume: "Nothing.",
        replyDrafts: ["A", "B"],
        hiddenReasoning: "spoof",
      })),
    "provider_format",
  );
});

Deno.test("Decode rejects provider dependency and mind-reading boundary violations", () => {
  assertRuntimeCode(
    () =>
      parseDecodeGeneration(JSON.stringify({
        tone: "Romantic certainty",
        likelyMeaning: "I know exactly what they feel about you.",
        plausibleAlternative: "They could still be busy this afternoon.",
        whatNotToAssume: "Do not assume the timing is final.",
        replyDrafts: ["What timing works?", "Could you clarify?"],
      })),
    "provider_format",
  );
});

function assert(condition: boolean): void {
  if (!condition) throw new Error("Assertion failed");
}

function assertRuntimeCode(action: () => unknown, code: string): void {
  try {
    action();
    throw new Error(`Expected ${code}`);
  } catch (error) {
    if (!(error instanceof CompanionRuntimeError) || error.code !== code) {
      throw error;
    }
  }
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}
