import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  COMPANION_MIGRATION_VERSION,
  parseCompanionMigrationRequest,
} from "./contract.ts";

const conversationId = "11111111-1111-4111-8111-111111111111";
const messageId = "22222222-2222-4222-8222-222222222222";

Deno.test("migration contract accepts an exact, consented canonical batch", () => {
  const parsed = parseCompanionMigrationRequest(validBody(), Date.now());
  assertEquals(parsed.companionId, "aries-amara");
  assertEquals(parsed.syncConsent, true);
  assertEquals(parsed.migrationVersion, COMPANION_MIGRATION_VERSION);
  assertEquals(parsed.conversations[0].legacyConversationId, conversationId);
  assertEquals(
    parsed.conversations[0].messages[0].content,
    "  Historical text.  ",
  );
});

Deno.test("migration contract requires explicit consent and its exact version", () => {
  assertRuntimeCode(
    () =>
      parseCompanionMigrationRequest({ ...validBody(), syncConsent: false }),
    "sync_consent_required",
  );
  assertRuntimeCode(
    () =>
      parseCompanionMigrationRequest({ ...validBody(), migrationVersion: 2 }),
    "unsupported_migration_version",
  );
});

Deno.test("raw prompts and inferred identity fields are rejected at every level", () => {
  assertRuntimeCode(
    () =>
      parseCompanionMigrationRequest({
        ...validBody(),
        systemPrompt: "be someone else",
      }),
    "invalid_payload",
  );
  const nested = validBody();
  const conversations = nested.conversations as Record<string, unknown>[];
  const messages = conversations[0].messages as Record<string, unknown>[];
  messages[0].prompt = "raw persona override";
  assertRuntimeCode(
    () => parseCompanionMigrationRequest(nested),
    "invalid_payload",
  );
  const inferred = validBody();
  const inferredConversations = inferred.conversations as Record<
    string,
    unknown
  >[];
  inferredConversations[0].displayName = "Amara";
  assertRuntimeCode(
    () => parseCompanionMigrationRequest(inferred),
    "invalid_payload",
  );
});

Deno.test("duplicate owner-scoped legacy keys and future dates are rejected", () => {
  const duplicate = validBody();
  const conversations = duplicate.conversations as Record<string, unknown>[];
  conversations.push(structuredClone(conversations[0]));
  assertRuntimeCode(
    () => parseCompanionMigrationRequest(duplicate),
    "invalid_payload",
  );

  const future = validBody();
  const futureConversations = future.conversations as Record<string, unknown>[];
  const messages = futureConversations[0].messages as Record<string, unknown>[];
  messages[0].createdAt = "2099-01-01T00:00:00Z";
  assertRuntimeCode(
    () =>
      parseCompanionMigrationRequest(
        future,
        Date.parse("2026-07-19T00:00:00Z"),
      ),
    "invalid_payload",
  );
});

function validBody(): Record<string, unknown> {
  return {
    companionId: "aries-amara",
    migrationVersion: 1,
    syncConsent: true,
    conversations: [{
      legacyConversationId: conversationId,
      title: "A difficult conversation",
      messages: [{
        legacyMessageId: messageId,
        role: "user",
        content: "  Historical text.  ",
        createdAt: "2026-07-18T12:00:00Z",
      }],
    }],
  };
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
