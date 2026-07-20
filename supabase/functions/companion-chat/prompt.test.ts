import { getPilotPersona } from "../_shared/companion/registry.ts";
import { buildCompanionPrompt } from "./prompt.ts";

Deno.test("chat prompt includes only an explicitly resolved person and keeps uncertainty", () => {
  const prompt = buildCompanionPrompt(getPilotPersona("aries-amara"), {
    supportPreferences: {},
    birthChart: null,
    memories: [],
    transcript: [],
    selectedPerson: {
      displayName: "Maria",
      relationshipKind: "friend",
      pronouns: "she/her",
      birthChart: { sunSign: "libra" },
      communicationGuide: {
        deterministic: {
          source: "server_deterministic_sun_sign",
          sign: "libra",
        },
      },
      notes: null,
      situation: { actionState: "planned" },
    },
  }, "How should I answer Maria?");
  assertStringIncludes(prompt.user, '"displayName":"Maria"');
  assertStringIncludes(prompt.user, '"situation":{"actionState":"planned"}');
  assertStringIncludes(prompt.user, "uniquely named them");
  assertStringIncludes(
    prompt.system,
    "Do not claim to know another person's thoughts",
  );
});

Deno.test("chat prompt refuses to infer an unnamed saved person", () => {
  const prompt = buildCompanionPrompt(getPilotPersona("taurus-theo"), {
    supportPreferences: {},
    birthChart: null,
    memories: [],
    transcript: [],
    selectedPerson: null,
  }, "Why did they say that?");
  assertStringIncludes(prompt.user, '"explicitlyReferencedPerson":null');
  assertStringIncludes(prompt.user, "Do not choose one from memory");
});

Deno.test("chat prompt honors user corrections without inventing saved memory", () => {
  const prompt = buildCompanionPrompt(getPilotPersona("pisces-zev"), {
    supportPreferences: {},
    birthChart: null,
    memories: [{
      scope: "shared_user_fact",
      kind: "preference",
      content: "The user prefers long replies.",
      source: "user_explicit",
    }],
    transcript: [],
    selectedPerson: null,
  }, "Correction: I prefer concise replies now.");

  assertStringIncludes(
    prompt.system,
    "newest explicit correction as authoritative",
  );
  assertStringIncludes(prompt.system, "do not say it was saved");
});

function assertStringIncludes(actual: string, expected: string): void {
  if (!actual.includes(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(actual)} to include ${expected}`,
    );
  }
}
