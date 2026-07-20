import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import type { TextGenerationRequest } from "../_shared/companion/provider.ts";
import type {
  CompanionUsageFinalization,
  CompanionUsageLedger,
  CompanionUsageReservationRequest,
} from "../_shared/companion/usage.ts";
import { createCompanionChatHandler } from "./handler.ts";
import type {
  CompanionChatRepository,
  CompletedChatTurn,
  PreparedChatTurn,
} from "./repository.ts";

const userId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const conversationId = "11111111-1111-4111-8111-111111111111";
const clientMessageId = "22222222-2222-4222-8222-222222222222";
const usageEventId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";
const requestFingerprint = Object.freeze({
  keyId: "v1" as const,
  value: "f".repeat(64),
});
const fingerprintRequest = () => Promise.resolve(requestFingerprint);

Deno.test("chat handler persists one claimed safe turn and emits the exact stream envelope", async () => {
  const repository = new FakeChatRepository({
    kind: "claimed",
    userMessageId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    relationshipId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    context: {
      supportPreferences: { tone: "warm" },
      birthChart: { sun_estimate: { signs: ["aries"] } },
      memories: [],
      transcript: [],
      selectedPerson: null,
    },
  });
  const usageLedger = new FakeUsageLedger();
  let providerCalls = 0;
  const handler = createCompanionChatHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    provider: {
      generate: (_request: TextGenerationRequest) => {
        providerCalls += 1;
        return Promise.resolve({
          text: "Name what you know, then ask one direct question.",
          provider: "anthropic",
          model: "test-model",
          usage: { inputTokens: 17, outputTokens: 9 },
        });
      },
    },
    rateLimiter: { check: () => {} },
    fingerprintRequest,
    usageLedger,
  });

  const response = await handler(chatRequest("Help me get clarity.", true));
  assertEquals(response.status, 200);
  const body = await response.text();
  assert(body.indexOf("event: meta") < body.indexOf("event: delta"));
  assert(body.indexOf("event: delta") < body.indexOf("event: done"));
  assert(body.includes('"companionId":"aries-amara"'));
  assert(body.includes('"personaVersion":1'));
  assert(body.includes('"messagePersisted":true'));
  assert(body.includes(`"usageEventId":"${usageEventId}"`));
  assertEquals(providerCalls, 1);
  assertEquals(repository.completeCalls, 1);
  assertEquals(usageLedger.reservations.length, 1);
  assertEquals(usageLedger.finalizations[0]?.status, "success");
  assertEquals(usageLedger.finalizations[0]?.inputTokens, 17);
  assertEquals(usageLedger.finalizations[0]?.outputTokens, 9);
  assertEquals(
    repository.lastCompletion?.request.clientMessageId,
    clientMessageId,
  );
  assertEquals(repository.lastCompletion?.usageEventId, usageEventId);
  assertEquals(
    repository.lastCompletion?.requestFingerprint,
    requestFingerprint,
  );
  assertEquals(repository.lastFingerprint, requestFingerprint);
});

Deno.test("idempotent replay never calls provider or writes another response", async () => {
  const repository = new FakeChatRepository({
    kind: "replay",
    text: "Previously persisted answer.",
    modelVersion: "persisted-model",
    usageEventId,
    usage: {
      modelProvider: "anthropic",
      inputTokens: 11,
      outputTokens: 7,
      responseCharacters: 28,
      tokenSource: "provider",
    },
  });
  const usageLedger = new FakeUsageLedger();
  let providerCalls = 0;
  const handler = createCompanionChatHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    provider: {
      generate: () => {
        providerCalls += 1;
        throw new Error("should not run");
      },
    },
    rateLimiter: { check: () => {} },
    fingerprintRequest,
    usageLedger,
  });
  const response = await handler(chatRequest("Same message.", false));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(body.text, "Previously persisted answer.");
  assertEquals(body.replayed, true);
  assertEquals(body.usageEventId, usageEventId);
  assertEquals(providerCalls, 0);
  assertEquals(repository.completeCalls, 0);
  assertEquals(usageLedger.reservations.length, 0);
  assertEquals(usageLedger.finalizations[0]?.status, "success");
  assertEquals(usageLedger.finalizations[0]?.inputTokens, 11);
});

Deno.test("dependency and romance requests use deterministic boundary without provider", async () => {
  const repository = new FakeChatRepository({
    kind: "claimed",
    userMessageId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    relationshipId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    context: {
      supportPreferences: {},
      birthChart: null,
      memories: [],
      transcript: [],
      selectedPerson: null,
    },
  });
  const usageLedger = new FakeUsageLedger();
  let providerCalls = 0;
  const handler = createCompanionChatHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    provider: {
      generate: () => {
        providerCalls += 1;
        throw new Error("should not run");
      },
    },
    rateLimiter: { check: () => {} },
    fingerprintRequest,
    usageLedger,
  });
  const response = await handler(
    chatRequest("Be my girlfriend. I only need you.", false),
  );
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(providerCalls, 0);
  assert(body.text.includes("not a romantic partner"));
  assertEquals(repository.lastCompletion?.modelProvider, "simastry_safety");
  assertEquals(usageLedger.finalizations[0]?.tokenSource, "deterministic");
  assertEquals(usageLedger.finalizations[0]?.inputTokens, 0);
  assertEquals(usageLedger.finalizations[0]?.outputTokens, 0);
});

Deno.test("chat redacts direct identifiers before persistence and provider prompts", async () => {
  const repository = new FakeChatRepository({
    kind: "claimed",
    userMessageId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    relationshipId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    context: {
      supportPreferences: {},
      birthChart: null,
      memories: [],
      transcript: [],
      selectedPerson: null,
    },
  });
  let providerPrompt = "";
  const handler = createCompanionChatHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    provider: {
      generate: (providerRequest) => {
        providerPrompt = providerRequest.user;
        return Promise.resolve({
          text: "Use a private channel.",
          provider: "anthropic",
          model: "test-model",
          usage: { inputTokens: 8, outputTokens: 4 },
        });
      },
    },
    rateLimiter: { check: () => {} },
    fingerprintRequest,
    usageLedger: new FakeUsageLedger(),
  });
  const raw =
    "Tell @private_handle at person@example.com or +1 415 555 0123; see https://secret.example/path";
  const response = await handler(chatRequest(raw, false));
  assertEquals(response.status, 200);
  const persisted = repository.lastPreparationRequest?.message ?? "";
  for (
    const secret of [
      "@private_handle",
      "person@example.com",
      "415 555 0123",
      "secret.example",
    ]
  ) {
    assert(!persisted.includes(secret));
    assert(!providerPrompt.includes(secret));
  }
});

Deno.test("a limiter failure after claim finalizes usage and marks the turn failed", async () => {
  const repository = new FakeChatRepository({
    kind: "claimed",
    userMessageId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    relationshipId: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    context: {
      supportPreferences: {},
      birthChart: null,
      memories: [],
      transcript: [],
      selectedPerson: null,
    },
  });
  const usageLedger = new FakeUsageLedger();
  const handler = createCompanionChatHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    provider: {
      generate: () => {
        throw new Error("provider must not run");
      },
    },
    rateLimiter: {
      check: () => {
        throw new CompanionRuntimeError(
          "ai_usage_limit",
          "Please wait.",
          429,
        );
      },
    },
    fingerprintRequest,
    usageLedger,
  });
  const response = await handler(chatRequest("A claimed turn.", false));
  assertEquals(response.status, 429);
  assertEquals(repository.failCalls, 1);
  assertEquals(usageLedger.finalizations[0]?.status, "failed");
  assertEquals(usageLedger.finalizations[0]?.errorCode, "ai_usage_limit");
});

class FakeChatRepository implements CompanionChatRepository {
  readonly #preparation: PreparedChatTurn;
  completeCalls = 0;
  failCalls = 0;
  lastPreparationRequest:
    | Parameters<CompanionChatRepository["prepare"]>[1]
    | null = null;
  lastFingerprint: Parameters<CompanionChatRepository["prepare"]>[3] | null =
    null;
  lastCompletion: Parameters<CompanionChatRepository["complete"]>[0] | null =
    null;

  constructor(preparation: PreparedChatTurn) {
    this.#preparation = preparation;
  }

  prepare(
    _userId: string,
    request: Parameters<CompanionChatRepository["prepare"]>[1],
    _persona: Parameters<CompanionChatRepository["prepare"]>[2],
    fingerprint: Parameters<CompanionChatRepository["prepare"]>[3],
  ): Promise<PreparedChatTurn> {
    this.lastPreparationRequest = request;
    this.lastFingerprint = fingerprint;
    return Promise.resolve(this.#preparation);
  }

  complete(
    args: Parameters<CompanionChatRepository["complete"]>[0],
  ): Promise<CompletedChatTurn> {
    this.completeCalls += 1;
    this.lastCompletion = args;
    return Promise.resolve({
      text: args.text,
      modelVersion: args.modelVersion,
      usageEventId: args.usageEventId,
      replayed: false,
    });
  }

  fail(): Promise<void> {
    this.failCalls += 1;
    return Promise.resolve();
  }
}

class FakeUsageLedger implements CompanionUsageLedger {
  reservations: CompanionUsageReservationRequest[] = [];
  finalizations: CompanionUsageFinalization[] = [];

  reserve(
    request: CompanionUsageReservationRequest,
  ): Promise<Readonly<{ id: string }>> {
    this.reservations.push(request);
    return Promise.resolve(Object.freeze({ id: usageEventId }));
  }

  finalize(finalization: CompanionUsageFinalization): Promise<void> {
    this.finalizations.push(finalization);
    return Promise.resolve();
  }
}

function chatRequest(message: string, stream: boolean): Request {
  return new Request("https://example.test/functions/v1/companion-chat", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      companionId: "aries-amara",
      conversationId,
      clientMessageId,
      message,
      stream,
    }),
  });
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
