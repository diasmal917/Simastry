import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  type CompanionRest,
  CompanionRestError,
  type CompanionTable,
  type RestRequest,
} from "../_shared/companion/rest.ts";
import { getPilotPersona } from "../_shared/companion/registry.ts";
import type { CompanionChatRequest } from "./contract.ts";
import {
  classifyExistingTurn,
  type StoredMessage,
  SupabaseCompanionChatRepository,
} from "./repository.ts";

const request: CompanionChatRequest = Object.freeze({
  companionId: "aries-amara",
  conversationId: "11111111-1111-4111-8111-111111111111",
  clientMessageId: "22222222-2222-4222-8222-222222222222",
  message: "Help me say this clearly.",
  stream: false,
});
const requestFingerprint = Object.freeze({
  keyId: "v1" as const,
  value: "a".repeat(64),
});
const usageEventId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";

Deno.test("completed companion response is idempotently replayed", () => {
  const disposition = classifyExistingTurn(
    [
      messageRow("user", "complete", request.message),
      {
        ...messageRow(
          "companion",
          "complete",
          "Try one clean sentence.",
          "model-1",
        ),
        usage_event_id: usageEventId,
        safety_metadata: {
          provider_usage: { input_tokens: 13, output_tokens: 6 },
        },
      },
    ],
    request,
    requestFingerprint,
  );
  assertEquals(disposition, {
    kind: "replay",
    text: "Try one clean sentence.",
    modelVersion: "model-1",
    usageEventId,
    usage: {
      modelProvider: "anthropic",
      inputTokens: 13,
      outputTokens: 6,
      responseCharacters: "Try one clean sentence.".length,
      tokenSource: "provider",
    },
  });
});

Deno.test("same id with changed text or conversation is rejected", () => {
  assertRuntimeCode(
    () =>
      classifyExistingTurn([
        messageRow("user", "failed", "Different text"),
      ], request),
    "idempotency_conflict",
  );
  assertRuntimeCode(
    () =>
      classifyExistingTurn(
        [{
          ...messageRow("user", "failed", request.message),
          request_fingerprint: requestFingerprint.value,
          request_fingerprint_key_id: requestFingerprint.keyId,
        }],
        request,
        { keyId: "v1", value: "b".repeat(64) },
      ),
    "idempotency_conflict",
  );
  assertRuntimeCode(
    () =>
      classifyExistingTurn([
        {
          ...messageRow("user", "failed", request.message),
          conversation_id: "33333333-3333-4333-8333-333333333333",
        },
      ], request),
    "idempotency_conflict",
  );
});

Deno.test("fresh pending turns block duplicate generation; failed and stale turns resume", () => {
  assertRuntimeCode(
    () =>
      classifyExistingTurn(
        [
          messageRow("user", "pending", request.message),
        ],
        request,
        null,
        Date.now(),
      ),
    "turn_in_progress",
  );
  assertEquals(
    classifyExistingTurn([
      messageRow("user", "failed", request.message),
    ], request).kind,
    "resume",
  );
  const stale = {
    ...messageRow("user", "streaming", request.message),
    updated_at: new Date(Date.now() - 180_000).toISOString(),
  };
  assertEquals(classifyExistingTurn([stale], request).kind, "resume");
});

Deno.test("resume claims CAS the observed timestamp and context failures mark the turn failed", async () => {
  const failed = {
    ...messageRow("user", "streaming", request.message),
    updated_at: "2026-07-19T12:00:00.000Z",
  };
  const rest = new ScriptedRest((table, call) => {
    if (table === "companion_personas") {
      return [{
        id: "aries-amara",
        status: "pilot_ready",
        active_persona_version: "pilot-2026-07-19.1",
      }];
    }
    if (table === "user_companion_relationships") {
      return [{
        id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
        support_preferences: {},
      }];
    }
    if (table === "companion_conversations" && !call.method) {
      return [{
        id: request.conversationId,
        user_id: failed.user_id,
        relationship_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
        companion_id: request.companionId,
        status: "active",
        persona_version: "pilot-2026-07-19.1",
      }];
    }
    if (table === "companion_messages" && !call.method) {
      if (call.query?.client_message_id === `eq.${request.clientMessageId}`) {
        return [failed];
      }
      return [];
    }
    if (
      table === "companion_messages" && call.method === "PATCH" &&
      bodyState(call) === "pending"
    ) {
      return [{ ...failed, delivery_state: "pending" }];
    }
    if (table === "user_birth_charts") {
      throw new CompanionRestError(503);
    }
    if (
      table === "companion_memories" || table === "relationship_people" ||
      table === "communication_outcomes"
    ) {
      return [];
    }
    return undefined;
  });
  const repository = new SupabaseCompanionChatRepository(rest);
  await assertRejects(() =>
    repository.prepare(
      failed.user_id,
      request,
      getPilotPersona(request.companionId),
      requestFingerprint,
    )
  );

  const claim = rest.calls.find((call) =>
    bodyState(call.request) === "pending"
  );
  assertEquals(claim?.request.query?.updated_at, `eq.${failed.updated_at}`);
  assert(
    rest.calls.some((call) => bodyState(call.request) === "streaming"),
  );
  assert(rest.calls.some((call) => bodyState(call.request) === "failed"));
});

Deno.test("committed companion responses survive deferred bookkeeping failures", async () => {
  const rest = new ScriptedRest((table, call) => {
    if (table === "companion_messages" && call.method === "POST") return [];
    if (call.method === "PATCH") throw new CompanionRestError(503);
    return undefined;
  });
  const repository = new SupabaseCompanionChatRepository(rest);
  const result = await repository.complete({
    userId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    request,
    persona: getPilotPersona(request.companionId),
    userMessageId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    text: "A durably committed answer.",
    modelProvider: "anthropic",
    modelVersion: "test-model",
    safetyCategory: "none",
    safetyOutputReplaced: false,
    usageEventId,
    requestFingerprint,
    usage: { inputTokens: 7, outputTokens: 5 },
  });
  assertEquals(result.replayed, false);
  assertEquals(result.text, "A durably committed answer.");
  assertEquals(result.usageEventId, usageEventId);
  const responseInsert = rest.calls.find((call) =>
    call.table === "companion_messages" && call.request.method === "POST"
  );
  assertEquals(
    bodyValue(responseInsert?.request, "usage_event_id"),
    usageEventId,
  );
  assert(
    JSON.stringify(responseInsert?.request.body).includes(
      `"usage_accounting":{"response_characters":${"A durably committed answer.".length},"token_source":"provider"}`,
    ),
  );
  assertEquals(
    rest.calls.filter((call) => call.request.method === "PATCH").length,
    4,
  );
});

function messageRow(
  role: "user" | "companion",
  state: StoredMessage["delivery_state"],
  content: string,
  modelVersion: string | null = null,
): StoredMessage {
  const timestamp = new Date().toISOString();
  return {
    id: role === "user"
      ? "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
      : "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    conversation_id: request.conversationId,
    user_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    companion_id: request.companionId,
    client_message_id: request.clientMessageId,
    role,
    content,
    delivery_state: state,
    persona_version: "pilot-2026-07-19.1",
    model_provider: role === "companion" ? "anthropic" : null,
    model_version: modelVersion,
    usage_event_id: null,
    request_fingerprint: null,
    request_fingerprint_key_id: null,
    safety_metadata: null,
    updated_at: timestamp,
    created_at: timestamp,
  };
}

type RecordedCall = Readonly<{
  table: CompanionTable;
  request: RestRequest;
}>;

class ScriptedRest implements CompanionRest {
  calls: RecordedCall[] = [];
  readonly #handler: (table: CompanionTable, request: RestRequest) => unknown;

  constructor(
    handler: (table: CompanionTable, request: RestRequest) => unknown,
  ) {
    this.#handler = handler;
  }

  request<T>(table: CompanionTable, request: RestRequest = {}): Promise<T> {
    this.calls.push({ table, request });
    try {
      return Promise.resolve(this.#handler(table, request) as T);
    } catch (error) {
      return Promise.reject(error);
    }
  }
}

function bodyState(request: RestRequest): string | null {
  const body = request.body;
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  const state = (body as Record<string, unknown>).delivery_state;
  return typeof state === "string" ? state : null;
}

function bodyValue(request: RestRequest | undefined, key: string): unknown {
  const body = request?.body;
  if (!body || typeof body !== "object" || Array.isArray(body)) return null;
  return (body as Record<string, unknown>)[key];
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
