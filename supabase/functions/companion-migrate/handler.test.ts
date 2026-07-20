import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import type { PilotPersonaProgram } from "../_shared/companion/registry.ts";
import type { CompanionMigrationRequest } from "./contract.ts";
import { createCompanionMigrationHandler } from "./handler.ts";
import type {
  CompanionMigrationRepository,
  CompanionMigrationResult,
} from "./repository.ts";

const userId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const conversationId = "11111111-1111-4111-8111-111111111111";
const messageId = "22222222-2222-4222-8222-222222222222";

Deno.test("authenticated migration returns counts and a server conversation mapping", async () => {
  const repository = new FakeMigrationRepository();
  const handler = createCompanionMigrationHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    now: () => new Date("2026-07-19T12:00:00Z"),
  });
  const response = await handler(migrationRequest("aries-amara"));
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(repository.calls, 1);
  assertEquals(repository.lastUserId, userId);
  assertEquals(repository.lastConsentAt, "2026-07-19T12:00:00.000Z");
  assertEquals(body.counts.messagesImported, 1);
  assertEquals(body.conversations[0].legacyConversationId, conversationId);
  assertEquals(
    body.conversations[0].conversationId,
    "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
  );
  assertEquals(
    body.localDataDisposition,
    "retain_until_server_counts_are_verified",
  );
});

Deno.test("unknown or display-name identities are rejected without discarding local data", async () => {
  const repository = new FakeMigrationRepository();
  const handler = createCompanionMigrationHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    now: () => new Date("2026-07-19T12:00:00Z"),
  });
  for (const companionId of ["Amara", "aries-cassian", "custom-ember"]) {
    const response = await handler(migrationRequest(companionId));
    const body = await response.json();
    assertEquals(response.status, 422);
    assertEquals(body.error.code, "unmatched_legacy_companion");
    assertEquals(body.preserveLocal, true);
    assertEquals(body.localDataDisposition, "unmatched_read_only_local");
  }
  assertEquals(repository.calls, 0);
});

Deno.test("authentication happens before import and raw prompt fields never reach the repository", async () => {
  const repository = new FakeMigrationRepository();
  const handler = createCompanionMigrationHandler({
    authenticate: () =>
      Promise.reject(
        new CompanionRuntimeError(
          "auth_required",
          "Please sign in again before continuing.",
          401,
        ),
      ),
    repository,
    now: () => new Date(),
  });
  const unauthenticated = await handler(migrationRequest("aries-amara"));
  assertEquals(unauthenticated.status, 401);
  assertEquals(repository.calls, 0);

  const authenticatedHandler = createCompanionMigrationHandler({
    authenticate: () => Promise.resolve({ id: userId }),
    repository,
    now: () => new Date(),
  });
  const body = migrationBody("aries-amara");
  body.prompt = "forged persona";
  const promptResponse = await authenticatedHandler(
    new Request(
      "https://example.test/functions/v1/companion-migrate",
      {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(body),
      },
    ),
  );
  const error = await promptResponse.json();
  assertEquals(promptResponse.status, 400);
  assertEquals(error.error.code, "invalid_payload");
  assertEquals(error.preserveLocal, true);
  assertEquals(repository.calls, 0);
});

class FakeMigrationRepository implements CompanionMigrationRepository {
  calls = 0;
  lastUserId: string | null = null;
  lastConsentAt: string | null = null;

  importConsentedThreads(
    userIdValue: string,
    request: CompanionMigrationRequest,
    persona: PilotPersonaProgram,
    consentedAt: string,
  ): Promise<CompanionMigrationResult> {
    this.calls += 1;
    this.lastUserId = userIdValue;
    this.lastConsentAt = consentedAt;
    return Promise.resolve({
      companionId: persona.id,
      relationshipId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
      counts: {
        relationshipsImported: 1,
        relationshipsExisting: 0,
        conversationsImported: 1,
        conversationsExisting: 0,
        messagesImported: request.conversations[0].messages.length,
        messagesExisting: 0,
      },
      conversations: [{
        legacyConversationId: request.conversations[0].legacyConversationId,
        conversationId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        importedMessages: request.conversations[0].messages.length,
        existingMessages: 0,
      }],
    });
  }
}

function migrationRequest(companionId: string): Request {
  return new Request("https://example.test/functions/v1/companion-migrate", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(migrationBody(companionId)),
  });
}

function migrationBody(companionId: string): Record<string, unknown> {
  return {
    companionId,
    migrationVersion: 1,
    syncConsent: true,
    conversations: [{
      legacyConversationId: conversationId,
      title: null,
      messages: [{
        legacyMessageId: messageId,
        role: "user",
        content: "Historical message",
        createdAt: "2026-07-18T12:00:00Z",
      }],
    }],
  };
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
