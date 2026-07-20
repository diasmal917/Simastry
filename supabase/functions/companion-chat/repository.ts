import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  boundedContextObject,
  boundedContextText,
} from "../_shared/companion/context.ts";
import {
  type CompanionRest,
  CompanionRestError,
} from "../_shared/companion/rest.ts";
import type { PilotPersonaProgram } from "../_shared/companion/registry.ts";
import {
  type CompanionTokenSource,
  tokenSource,
} from "../_shared/companion/usage.ts";
import {
  type AuthorizedPersonContext,
  buildAuthorizedPersonContext,
  type CommunicationOutcomeRow,
  explicitlyReferencedPerson,
  type RelationshipPersonRow,
} from "../_shared/companion/relationshipContext.ts";
import type { CompanionChatRequest } from "./contract.ts";
import type { CompanionChatRequestFingerprint } from "./fingerprint.ts";

type PersonaRow = Readonly<{
  id: string;
  status: string;
  active_persona_version: string | null;
}>;

type RelationshipRow = Readonly<{
  id: string;
  support_preferences: Record<string, unknown> | null;
}>;

type ConversationRow = Readonly<{
  id: string;
  user_id: string;
  relationship_id: string;
  companion_id: string | null;
  status: string;
  persona_version: string | null;
}>;

export type StoredMessage = Readonly<{
  id: string;
  conversation_id: string;
  user_id: string;
  companion_id: string | null;
  client_message_id: string;
  role: "user" | "companion";
  content: string;
  delivery_state: "pending" | "streaming" | "complete" | "failed";
  persona_version: string | null;
  model_provider: string | null;
  model_version: string | null;
  usage_event_id: string | null;
  request_fingerprint: string | null;
  request_fingerprint_key_id: string | null;
  safety_metadata: Record<string, unknown> | null;
  updated_at: string;
  created_at: string;
}>;

type MemoryRow = Readonly<{
  scope: string;
  companion_id: string | null;
  memory_kind: string;
  content: string;
  source: string;
}>;

export type CompanionChatContext = Readonly<{
  supportPreferences: Record<string, unknown>;
  birthChart: Record<string, unknown> | null;
  memories: readonly Readonly<{
    scope: string;
    kind: string;
    content: string;
    source: string;
  }>[];
  transcript: readonly Readonly<{
    role: "user" | "companion";
    content: string;
  }>[];
  selectedPerson: AuthorizedPersonContext | null;
}>;

export type ClaimedChatTurn = Readonly<{
  kind: "claimed";
  userMessageId: string;
  relationshipId: string;
  context: CompanionChatContext;
}>;

export type ReplayedChatTurn = Readonly<{
  kind: "replay";
  text: string;
  modelVersion: string;
  usageEventId: string | null;
  usage: ReplayedChatUsage | null;
}>;

export type ReplayedChatUsage = Readonly<{
  modelProvider: string;
  inputTokens: number;
  outputTokens: number;
  responseCharacters: number;
  tokenSource: CompanionTokenSource;
}>;

export type PreparedChatTurn = ClaimedChatTurn | ReplayedChatTurn;

export type CompletedChatTurn = Readonly<{
  text: string;
  modelVersion: string;
  usageEventId: string | null;
  replayed: boolean;
}>;

export type CompanionChatRepository = Readonly<{
  prepare(
    userId: string,
    request: CompanionChatRequest,
    persona: PilotPersonaProgram,
    requestFingerprint: CompanionChatRequestFingerprint,
  ): Promise<PreparedChatTurn>;
  complete(
    args: Readonly<{
      userId: string;
      request: CompanionChatRequest;
      persona: PilotPersonaProgram;
      userMessageId: string;
      text: string;
      modelProvider: string;
      modelVersion: string;
      safetyCategory: string;
      safetyOutputReplaced: boolean;
      usageEventId: string | null;
      requestFingerprint: CompanionChatRequestFingerprint;
      usage?: Readonly<{ inputTokens: number; outputTokens: number }>;
    }>,
  ): Promise<CompletedChatTurn>;
  fail(userMessageId: string, code: string): Promise<void>;
}>;

type ExistingDisposition =
  | Readonly<{ kind: "none" }>
  | Readonly<{
    kind: "replay";
    text: string;
    modelVersion: string;
    usageEventId: string | null;
    usage: ReplayedChatUsage | null;
  }>
  | Readonly<{ kind: "resume"; userMessage: StoredMessage }>;

export function classifyExistingTurn(
  rows: readonly StoredMessage[],
  request: CompanionChatRequest,
  requestFingerprint: CompanionChatRequestFingerprint | null = null,
  now = Date.now(),
): ExistingDisposition {
  const companion = rows.find((row) => row.role === "companion");
  const user = rows.find((row) => row.role === "user");
  for (const row of rows) {
    if (
      row.conversation_id !== request.conversationId ||
      row.companion_id !== request.companionId
    ) {
      throw new CompanionRuntimeError(
        "idempotency_conflict",
        "This message identifier was already used for another turn.",
        409,
      );
    }
  }
  if (user && !sameLogicalRequest(user, request, requestFingerprint)) {
    throw new CompanionRuntimeError(
      "idempotency_conflict",
      "This message identifier was already used with different text.",
      409,
    );
  }
  if (companion?.delivery_state === "complete") {
    return Object.freeze({
      kind: "replay",
      text: companion.content,
      modelVersion: companion.model_version ?? "unknown",
      usageEventId: companion.usage_event_id,
      usage: replayedUsage(companion),
    });
  }
  if (!user) return Object.freeze({ kind: "none" });
  const updatedAt = Date.parse(user.updated_at);
  const isStale = !Number.isFinite(updatedAt) || now - updatedAt >= 120_000;
  if (
    (user.delivery_state === "pending" ||
      user.delivery_state === "streaming") && !isStale
  ) {
    throw new CompanionRuntimeError(
      "turn_in_progress",
      "This message is already being answered.",
      409,
    );
  }
  if (user.delivery_state === "complete") {
    throw new CompanionRuntimeError(
      "idempotency_unavailable",
      "This completed turn could not be replayed. Please send it again with a new message identifier.",
      409,
    );
  }
  return Object.freeze({ kind: "resume", userMessage: user });
}

export class SupabaseCompanionChatRepository
  implements CompanionChatRepository {
  readonly #rest: CompanionRest;

  constructor(rest: CompanionRest) {
    this.#rest = rest;
  }

  async prepare(
    userId: string,
    request: CompanionChatRequest,
    persona: PilotPersonaProgram,
    requestFingerprint: CompanionChatRequestFingerprint,
  ): Promise<PreparedChatTurn> {
    await this.#verifyPersona(persona);
    const relationship = await this.#primaryRelationship(userId, persona.id);
    await this.#ensureConversation(userId, request, persona, relationship.id);

    let rows = await this.#messagesForTurn(userId, request.clientMessageId);
    let disposition = classifyExistingTurn(rows, request, requestFingerprint);
    if (disposition.kind === "replay") return disposition;

    let userMessageId: string;
    if (disposition.kind === "resume") {
      const claimed = await this.#rest.request<StoredMessage[]>(
        "companion_messages",
        {
          method: "PATCH",
          query: {
            id: `eq.${disposition.userMessage.id}`,
            delivery_state: `eq.${disposition.userMessage.delivery_state}`,
            updated_at: `eq.${disposition.userMessage.updated_at}`,
            select:
              "id,conversation_id,user_id,companion_id,client_message_id,role,content,delivery_state,persona_version,model_provider,model_version,usage_event_id,request_fingerprint,request_fingerprint_key_id,safety_metadata,updated_at,created_at",
          },
          body: {
            delivery_state: "pending",
            request_fingerprint: requestFingerprint.value,
            request_fingerprint_key_id: requestFingerprint.keyId,
          },
          prefer: "return=representation",
        },
      );
      if (claimed.length !== 1) {
        throw new CompanionRuntimeError(
          "turn_in_progress",
          "This message is already being answered.",
          409,
        );
      }
      userMessageId = claimed[0].id;
    } else {
      try {
        const inserted = await this.#rest.request<StoredMessage[]>(
          "companion_messages",
          {
            method: "POST",
            query: {
              select:
                "id,conversation_id,user_id,companion_id,client_message_id,role,content,delivery_state,persona_version,model_provider,model_version,usage_event_id,request_fingerprint,request_fingerprint_key_id,safety_metadata,updated_at,created_at",
            },
            body: {
              conversation_id: request.conversationId,
              user_id: userId,
              companion_id: persona.id,
              client_message_id: request.clientMessageId,
              role: "user",
              content: request.message,
              request_fingerprint: requestFingerprint.value,
              request_fingerprint_key_id: requestFingerprint.keyId,
              persona_version: persona.version,
              delivery_state: "pending",
            },
            prefer: "return=representation",
          },
        );
        if (inserted.length !== 1) throw new CompanionRestError(503);
        userMessageId = inserted[0].id;
      } catch (error) {
        if (
          !(error instanceof CompanionRestError) || error.databaseStatus !== 409
        ) {
          throw error;
        }
        rows = await this.#messagesForTurn(userId, request.clientMessageId);
        disposition = classifyExistingTurn(rows, request, requestFingerprint);
        if (disposition.kind === "replay") return disposition;
        throw new CompanionRuntimeError(
          "turn_in_progress",
          "This message is already being answered.",
          409,
        );
      }
    }

    try {
      await this.#rest.request<unknown>("companion_messages", {
        method: "PATCH",
        query: { id: `eq.${userMessageId}` },
        body: { delivery_state: "streaming" },
        prefer: "return=minimal",
      });
      const context = await this.#context(
        userId,
        request,
        persona,
        relationship,
      );
      return Object.freeze({
        kind: "claimed",
        userMessageId,
        relationshipId: relationship.id,
        context,
      });
    } catch (error) {
      await this.fail(
        userMessageId,
        error instanceof CompanionRuntimeError
          ? error.code
          : "backend_unavailable",
      );
      throw error;
    }
  }

  async complete(
    args: Readonly<{
      userId: string;
      request: CompanionChatRequest;
      persona: PilotPersonaProgram;
      userMessageId: string;
      text: string;
      modelProvider: string;
      modelVersion: string;
      safetyCategory: string;
      safetyOutputReplaced: boolean;
      usageEventId: string | null;
      requestFingerprint: CompanionChatRequestFingerprint;
      usage?: Readonly<{ inputTokens: number; outputTokens: number }>;
    }>,
  ): Promise<CompletedChatTurn> {
    const now = new Date().toISOString();
    try {
      await this.#rest.request<StoredMessage[]>("companion_messages", {
        method: "POST",
        body: {
          conversation_id: args.request.conversationId,
          user_id: args.userId,
          companion_id: args.persona.id,
          client_message_id: args.request.clientMessageId,
          role: "companion",
          content: args.text,
          persona_version: args.persona.version,
          model_provider: args.modelProvider,
          model_version: args.modelVersion,
          usage_event_id: args.usageEventId,
          delivery_state: "complete",
          safety_metadata: {
            input_category: args.safetyCategory,
            output_replaced: args.safetyOutputReplaced,
            policy_version: "companion-safety-2026-07-19.1",
            usage_accounting: {
              response_characters: args.text.length,
              token_source: tokenSource(args.modelProvider, args.usage),
            },
            ...(args.usage
              ? {
                provider_usage: {
                  input_tokens: args.usage.inputTokens,
                  output_tokens: args.usage.outputTokens,
                },
              }
              : {}),
          },
          completed_at: now,
        },
        prefer: "return=representation",
      });
    } catch (error) {
      if (
        !(error instanceof CompanionRestError) || error.databaseStatus !== 409
      ) {
        throw error;
      }
      const rows = await this.#messagesForTurn(
        args.userId,
        args.request.clientMessageId,
      );
      const disposition = classifyExistingTurn(
        rows,
        args.request,
        args.requestFingerprint,
      );
      if (disposition.kind === "replay") {
        await this.#completeBookkeeping(args, now);
        return Object.freeze({
          text: disposition.text,
          modelVersion: disposition.modelVersion,
          usageEventId: disposition.usageEventId,
          replayed: true,
        });
      }
      throw error;
    }

    await this.#completeBookkeeping(args, now);
    return Object.freeze({
      text: args.text,
      modelVersion: args.modelVersion,
      usageEventId: args.usageEventId,
      replayed: false,
    });
  }

  async fail(userMessageId: string, code: string): Promise<void> {
    try {
      await this.#rest.request<unknown>("companion_messages", {
        method: "PATCH",
        query: { id: `eq.${userMessageId}` },
        body: {
          delivery_state: "failed",
          safety_metadata: { failure_code: code },
        },
        prefer: "return=minimal",
      });
    } catch (error) {
      console.error(JSON.stringify({
        event: "companion_turn_failure_state_update_failed",
        error: error instanceof Error ? error.message : String(error),
      }));
    }
  }

  async #completeBookkeeping(
    args: Readonly<{
      userId: string;
      request: CompanionChatRequest;
      persona: PilotPersonaProgram;
      userMessageId: string;
    }>,
    completedAt: string,
  ): Promise<void> {
    await Promise.all([
      recoverCommittedResponseBookkeeping(
        "user_message",
        () =>
          this.#rest.request<unknown>("companion_messages", {
            method: "PATCH",
            query: { id: `eq.${args.userMessageId}` },
            body: { delivery_state: "complete", completed_at: completedAt },
            prefer: "return=minimal",
          }),
      ),
      recoverCommittedResponseBookkeeping(
        "conversation",
        () =>
          this.#rest.request<unknown>("companion_conversations", {
            method: "PATCH",
            query: {
              id: `eq.${args.request.conversationId}`,
              user_id: `eq.${args.userId}`,
            },
            body: {
              persona_version: args.persona.version,
              last_message_at: completedAt,
            },
            prefer: "return=minimal",
          }),
      ),
    ]);
  }

  async #verifyPersona(persona: PilotPersonaProgram): Promise<void> {
    const rows = await this.#rest.request<PersonaRow[]>("companion_personas", {
      query: {
        id: `eq.${persona.id}`,
        select: "id,status,active_persona_version",
        limit: "1",
      },
    });
    const row = rows[0];
    if (
      !row || !["pilot_ready", "active"].includes(row.status) ||
      row.active_persona_version !== persona.version
    ) {
      throw new CompanionRuntimeError(
        "companion_unavailable",
        "This companion is not available right now.",
        409,
      );
    }
  }

  async #primaryRelationship(
    userId: string,
    companionId: string,
  ): Promise<RelationshipRow> {
    const rows = await this.#rest.request<RelationshipRow[]>(
      "user_companion_relationships",
      {
        query: {
          user_id: `eq.${userId}`,
          companion_id: `eq.${companionId}`,
          status: "eq.active",
          is_primary: "eq.true",
          select: "id,support_preferences",
          limit: "1",
        },
      },
    );
    if (!rows[0]) {
      throw new CompanionRuntimeError(
        "primary_companion_required",
        "Choose this companion as your primary before starting this thread.",
        403,
      );
    }
    return rows[0];
  }

  async #ensureConversation(
    userId: string,
    request: CompanionChatRequest,
    persona: PilotPersonaProgram,
    relationshipId: string,
  ): Promise<void> {
    const rows = await this.#rest.request<ConversationRow[]>(
      "companion_conversations",
      {
        query: {
          id: `eq.${request.conversationId}`,
          select:
            "id,user_id,relationship_id,companion_id,status,persona_version",
          limit: "1",
        },
      },
    );
    const existing = rows[0];
    if (existing) {
      if (
        existing.user_id !== userId ||
        existing.relationship_id !== relationshipId ||
        existing.companion_id !== persona.id || existing.status !== "active"
      ) {
        throw new CompanionRuntimeError(
          "conversation_forbidden",
          "This conversation does not belong to the selected companion relationship.",
          403,
        );
      }
      return;
    }

    try {
      await this.#rest.request<ConversationRow[]>("companion_conversations", {
        method: "POST",
        body: {
          id: request.conversationId,
          user_id: userId,
          relationship_id: relationshipId,
          companion_id: persona.id,
          status: "active",
          persona_version: persona.version,
        },
        prefer: "return=representation",
      });
    } catch (error) {
      if (
        !(error instanceof CompanionRestError) || error.databaseStatus !== 409
      ) {
        throw error;
      }
      const raced = await this.#rest.request<ConversationRow[]>(
        "companion_conversations",
        {
          query: {
            id: `eq.${request.conversationId}`,
            select:
              "id,user_id,relationship_id,companion_id,status,persona_version",
            limit: "1",
          },
        },
      );
      const row = raced[0];
      if (
        !row || row.user_id !== userId ||
        row.relationship_id !== relationshipId ||
        row.companion_id !== persona.id ||
        row.status !== "active"
      ) {
        throw new CompanionRuntimeError(
          "conversation_forbidden",
          "This conversation does not belong to the selected companion relationship.",
          403,
        );
      }
    }
  }

  #messagesForTurn(
    userId: string,
    clientMessageId: string,
  ): Promise<StoredMessage[]> {
    return this.#rest.request<StoredMessage[]>("companion_messages", {
      query: {
        user_id: `eq.${userId}`,
        client_message_id: `eq.${clientMessageId}`,
        select:
          "id,conversation_id,user_id,companion_id,client_message_id,role,content,delivery_state,persona_version,model_provider,model_version,usage_event_id,request_fingerprint,request_fingerprint_key_id,safety_metadata,updated_at,created_at",
        order: "created_at.asc",
      },
    });
  }

  async #context(
    userId: string,
    request: CompanionChatRequest,
    persona: PilotPersonaProgram,
    relationship: RelationshipRow,
  ): Promise<CompanionChatContext> {
    const [transcriptRows, chartRows, memoryRows, personRows] = await Promise
      .all([
        this.#rest.request<StoredMessage[]>("companion_messages", {
          query: {
            user_id: `eq.${userId}`,
            conversation_id: `eq.${request.conversationId}`,
            client_message_id: `neq.${request.clientMessageId}`,
            delivery_state: "eq.complete",
            select:
              "id,conversation_id,user_id,companion_id,client_message_id,role,content,delivery_state,persona_version,model_provider,model_version,usage_event_id,request_fingerprint,request_fingerprint_key_id,safety_metadata,updated_at,created_at",
            order: "created_at.desc",
            limit: "16",
          },
        }),
        this.#rest.request<Record<string, unknown>[]>("user_birth_charts", {
          query: {
            user_id: `eq.${userId}`,
            select:
              "birth_time_precision,sun_estimate,moon_estimate,rising_estimate,calculation_version,provenance,confirmed_at",
            limit: "1",
          },
        }),
        this.#rest.request<MemoryRow[]>("companion_memories", {
          query: {
            user_id: `eq.${userId}`,
            deleted_at: "is.null",
            select: "scope,companion_id,memory_kind,content,source",
            order: "updated_at.desc",
            limit: "40",
          },
        }),
        this.#rest.request<RelationshipPersonRow[]>("relationship_people", {
          query: {
            user_id: `eq.${userId}`,
            archived_at: "is.null",
            ai_context_enabled: "eq.true",
            select:
              "id,display_name,relationship_kind,pronouns,birth_chart,notes,communication_guide",
            order: "updated_at.desc",
            // One extra row detects an incomplete bounded candidate set. In
            // that case we decline to infer a person from the message.
            limit: "101",
          },
        }),
      ]);
    const person = explicitlyReferencedPerson(
      request.message,
      personRows.slice(0, 100),
      personRows.length <= 100,
    );
    const outcomeRows = person
      ? await this.#rest.request<CommunicationOutcomeRow[]>(
        "communication_outcomes",
        {
          query: {
            user_id: `eq.${userId}`,
            person_id: `eq.${person.id}`,
            select:
              "action_text,action_state,planned_for,acted_at,result_kind,result_summary,result_source,result_recorded_at,follow_up_state,updated_at",
            order: "updated_at.desc",
            limit: "1",
          },
        },
      )
      : [];
    const memories = memoryRows
      .filter((row) =>
        row.scope === "shared_user_fact" || row.companion_id === persona.id
      )
      .slice(0, 12)
      .map((row) =>
        Object.freeze({
          scope: row.scope,
          kind: row.memory_kind,
          content: boundedContextText(row.content, 1_000),
          source: row.source,
        })
      );
    const transcript = transcriptRows.reverse().map((row) =>
      Object.freeze({
        role: row.role,
        content: boundedContextText(row.content, 4_000),
      })
    );
    return Object.freeze({
      supportPreferences: boundedContextObject(
        relationship.support_preferences,
        2_000,
      ) ?? {},
      birthChart: boundedContextObject(chartRows[0], 12_000),
      memories: Object.freeze(memories),
      transcript: Object.freeze(transcript),
      selectedPerson: person
        ? buildAuthorizedPersonContext(person, outcomeRows[0] ?? null)
        : null,
    });
  }
}

function sameLogicalRequest(
  userMessage: StoredMessage,
  request: CompanionChatRequest,
  requestFingerprint: CompanionChatRequestFingerprint | null,
): boolean {
  const hasStoredFingerprint = userMessage.request_fingerprint !== null ||
    userMessage.request_fingerprint_key_id !== null;
  if (hasStoredFingerprint) {
    return requestFingerprint !== null &&
      userMessage.request_fingerprint === requestFingerprint.value &&
      userMessage.request_fingerprint_key_id === requestFingerprint.keyId;
  }
  // Legacy rows created before server fingerprints retain the redacted-content
  // comparison so old completed turns remain replayable.
  return userMessage.content === request.message;
}

function replayedUsage(message: StoredMessage): ReplayedChatUsage | null {
  if (!message.usage_event_id || !message.model_provider) return null;
  const candidate = message.safety_metadata?.provider_usage;
  const providerUsage = candidate && typeof candidate === "object" &&
      !Array.isArray(candidate)
    ? candidate as Record<string, unknown>
    : null;
  const inputTokens = nonNegativeInteger(providerUsage?.input_tokens);
  const outputTokens = nonNegativeInteger(providerUsage?.output_tokens);
  const knownProviderUsage = inputTokens !== null && outputTokens !== null
    ? Object.freeze({ inputTokens, outputTokens })
    : undefined;
  return Object.freeze({
    modelProvider: message.model_provider,
    inputTokens: inputTokens ?? 0,
    outputTokens: outputTokens ?? 0,
    responseCharacters: message.content.length,
    tokenSource: tokenSource(message.model_provider, knownProviderUsage),
  });
}

function nonNegativeInteger(value: unknown): number | null {
  return Number.isInteger(value) && Number(value) >= 0 ? Number(value) : null;
}

async function recoverCommittedResponseBookkeeping(
  operation: "user_message" | "conversation",
  update: () => Promise<unknown>,
): Promise<void> {
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      await update();
      return;
    } catch (error) {
      if (attempt < 2) continue;
      console.error(JSON.stringify({
        event: "companion_response_bookkeeping_deferred",
        operation,
        error: error instanceof Error ? error.message : String(error),
      }));
    }
  }
}
