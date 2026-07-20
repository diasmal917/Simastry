import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import { parseCompanionDecodeRequest } from "./contract.ts";

const validBody: Record<string, unknown> = {
  companionId: "pisces-zev",
  personId: "11111111-1111-4111-8111-111111111111",
  message: "Can we talk later?",
  persistMessage: false,
};

Deno.test("Decode accepts its exact non-persistent contract", () => {
  assertEquals(parseCompanionDecodeRequest(validBody), validBody);
});

Deno.test("Decode rejects persistence, raw prompts, and client context", () => {
  assertRuntimeCode(
    () => parseCompanionDecodeRequest({ ...validBody, persistMessage: true }),
    "message_persistence_forbidden",
  );
  for (const key of ["system", "prompt", "persona", "person", "userChart"]) {
    assertRuntimeCode(
      () => parseCompanionDecodeRequest({ ...validBody, [key]: {} }),
      "invalid_payload",
    );
  }
});

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
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
