import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  type CompanionRest,
  CompanionRestError,
} from "../_shared/companion/rest.ts";
import type { PilotPersonaProgram } from "../_shared/companion/registry.ts";
import {
  type CompanionMigrationRequest,
  type LegacyConversationImport,
  type LegacyMessageImport,
} from "./contract.ts";

export const LEGACY_PERSONA_VERSION = "legacy-unversioned";

type PersonaRow = Readonly<{
  id: string;
  status: string;
  active_persona_version: string | null;
}>;

export type MigrationRelationshipRow = Readonly<{
  id: string;
  user_id: string;
  companion_id: string | null;
  status: string;
}>;

export type MigrationConversationRow = Readonly<{
  id: string;
  user_id: string;
  relationship_id: string;
  companion_id: string | null;
  status: string;
  title: string | null;
  persona_version: string | null;
  legacy_record_id: string | null;
  migration_version: number | null;
  sync_consent_at: string | null;
}>;

export type MigrationMessageRow = Readonly<{
  id: string;
  conversation_id: string;
  user_id: string;
  companion_id: string | null;
  client_message_id: string;
  role: "user" | "companion";
  content: string;
  persona_version: string | null;
  is_legacy_import: boolean;
  created_at: string;
}>;

export type MigratedConversationResult = Readonly<{
  legacyConversationId: string;
  conversationId: string;
  importedMessages: number;
  existingMessages: number;
}>;

export type CompanionMigrationResult = Readonly<{
  companionId: string;
  relationshipId: string;
  counts: Readonly<{
    relationshipsImported: number;
    relationshipsExisting: number;
    conversationsImported: number;
    conversationsExisting: number;
    messagesImported: number;
    messagesExisting: number;
  }>;
  conversations: readonly MigratedConversationResult[];
}>;

export type CompanionMigrationRepository = Readonly<{
  importConsentedThreads(
    userId: string,
    request: CompanionMigrationRequest,
    persona: PilotPersonaProgram,
    consentedAt: string,
  ): Promise<CompanionMigrationResult>;
}>;

export class SupabaseCompanionMigrationRepository
  implements CompanionMigrationRepository {
  readonly #rest: CompanionRest;

  constructor(rest: CompanionRest) {
    this.#rest = rest;
  }

  async importConsentedThreads(
    userId: string,
    request: CompanionMigrationRequest,
    persona: PilotPersonaProgram,
    consentedAt: string,
  ): Promise<CompanionMigrationResult> {
    await this.#verifyReleasedPersona(persona);
    const relationship = await this.#ensureRelationship(userId, persona.id);

    const relationshipsImported = relationship.created ? 1 : 0;
    const relationshipsExisting = relationship.created ? 0 : 1;
    let conversationsImported = 0;
    let conversationsExisting = 0;
    let messagesImported = 0;
    let messagesExisting = 0;
    const conversationResults: MigratedConversationResult[] = [];

    for (const importConversation of request.conversations) {
      const conversation = await this.#ensureConversation(
        userId,
        relationship.row,
        persona.id,
        request.migrationVersion,
        consentedAt,
        importConversation,
      );
      if (conversation.created) conversationsImported += 1;
      else conversationsExisting += 1;

      let importedForConversation = 0;
      let existingForConversation = 0;
      for (const message of importConversation.messages) {
        const created = await this.#ensureMessage(
          userId,
          persona.id,
          conversation.row.id,
          request.migrationVersion,
          message,
        );
        if (created) {
          messagesImported += 1;
          importedForConversation += 1;
        } else {
          messagesExisting += 1;
          existingForConversation += 1;
        }
      }

      const lastMessageAt = importConversation.messages.reduce(
        (latest, message) =>
          Date.parse(message.createdAt) > Date.parse(latest)
            ? message.createdAt
            : latest,
        importConversation.messages[0].createdAt,
      );
      await this.#rest.request<unknown>("companion_conversations", {
        method: "PATCH",
        query: {
          id: `eq.${conversation.row.id}`,
          user_id: `eq.${userId}`,
        },
        body: { last_message_at: lastMessageAt },
        prefer: "return=minimal",
      });

      conversationResults.push(Object.freeze({
        legacyConversationId: importConversation.legacyConversationId,
        conversationId: conversation.row.id,
        importedMessages: importedForConversation,
        existingMessages: existingForConversation,
      }));
    }

    return Object.freeze({
      companionId: persona.id,
      relationshipId: relationship.row.id,
      counts: Object.freeze({
        relationshipsImported,
        relationshipsExisting,
        conversationsImported,
        conversationsExisting,
        messagesImported,
        messagesExisting,
      }),
      conversations: Object.freeze(conversationResults),
    });
  }

  async #verifyReleasedPersona(persona: PilotPersonaProgram): Promise<void> {
    const rows = await this.#rest.request<PersonaRow[]>("companion_personas", {
      query: {
        id: `eq.${persona.id}`,
        select: "id,status,active_persona_version",
        limit: "1",
      },
    });
    const row = rows[0];
    if (
      !row || row.id !== persona.id ||
      !["pilot_ready", "active"].includes(row.status) ||
      row.active_persona_version !== persona.version
    ) {
      throw new CompanionRuntimeError(
        "companion_unavailable",
        "This companion is not certified for migration right now.",
        409,
      );
    }
  }

  async #ensureRelationship(
    userId: string,
    companionId: string,
  ): Promise<Readonly<{ row: MigrationRelationshipRow; created: boolean }>> {
    const existing = await this.#relationship(userId, companionId);
    if (existing) {
      assertRelationshipOwnership(existing, userId, companionId);
      return Object.freeze({ row: existing, created: false });
    }

    try {
      const rows = await this.#rest.request<MigrationRelationshipRow[]>(
        "user_companion_relationships",
        {
          method: "POST",
          query: {
            select: "id,user_id,companion_id,status",
          },
          body: {
            user_id: userId,
            companion_id: companionId,
            status: "active",
            is_primary: false,
            support_preferences: {},
          },
          prefer: "return=representation",
        },
      );
      const row = rows[0];
      if (!row) throw new CompanionRestError(503);
      assertRelationshipOwnership(row, userId, companionId);
      return Object.freeze({ row, created: true });
    } catch (error) {
      if (!isConflict(error)) throw error;
      const raced = await this.#relationship(userId, companionId);
      if (!raced) throw error;
      assertRelationshipOwnership(raced, userId, companionId);
      return Object.freeze({ row: raced, created: false });
    }
  }

  #relationship(
    userId: string,
    companionId: string,
  ): Promise<MigrationRelationshipRow | null> {
    return this.#rest.request<MigrationRelationshipRow[]>(
      "user_companion_relationships",
      {
        query: {
          user_id: `eq.${userId}`,
          companion_id: `eq.${companionId}`,
          select: "id,user_id,companion_id,status",
          limit: "1",
        },
      },
    ).then((rows) => rows[0] ?? null);
  }

  async #ensureConversation(
    userId: string,
    relationship: MigrationRelationshipRow,
    companionId: string,
    migrationVersion: number,
    consentedAt: string,
    imported: LegacyConversationImport,
  ): Promise<Readonly<{ row: MigrationConversationRow; created: boolean }>> {
    const existing = await this.#conversation(
      userId,
      imported.legacyConversationId,
    );
    if (existing) {
      assertConversationImportMatches(
        existing,
        userId,
        relationship.id,
        companionId,
        migrationVersion,
        imported,
      );
      return Object.freeze({ row: existing, created: false });
    }

    const firstMessageAt = imported.messages.reduce(
      (earliest, message) =>
        Date.parse(message.createdAt) < Date.parse(earliest)
          ? message.createdAt
          : earliest,
      imported.messages[0].createdAt,
    );
    const body = {
      user_id: userId,
      relationship_id: relationship.id,
      companion_id: companionId,
      status: relationship.status === "archived" ? "archived" : "active",
      title: imported.title,
      persona_version: LEGACY_PERSONA_VERSION,
      legacy_record_id: imported.legacyConversationId,
      migration_version: migrationVersion,
      sync_consent_at: consentedAt,
      created_at: firstMessageAt,
    };
    try {
      const rows = await this.#rest.request<MigrationConversationRow[]>(
        "companion_conversations",
        {
          method: "POST",
          query: { select: conversationColumns },
          body,
          prefer: "return=representation",
        },
      );
      const row = rows[0];
      if (!row) throw new CompanionRestError(503);
      assertConversationImportMatches(
        row,
        userId,
        relationship.id,
        companionId,
        migrationVersion,
        imported,
      );
      return Object.freeze({ row, created: true });
    } catch (error) {
      if (!isConflict(error)) throw error;
      const raced = await this.#conversation(
        userId,
        imported.legacyConversationId,
      );
      if (!raced) throw error;
      assertConversationImportMatches(
        raced,
        userId,
        relationship.id,
        companionId,
        migrationVersion,
        imported,
      );
      return Object.freeze({ row: raced, created: false });
    }
  }

  #conversation(
    userId: string,
    legacyConversationId: string,
  ): Promise<MigrationConversationRow | null> {
    return this.#rest.request<MigrationConversationRow[]>(
      "companion_conversations",
      {
        query: {
          user_id: `eq.${userId}`,
          legacy_record_id: `eq.${legacyConversationId}`,
          select: conversationColumns,
          limit: "1",
        },
      },
    ).then((rows) => rows[0] ?? null);
  }

  async #ensureMessage(
    userId: string,
    companionId: string,
    conversationId: string,
    migrationVersion: number,
    imported: LegacyMessageImport,
  ): Promise<boolean> {
    const existing = await this.#message(
      userId,
      imported.legacyMessageId,
      imported.role,
    );
    if (existing) {
      assertMessageImportMatches(
        existing,
        userId,
        conversationId,
        companionId,
        imported,
      );
      return false;
    }

    const body = {
      conversation_id: conversationId,
      user_id: userId,
      companion_id: companionId,
      client_message_id: imported.legacyMessageId,
      role: imported.role,
      content: imported.content,
      persona_version: LEGACY_PERSONA_VERSION,
      model_provider: null,
      model_version: null,
      delivery_state: "complete",
      safety_metadata: {
        provenance: "consented_device_import",
        migration_version: migrationVersion,
      },
      is_legacy_import: true,
      completed_at: imported.createdAt,
      created_at: imported.createdAt,
    };
    try {
      const rows = await this.#rest.request<MigrationMessageRow[]>(
        "companion_messages",
        {
          method: "POST",
          query: { select: messageColumns },
          body,
          prefer: "return=representation",
        },
      );
      const row = rows[0];
      if (!row) throw new CompanionRestError(503);
      assertMessageImportMatches(
        row,
        userId,
        conversationId,
        companionId,
        imported,
      );
      return true;
    } catch (error) {
      if (!isConflict(error)) throw error;
      const raced = await this.#message(
        userId,
        imported.legacyMessageId,
        imported.role,
      );
      if (!raced) throw error;
      assertMessageImportMatches(
        raced,
        userId,
        conversationId,
        companionId,
        imported,
      );
      return false;
    }
  }

  #message(
    userId: string,
    legacyMessageId: string,
    role: LegacyMessageImport["role"],
  ): Promise<MigrationMessageRow | null> {
    return this.#rest.request<MigrationMessageRow[]>("companion_messages", {
      query: {
        user_id: `eq.${userId}`,
        client_message_id: `eq.${legacyMessageId}`,
        role: `eq.${role}`,
        select: messageColumns,
        limit: "1",
      },
    }).then((rows) => rows[0] ?? null);
  }
}

const conversationColumns =
  "id,user_id,relationship_id,companion_id,status,title,persona_version,legacy_record_id,migration_version,sync_consent_at";
const messageColumns =
  "id,conversation_id,user_id,companion_id,client_message_id,role,content,persona_version,is_legacy_import,created_at";

export function assertRelationshipOwnership(
  row: MigrationRelationshipRow,
  userId: string,
  companionId: string,
): void {
  if (
    row.user_id !== userId || row.companion_id !== companionId ||
    !["active", "archived"].includes(row.status)
  ) {
    throw conflict(
      "relationship_forbidden",
      "The canonical companion relationship does not belong to this user.",
      403,
    );
  }
}

export function assertConversationImportMatches(
  row: MigrationConversationRow,
  userId: string,
  relationshipId: string,
  companionId: string,
  migrationVersion: number,
  imported: LegacyConversationImport,
): void {
  if (
    row.user_id !== userId || row.relationship_id !== relationshipId ||
    row.companion_id !== companionId
  ) {
    throw conflict(
      "legacy_id_conflict",
      "This legacy conversation identifier is already bound to another relationship.",
      409,
    );
  }
  if (
    row.legacy_record_id !== imported.legacyConversationId ||
    row.persona_version !== LEGACY_PERSONA_VERSION ||
    row.migration_version !== migrationVersion ||
    row.sync_consent_at === null || row.title !== imported.title
  ) {
    throw conflict(
      "legacy_import_conflict",
      "This legacy conversation identifier was already imported with different metadata.",
      409,
    );
  }
}

export function assertMessageImportMatches(
  row: MigrationMessageRow,
  userId: string,
  conversationId: string,
  companionId: string,
  imported: LegacyMessageImport,
): void {
  const sameTimestamp = Date.parse(row.created_at) === Date.parse(
    imported.createdAt,
  );
  if (
    row.user_id !== userId || row.conversation_id !== conversationId ||
    row.companion_id !== companionId ||
    row.client_message_id !== imported.legacyMessageId ||
    row.role !== imported.role || row.content !== imported.content ||
    row.persona_version !== LEGACY_PERSONA_VERSION ||
    !row.is_legacy_import || !sameTimestamp
  ) {
    throw conflict(
      "legacy_message_conflict",
      "This legacy message identifier was already imported with different content or ownership.",
      409,
    );
  }
}

function isConflict(error: unknown): error is CompanionRestError {
  return error instanceof CompanionRestError && error.databaseStatus === 409;
}

function conflict(
  code: string,
  message: string,
  status: number,
): CompanionRuntimeError {
  return new CompanionRuntimeError(code, message, status);
}
