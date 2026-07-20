import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import type {
  CompanionUsageFinalization,
  CompanionUsageLedger,
  CompanionUsageReservationRequest,
} from "../_shared/companion/usage.ts";
import { createCompanionDecodeHandler } from "./handler.ts";
import type { CompanionDecodeRepository } from "./repository.ts";

const userId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const personId = "11111111-1111-4111-8111-111111111111";
const usageEventId = "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee";

Deno.test("Decode authorizes People context, redacts again, and never persists message text", async () => {
  let authorizationCalls = 0;
  let providerUser = "";
  const usageLedger = new FakeUsageLedger();
  const repository: CompanionDecodeRepository = {
    authorizeAndLoad: () => {
      authorizationCalls += 1;
      return Promise.resolve(authorizedContext());
    },
  };
  const handler = createCompanionDecodeHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    provider: {
      generate: (request) => {
        providerUser = request.user;
        return Promise.resolve({
          text: JSON.stringify({
            tone: "Brief and open",
            likelyMeaning: "They may want to continue the conversation later.",
            plausibleAlternative:
              "They could be checking whether the timing works for you.",
            whatNotToAssume:
              "Do not assume rejection or certainty about their motive.",
            replyDrafts: [
              "Yes — what time works?",
              "Sure. Is everything okay?",
            ],
          }),
          provider: "anthropic",
          model: "test-model",
          usage: { inputTokens: 29, outputTokens: 13 },
        });
      },
    },
    rateLimiter: { check: () => {} },
    usageLedger,
  });
  const response = await handler(decodeRequest(
    "Email me at person@example.com or call +1 415 555 0123 later.",
  ));
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(authorizationCalls, 1);
  assertEquals(body.messagePersisted, false);
  assertEquals(body.personaVersion, 1);
  assertEquals(body.modelVersion, "test-model");
  assertEquals(body.usageEventId, usageEventId);
  assert(!providerUser.includes("person@example.com"));
  assert(!providerUser.includes("415 555 0123"));
  assert(providerUser.includes("[email]"));
  assert(providerUser.includes("[phone]"));
  assertEquals(usageLedger.reservations[0]?.feature, "companion_decode");
  assertEquals(usageLedger.reservations[0]?.requestCharacters, 61);
  assert(!JSON.stringify(usageLedger.reservations[0]).includes("message"));
  assert(!JSON.stringify(usageLedger.reservations[0]).includes(personId));
  assertEquals(usageLedger.finalizations[0]?.status, "success");
  assertEquals(usageLedger.finalizations[0]?.inputTokens, 29);
  assertEquals(usageLedger.finalizations[0]?.outputTokens, 13);
});

Deno.test("unauthorized People IDs fail before provider generation", async () => {
  let providerCalls = 0;
  const usageLedger = new FakeUsageLedger();
  const handler = createCompanionDecodeHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository: {
      authorizeAndLoad: () =>
        Promise.reject(
          new CompanionRuntimeError(
            "person_not_authorized",
            "Choose an authorized People record.",
            404,
          ),
        ),
    },
    provider: {
      generate: () => {
        providerCalls += 1;
        throw new Error("should not run");
      },
    },
    rateLimiter: { check: () => {} },
    usageLedger,
  });
  const response = await handler(decodeRequest("Can we talk?"));
  const body = await response.json();
  assertEquals(response.status, 404);
  assertEquals(body.error.code, "person_not_authorized");
  assertEquals(providerCalls, 0);
  assertEquals(usageLedger.reservations.length, 0);
});

Deno.test("coercion Decode is deterministic, safe, and still requires authorization", async () => {
  let authorizationCalls = 0;
  let providerCalls = 0;
  const usageLedger = new FakeUsageLedger();
  const handler = createCompanionDecodeHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository: {
      authorizeAndLoad: () => {
        authorizationCalls += 1;
        return Promise.resolve(authorizedContext());
      },
    },
    provider: {
      generate: () => {
        providerCalls += 1;
        throw new Error("should not run");
      },
    },
    rateLimiter: { check: () => {} },
    usageLedger,
  });
  const response = await handler(
    decodeRequest("I threatened you and will not let you leave."),
  );
  const body = await response.json();
  assertEquals(response.status, 200);
  assertEquals(authorizationCalls, 1);
  assertEquals(providerCalls, 0);
  assertEquals(body.messagePersisted, false);
  assert(body.whatNotToAssume.includes("confrontation"));
  assertEquals(usageLedger.finalizations[0]?.tokenSource, "deterministic");
  assertEquals(usageLedger.finalizations[0]?.inputTokens, 0);
  assertEquals(usageLedger.finalizations[0]?.outputTokens, 0);
});

Deno.test("Decode provider failures finalize the durable reservation without persisting text", async () => {
  const usageLedger = new FakeUsageLedger();
  const handler = createCompanionDecodeHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository: {
      authorizeAndLoad: () => Promise.resolve(authorizedContext()),
    },
    provider: {
      generate: () =>
        Promise.reject(
          new CompanionRuntimeError(
            "provider_unavailable",
            "Try again.",
            502,
          ),
        ),
    },
    rateLimiter: { check: () => {} },
    usageLedger,
  });
  const response = await handler(decodeRequest("A private failed request."));
  assertEquals(response.status, 502);
  assertEquals(usageLedger.reservations.length, 1);
  assertEquals(usageLedger.finalizations[0]?.status, "failed");
  assertEquals(
    usageLedger.finalizations[0]?.errorCode,
    "provider_unavailable",
  );
  assert(!JSON.stringify(usageLedger.finalizations[0]).includes("private"));
});

Deno.test("Decode never returns generated output when durable finalization is exhausted", async () => {
  const usageLedger = new AlwaysFailingUsageLedger();
  const handler = createCompanionDecodeHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository: {
      authorizeAndLoad: () => Promise.resolve(authorizedContext()),
    },
    provider: {
      generate: () =>
        Promise.resolve({
          text: JSON.stringify({
            tone: "Private generated tone",
            likelyMeaning: "They may want to continue the conversation later.",
            plausibleAlternative:
              "They could be checking whether the timing works for you.",
            whatNotToAssume:
              "Do not assume rejection or certainty about their motive.",
            replyDrafts: [
              "Yes — what time works?",
              "Sure. Is everything okay?",
            ],
          }),
          provider: "anthropic",
          model: "test-model",
          usage: { inputTokens: 9, outputTokens: 4 },
        }),
    },
    rateLimiter: { check: () => {} },
    usageLedger,
  });

  const response = await handler(decodeRequest("Never persist this text."));
  const body = await response.json();
  assertEquals(response.status, 503);
  assertEquals(body.error.code, "backend_unavailable");
  assertEquals(usageLedger.finalizations.length, 6);
  assert(
    usageLedger.finalizations.slice(0, 3).every((row) =>
      row.status === "success"
    ),
  );
  assert(
    usageLedger.finalizations.slice(3).every((row) => row.status === "failed"),
  );
  assert(!JSON.stringify(body).includes("Private generated tone"));
  assert(!JSON.stringify(usageLedger.finalizations).includes("Never persist"));
});

function authorizedContext() {
  return Object.freeze({
    supportPreferences: { tone: "warm" },
    userChart: { sun_estimate: { signs: ["libra"] } },
    person: Object.freeze({
      relationshipKind: "friend",
      pronouns: null,
      birthChart: { sun: "taurus" },
      notes: null,
      communicationGuide: { repair: "allow time" },
    }),
  });
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

class AlwaysFailingUsageLedger extends FakeUsageLedger {
  override finalize(
    finalization: CompanionUsageFinalization,
  ): Promise<void> {
    this.finalizations.push(finalization);
    return Promise.reject(new Error("accounting unavailable"));
  }
}

function decodeRequest(message: string): Request {
  return new Request("https://example.test/functions/v1/companion-decode", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      companionId: "pisces-zev",
      personId,
      message,
      persistMessage: false,
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
