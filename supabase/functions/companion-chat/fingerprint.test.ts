import { fingerprintCompanionChatRequest } from "./fingerprint.ts";
import type { CompanionChatRequest } from "./contract.ts";

const baseRequest: CompanionChatRequest = Object.freeze({
  companionId: "aries-amara",
  conversationId: "11111111-1111-4111-8111-111111111111",
  clientMessageId: "22222222-2222-4222-8222-222222222222",
  message: "Email first@example.com",
  stream: false,
});

Deno.test("chat idempotency HMAC distinguishes raw PII but ignores transport mode", async () => {
  await withFingerprintKey(async () => {
    const first = await fingerprintCompanionChatRequest(baseRequest);
    const retry = await fingerprintCompanionChatRequest({
      ...baseRequest,
      stream: true,
    });
    const differentPii = await fingerprintCompanionChatRequest({
      ...baseRequest,
      message: "Email other@example.com",
    });

    assertEquals(first, retry);
    assert(first.value !== differentPii.value);
    assert(/^[0-9a-f]{64}$/.test(first.value));
    assertEquals(first.keyId, "v1");
    assert(!JSON.stringify(first).includes("example.com"));
  });
});

Deno.test("chat idempotency HMAC fails closed on a weak or missing key", async () => {
  const previous = Deno.env.get("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY");
  try {
    Deno.env.delete("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY");
    await assertRejects(() => fingerprintCompanionChatRequest(baseRequest));
    Deno.env.set("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY", "too-short");
    await assertRejects(() => fingerprintCompanionChatRequest(baseRequest));
  } finally {
    restoreEnv(previous);
  }
});

async function withFingerprintKey(action: () => Promise<void>): Promise<void> {
  const previous = Deno.env.get("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY");
  Deno.env.set(
    "SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY",
    "test-only-key-material-at-least-32-bytes-long",
  );
  try {
    await action();
  } finally {
    restoreEnv(previous);
  }
}

function restoreEnv(value: string | undefined): void {
  if (value === undefined) {
    Deno.env.delete("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY");
  } else {
    Deno.env.set("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY", value);
  }
}

async function assertRejects(action: () => Promise<unknown>): Promise<void> {
  try {
    await action();
    throw new Error("Expected rejection");
  } catch (error) {
    if (error instanceof Error && error.message === "Expected rejection") {
      throw error;
    }
  }
}

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
