import {
  getPilotPersona,
  personaDistinctnessFingerprint,
  PILOT_COMPANION_IDS,
  PILOT_PERSONA_VERSION,
} from "./registry.ts";
import { CompanionRuntimeError } from "./errors.ts";

Deno.test("pilot registry exposes exactly four immutable Factory identities", () => {
  assertEquals(PILOT_COMPANION_IDS, [
    "aries-amara",
    "taurus-theo",
    "libra-isolde",
    "pisces-zev",
  ]);
  assertEquals(new Set(PILOT_COMPANION_IDS).size, 4);
  for (const id of PILOT_COMPANION_IDS) {
    const persona = getPilotPersona(id);
    assert(Object.isFrozen(persona));
    assertEquals(persona.version, PILOT_PERSONA_VERSION);
    assertEquals(persona.publicVersion, 1);
    assert(persona.supportPromise.length > 20);
  }
});

Deno.test("pilot programs remain meaningfully persona-distinct", () => {
  const fingerprints = PILOT_COMPANION_IDS.map((id) =>
    personaDistinctnessFingerprint(getPilotPersona(id))
  );
  assertEquals(new Set(fingerprints).size, 4);
  assert(getPilotPersona("aries-amara").actionBias.includes("clean sentence"));
  assert(
    getPilotPersona("taurus-theo").reasoningGuardrail.includes("avoidance"),
  );
  assert(
    getPilotPersona("libra-isolde").reasoningGuardrail.includes("self-erasure"),
  );
  assert(
    getPilotPersona("pisces-zev").reasoningGuardrail.includes(
      "Empathy is not evidence",
    ),
  );
});

Deno.test("uncertified and invented identities cannot resolve", () => {
  for (
    const id of ["aries-cassian", "aries-amara-v2", "amara", "expert-aurelia"]
  ) {
    try {
      getPilotPersona(id);
      throw new Error("Expected invalid_companion");
    } catch (error) {
      if (
        !(error instanceof CompanionRuntimeError) ||
        error.code !== "invalid_companion"
      ) {
        throw error;
      }
    }
  }
});

function assert(condition: boolean): void {
  if (!condition) throw new Error("Assertion failed");
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
