import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  objectValue,
  rejectUnknownKeys,
  requireExactKeys,
  requireString,
  requireUuid,
} from "../_shared/companion/http.ts";

export const COMPANION_MIGRATION_VERSION = 1;

export type LegacyMessageImport = Readonly<{
  legacyMessageId: string;
  role: "user" | "companion";
  content: string;
  createdAt: string;
}>;

export type LegacyConversationImport = Readonly<{
  legacyConversationId: string;
  title: string | null;
  messages: readonly LegacyMessageImport[];
}>;

export type CompanionMigrationRequest = Readonly<{
  companionId: string;
  migrationVersion: typeof COMPANION_MIGRATION_VERSION;
  syncConsent: true;
  conversations: readonly LegacyConversationImport[];
}>;

const requestKeys = Object.freeze([
  "companionId",
  "migrationVersion",
  "syncConsent",
  "conversations",
]);
const conversationKeys = Object.freeze([
  "legacyConversationId",
  "title",
  "messages",
]);
const messageKeys = Object.freeze([
  "legacyMessageId",
  "role",
  "content",
  "createdAt",
]);

export function parseCompanionMigrationRequest(
  body: Record<string, unknown>,
  now = Date.now(),
): CompanionMigrationRequest {
  rejectUnknownKeys(body, requestKeys);
  requireExactKeys(body, requestKeys);

  if (body.syncConsent !== true) {
    throw new CompanionRuntimeError(
      "sync_consent_required",
      "Explicit sync consent is required before importing device-local conversations.",
      400,
    );
  }
  if (body.migrationVersion !== COMPANION_MIGRATION_VERSION) {
    throw new CompanionRuntimeError(
      "unsupported_migration_version",
      `migrationVersion must be ${COMPANION_MIGRATION_VERSION}.`,
      400,
    );
  }
  if (!Array.isArray(body.conversations)) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      "conversations must be an array.",
      400,
    );
  }
  if (body.conversations.length < 1 || body.conversations.length > 20) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      "conversations must contain between 1 and 20 threads.",
      400,
    );
  }

  const conversations = body.conversations.map((value, index) =>
    parseConversation(value, index, now)
  );
  rejectDuplicateLegacyKeys(conversations);

  return Object.freeze({
    // Deliberately do not lowercase or otherwise infer this identity. Only an
    // exact Factory slug can pass the server registry after parsing.
    companionId: requireString(body, "companionId", 3, 80),
    migrationVersion: COMPANION_MIGRATION_VERSION,
    syncConsent: true,
    conversations: Object.freeze(conversations),
  });
}

function parseConversation(
  value: unknown,
  index: number,
  now: number,
): LegacyConversationImport {
  const body = objectValue(value);
  if (!body) {
    throw invalid(`conversations[${index}] must be an object.`);
  }
  rejectUnknownKeys(body, conversationKeys);
  requireExactKeys(body, conversationKeys);
  if (!Array.isArray(body.messages)) {
    throw invalid(`conversations[${index}].messages must be an array.`);
  }
  if (body.messages.length < 1 || body.messages.length > 200) {
    throw invalid(
      `conversations[${index}].messages must contain between 1 and 200 messages.`,
    );
  }

  let title: string | null;
  if (body.title === null) {
    title = null;
  } else if (typeof body.title === "string") {
    const trimmed = body.title.trim();
    if (trimmed.length < 1 || Array.from(trimmed).length > 160) {
      throw invalid(
        `conversations[${index}].title must be null or 1 to 160 characters.`,
      );
    }
    title = trimmed;
  } else {
    throw invalid(`conversations[${index}].title must be a string or null.`);
  }

  return Object.freeze({
    legacyConversationId: requireUuid(body, "legacyConversationId"),
    title,
    messages: Object.freeze(
      body.messages.map((message, messageIndex) =>
        parseMessage(message, index, messageIndex, now)
      ),
    ),
  });
}

function parseMessage(
  value: unknown,
  conversationIndex: number,
  messageIndex: number,
  now: number,
): LegacyMessageImport {
  const body = objectValue(value);
  const path = `conversations[${conversationIndex}].messages[${messageIndex}]`;
  if (!body) throw invalid(`${path} must be an object.`);
  rejectUnknownKeys(body, messageKeys);
  requireExactKeys(body, messageKeys);

  if (body.role !== "user" && body.role !== "companion") {
    throw invalid(`${path}.role must be user or companion.`);
  }
  if (typeof body.content !== "string") {
    throw invalid(`${path}.content must be a string.`);
  }
  if (
    body.content.trim().length < 1 || Array.from(body.content).length > 50_000
  ) {
    throw invalid(`${path}.content must be between 1 and 50000 characters.`);
  }
  const createdAt = canonicalTimestamp(body.createdAt, path, now);

  return Object.freeze({
    legacyMessageId: requireUuid(body, "legacyMessageId"),
    role: body.role,
    // Preserve the user's historical text exactly; trimming is validation-only.
    content: body.content,
    createdAt,
  });
}

function canonicalTimestamp(value: unknown, path: string, now: number): string {
  if (
    typeof value !== "string" ||
    !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$/
      .test(
        value,
      )
  ) {
    throw invalid(`${path}.createdAt must be an ISO 8601 timestamp.`);
  }
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp) || timestamp > now + 5 * 60_000) {
    throw invalid(`${path}.createdAt must not be invalid or in the future.`);
  }
  return new Date(timestamp).toISOString();
}

function rejectDuplicateLegacyKeys(
  conversations: readonly LegacyConversationImport[],
): void {
  const conversationIds = new Set<string>();
  const messageKeys = new Set<string>();
  for (const conversation of conversations) {
    if (conversationIds.has(conversation.legacyConversationId)) {
      throw invalid("A legacyConversationId may appear only once per request.");
    }
    conversationIds.add(conversation.legacyConversationId);
    for (const message of conversation.messages) {
      const key = `${message.role}:${message.legacyMessageId}`;
      if (messageKeys.has(key)) {
        throw invalid(
          "A legacyMessageId and role pair may appear only once per request.",
        );
      }
      messageKeys.add(key);
    }
  }
}

function invalid(message: string): CompanionRuntimeError {
  return new CompanionRuntimeError("invalid_payload", message, 400);
}
