import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import { parseCompanionChatRequest } from "./contract.ts";

const validBody: Record<string, unknown> = {
  companionId: "aries-amara",
  conversationId: "11111111-1111-4111-8111-111111111111",
  clientMessageId: "22222222-2222-4222-8222-222222222222",
  message: "Help me plan a calm conversation.",
  stream: true,
};

Deno.test("chat contract accepts only the public five-field request", () => {
  assertEquals(parseCompanionChatRequest(validBody), validBody);
});

Deno.test("chat contract rejects prompt and identity spoofing fields", () => {
  for (
    const key of [
      "system",
      "prompt",
      "persona",
      "personaVersion",
      "userId",
      "memory",
      "transcript",
      "model",
      "maxTokens",
    ]
  ) {
    assertRuntimeError(
      () => parseCompanionChatRequest({ ...validBody, [key]: "spoofed" }),
      "invalid_payload",
    );
  }
});

Deno.test("chat contract rejects missing, malformed, and oversized values", () => {
  const { stream: _stream, ...missingStream } = validBody;
  assertRuntimeError(
    () => parseCompanionChatRequest(missingStream),
    "invalid_payload",
  );
  assertRuntimeError(
    () => parseCompanionChatRequest({ ...validBody, stream: "yes" }),
    "invalid_payload",
  );
  assertRuntimeError(
    () =>
      parseCompanionChatRequest({ ...validBody, conversationId: "not-a-uuid" }),
    "invalid_payload",
  );
  assertRuntimeError(
    () =>
      parseCompanionChatRequest({ ...validBody, message: "x".repeat(4_001) }),
    "invalid_payload",
  );
});

function assertRuntimeError(action: () => unknown, code: string): void {
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
