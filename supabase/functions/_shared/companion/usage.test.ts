import { CompanionRuntimeError } from "./errors.ts";
import {
  safelyFinalizeCompanionUsage,
  SupabaseCompanionUsageLedger,
  tokenSource,
} from "./usage.ts";

const userId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const usageEventId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

Deno.test("usage reservation sends only bounded provenance and numeric accounting", async () => {
  await withSupabaseEnv(async () => {
    let requestBody: Record<string, unknown> | null = null;
    let requestUrl = "";
    const ledger = new SupabaseCompanionUsageLedger((input, init) => {
      requestUrl = String(input);
      requestBody = JSON.parse(String(init?.body));
      return Promise.resolve(Response.json([{
        usage_event_id: usageEventId,
        allowed: true,
        limit_label: null,
      }]));
    });

    const reservation = await ledger.reserve({
      userId,
      feature: "companion_decode",
      personaId: "pisces-zev",
      personaVersion: "pilot-2026-07-19.1",
      modelProvider: "anthropic",
      model: "test-model",
      requestMaxTokens: 900,
      requestCharacters: 91,
    });

    assertEquals(reservation.id, usageEventId);
    assert(requestUrl.endsWith("/rest/v1/rpc/reserve_companion_ai_usage"));
    assertEquals(requestBody, {
      p_user_id: userId,
      p_feature: "companion_decode",
      p_persona_id: "pisces-zev",
      p_persona_version: "pilot-2026-07-19.1",
      p_model_provider: "anthropic",
      p_model: "test-model",
      p_request_max_tokens: 900,
      p_request_characters: 91,
      p_request_key: null,
      p_per_minute_limit: 12,
      p_per_day_limit: 300,
    });
    const serialized = JSON.stringify(requestBody);
    assert(!serialized.includes("message"));
    assert(!serialized.includes("prompt"));
    assert(!serialized.includes("person_id"));
    assert(!serialized.includes("content"));
  });
});

Deno.test("durable limit decisions become the public 429 error", async () => {
  await withSupabaseEnv(async () => {
    const ledger = new SupabaseCompanionUsageLedger(() =>
      Promise.resolve(Response.json([{
        usage_event_id: usageEventId,
        allowed: false,
        limit_label: "per_minute",
      }]))
    );
    try {
      await ledger.reserve({
        userId,
        feature: "companion_chat",
        personaId: "aries-amara",
        personaVersion: "pilot-2026-07-19.1",
        modelProvider: "anthropic",
        model: "test-model",
        requestMaxTokens: 640,
        requestCharacters: 20,
        requestKey: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
      });
      throw new Error("Expected durable rate limit");
    } catch (error) {
      if (!(error instanceof CompanionRuntimeError)) throw error;
      assertEquals(error.code, "ai_usage_limit");
      assertEquals(error.status, 429);
    }
  });
});

Deno.test("usage finalization records actual tokens and their source without content", async () => {
  await withSupabaseEnv(async () => {
    let requestBody: Record<string, unknown> | null = null;
    const ledger = new SupabaseCompanionUsageLedger((_input, init) => {
      requestBody = JSON.parse(String(init?.body));
      return Promise.resolve(Response.json(true));
    });
    await ledger.finalize({
      userId,
      usageEventId,
      status: "success",
      modelProvider: "anthropic",
      model: "actual-model",
      inputTokens: 37,
      outputTokens: 12,
      responseCharacters: 104,
      tokenSource: "provider",
      errorCode: null,
    });
    assertEquals(requestBody, {
      p_user_id: userId,
      p_usage_event_id: usageEventId,
      p_status: "success",
      p_model_provider: "anthropic",
      p_model: "actual-model",
      p_input_tokens: 37,
      p_output_tokens: 12,
      p_response_characters: 104,
      p_token_source: "provider",
      p_error_code: null,
    });
  });
});

Deno.test("token provenance distinguishes provider, deterministic, and unavailable counts", () => {
  assertEquals(
    tokenSource("anthropic", { inputTokens: 3, outputTokens: 2 }),
    "provider",
  );
  assertEquals(tokenSource("simastry_safety", undefined), "deterministic");
  assertEquals(tokenSource("anthropic", undefined), "unavailable");
});

Deno.test("usage finalization retries transient failures and reports exhaustion", async () => {
  const finalization = {
    userId,
    usageEventId,
    status: "success" as const,
    modelProvider: "anthropic",
    model: "test-model",
    inputTokens: 3,
    outputTokens: 2,
    responseCharacters: 12,
    tokenSource: "provider" as const,
    errorCode: null,
  };
  let recoverableCalls = 0;
  const recovered = await safelyFinalizeCompanionUsage({
    reserve: () => Promise.resolve({ id: usageEventId }),
    finalize: () => {
      recoverableCalls += 1;
      return recoverableCalls < 3
        ? Promise.reject(new Error("transient"))
        : Promise.resolve();
    },
  }, finalization);
  assertEquals(recovered, true);
  assertEquals(recoverableCalls, 3);

  let exhaustedCalls = 0;
  const exhausted = await safelyFinalizeCompanionUsage({
    reserve: () => Promise.resolve({ id: usageEventId }),
    finalize: () => {
      exhaustedCalls += 1;
      return Promise.reject(new Error("still unavailable"));
    },
  }, finalization);
  assertEquals(exhausted, false);
  assertEquals(exhaustedCalls, 3);
});

async function withSupabaseEnv(action: () => Promise<void>): Promise<void> {
  const previousUrl = Deno.env.get("SUPABASE_URL");
  const previousKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  Deno.env.set("SUPABASE_URL", "https://project.test");
  Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-service-key");
  try {
    await action();
  } finally {
    restoreEnv("SUPABASE_URL", previousUrl);
    restoreEnv("SUPABASE_SERVICE_ROLE_KEY", previousKey);
  }
}

function restoreEnv(name: string, value: string | undefined): void {
  if (value === undefined) Deno.env.delete(name);
  else Deno.env.set(name, value);
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
