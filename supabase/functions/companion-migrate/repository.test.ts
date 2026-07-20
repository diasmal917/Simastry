import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import type {
  CompanionRest,
  CompanionTable,
  RestRequest,
} from "../_shared/companion/rest.ts";
import { getPilotPersona } from "../_shared/companion/registry.ts";
import {
  type CompanionMigrationRequest,
  parseCompanionMigrationRequest,
} from "./contract.ts";
import {
  assertConversationImportMatches,
  assertMessageImportMatches,
  LEGACY_PERSONA_VERSION,
  type MigrationConversationRow,
  type MigrationMessageRow,
  type MigrationRelationshipRow,
  SupabaseCompanionMigrationRepository,
} from "./repository.ts";

const firstUser = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const secondUser = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb";
const consentedAt = "2026-07-19T12:00:00.000Z";

Deno.test("canonical imports are idempotent and client IDs remain owner-scoped", async () => {
  const rest = new MemoryCompanionRest();
  const repository = new SupabaseCompanionMigrationRepository(rest);
  const request = migrationRequest();
  const persona = getPilotPersona(request.companionId);

  const first = await repository.importConsentedThreads(
    firstUser,
    request,
    persona,
    consentedAt,
  );
  assertEquals(first.counts, {
    relationshipsImported: 1,
    relationshipsExisting: 0,
    conversationsImported: 1,
    conversationsExisting: 0,
    messagesImported: 2,
    messagesExisting: 0,
  });
  assertEquals(rest.messages[0].persona_version, LEGACY_PERSONA_VERSION);
  assertEquals(rest.messages[0].is_legacy_import, true);
  assertEquals(rest.messages[0].companion_id, "aries-amara");

  const replay = await repository.importConsentedThreads(
    firstUser,
    request,
    persona,
    consentedAt,
  );
  assertEquals(replay.counts.messagesImported, 0);
  assertEquals(replay.counts.messagesExisting, 2);
  assertEquals(rest.messages.length, 2);

  const otherOwner = await repository.importConsentedThreads(
    secondUser,
    request,
    persona,
    consentedAt,
  );
  assertEquals(otherOwner.counts.messagesImported, 2);
  assert(
    first.conversations[0].conversationId !==
      otherOwner.conversations[0].conversationId,
  );
  assertEquals(rest.messages.length, 4);
  assertEquals(
    new Set(rest.messages.map((message) => message.id)).size,
    4,
  );
});

Deno.test("a repeated owner-scoped message key cannot change content or thread", async () => {
  const rest = new MemoryCompanionRest();
  const repository = new SupabaseCompanionMigrationRepository(rest);
  const request = migrationRequest();
  const persona = getPilotPersona(request.companionId);
  await repository.importConsentedThreads(
    firstUser,
    request,
    persona,
    consentedAt,
  );

  const changed = migrationRequest("Changed historical text");
  await assertRuntimeCodeAsync(
    () =>
      repository.importConsentedThreads(
        firstUser,
        changed,
        persona,
        consentedAt,
      ),
    "legacy_message_conflict",
  );
  assertEquals(rest.messages.length, 2);
});

Deno.test("ownership and provenance assertions reject forged service-role rows", () => {
  const request = migrationRequest();
  const importedConversation = request.conversations[0];
  const conversation = conversationRow({
    user_id: secondUser,
  });
  assertRuntimeCode(
    () =>
      assertConversationImportMatches(
        conversation,
        firstUser,
        "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
        "aries-amara",
        1,
        importedConversation,
      ),
    "legacy_id_conflict",
  );

  const message = messageRow({ is_legacy_import: false });
  assertRuntimeCode(
    () =>
      assertMessageImportMatches(
        message,
        firstUser,
        "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
        "aries-amara",
        importedConversation.messages[0],
      ),
    "legacy_message_conflict",
  );
});

class MemoryCompanionRest implements CompanionRest {
  readonly relationships: MigrationRelationshipRow[] = [];
  readonly conversations: MigrationConversationRow[] = [];
  readonly messages: MigrationMessageRow[] = [];
  #nextId = 1;

  request<T>(table: CompanionTable, request: RestRequest = {}): Promise<T> {
    const method = request.method ?? "GET";
    if (table === "companion_personas") {
      return Promise.resolve([{
        id: "aries-amara",
        status: "pilot_ready",
        active_persona_version: "pilot-2026-07-19.1",
      }] as T);
    }
    if (table === "user_companion_relationships") {
      if (method === "GET") {
        return Promise.resolve(
          this.relationships.filter((row) => matches(row, request.query)) as T,
        );
      }
      if (method === "POST") {
        const body = request.body as Record<string, unknown>;
        const existing = this.relationships.find((row) =>
          row.user_id === body.user_id && row.companion_id === body.companion_id
        );
        if (existing) throw new Error("Unexpected relationship race in fake");
        const row: MigrationRelationshipRow = {
          id: this.nextUuid(),
          user_id: String(body.user_id),
          companion_id: String(body.companion_id),
          status: String(body.status),
        };
        this.relationships.push(row);
        return Promise.resolve([row] as T);
      }
    }
    if (table === "companion_conversations") {
      if (method === "GET") {
        return Promise.resolve(
          this.conversations.filter((row) => matches(row, request.query)) as T,
        );
      }
      if (method === "POST") {
        const body = request.body as Record<string, unknown>;
        const row: MigrationConversationRow = {
          id: this.nextUuid(),
          user_id: String(body.user_id),
          relationship_id: String(body.relationship_id),
          companion_id: String(body.companion_id),
          status: String(body.status),
          title: body.title === null ? null : String(body.title),
          persona_version: String(body.persona_version),
          legacy_record_id: String(body.legacy_record_id),
          migration_version: Number(body.migration_version),
          sync_consent_at: String(body.sync_consent_at),
        };
        this.conversations.push(row);
        return Promise.resolve([row] as T);
      }
      if (method === "PATCH") return Promise.resolve(undefined as T);
    }
    if (table === "companion_messages") {
      if (method === "GET") {
        return Promise.resolve(
          this.messages.filter((row) => matches(row, request.query)) as T,
        );
      }
      if (method === "POST") {
        const body = request.body as Record<string, unknown>;
        const row: MigrationMessageRow = {
          id: this.nextUuid(),
          conversation_id: String(body.conversation_id),
          user_id: String(body.user_id),
          companion_id: String(body.companion_id),
          client_message_id: String(body.client_message_id),
          role: body.role as "user" | "companion",
          content: String(body.content),
          persona_version: String(body.persona_version),
          is_legacy_import: body.is_legacy_import === true,
          created_at: String(body.created_at),
        };
        this.messages.push(row);
        return Promise.resolve([row] as T);
      }
    }
    throw new Error(`Unsupported fake request: ${method} ${table}`);
  }

  private nextUuid(): string {
    const suffix = String(this.#nextId).padStart(12, "0");
    this.#nextId += 1;
    return `90000000-0000-4000-8000-${suffix}`;
  }
}

function matches(
  row: Record<string, unknown>,
  query: Readonly<Record<string, string>> | undefined,
): boolean {
  return Object.entries(query ?? {}).every(([key, expression]) => {
    if (["select", "limit", "order"].includes(key)) return true;
    if (!expression.startsWith("eq.")) return true;
    return String(row[key]) === expression.slice(3);
  });
}

function migrationRequest(
  firstContent = "Historical text",
): CompanionMigrationRequest {
  return parseCompanionMigrationRequest({
    companionId: "aries-amara",
    migrationVersion: 1,
    syncConsent: true,
    conversations: [{
      legacyConversationId: "11111111-1111-4111-8111-111111111111",
      title: "Imported thread",
      messages: [{
        legacyMessageId: "22222222-2222-4222-8222-222222222222",
        role: "user",
        content: firstContent,
        createdAt: "2026-07-18T12:00:00Z",
      }, {
        legacyMessageId: "22222222-2222-4222-8222-222222222222",
        role: "companion",
        content: "Historical reply",
        createdAt: "2026-07-18T12:00:01Z",
      }],
    }],
  });
}

function conversationRow(
  changes: Partial<MigrationConversationRow> = {},
): MigrationConversationRow {
  return {
    id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    user_id: firstUser,
    relationship_id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    companion_id: "aries-amara",
    status: "active",
    title: "Imported thread",
    persona_version: LEGACY_PERSONA_VERSION,
    legacy_record_id: "11111111-1111-4111-8111-111111111111",
    migration_version: 1,
    sync_consent_at: consentedAt,
    ...changes,
  };
}

function messageRow(
  changes: Partial<MigrationMessageRow> = {},
): MigrationMessageRow {
  return {
    id: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee",
    conversation_id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
    user_id: firstUser,
    companion_id: "aries-amara",
    client_message_id: "22222222-2222-4222-8222-222222222222",
    role: "user",
    content: "Historical text",
    persona_version: LEGACY_PERSONA_VERSION,
    is_legacy_import: true,
    created_at: "2026-07-18T12:00:00.000Z",
    ...changes,
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

async function assertRuntimeCodeAsync(
  action: () => Promise<unknown>,
  code: string,
): Promise<void> {
  try {
    await action();
    throw new Error(`Expected ${code}`);
  } catch (error) {
    if (!(error instanceof CompanionRuntimeError) || error.code !== code) {
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
