import {
  rejectUnknownKeys,
  requireExactKeys,
  requireString,
  requireUuid,
} from "../_shared/companion/http.ts";
import { CompanionRuntimeError } from "../_shared/companion/errors.ts";

export type CompanionChatRequest = Readonly<{
  companionId: string;
  conversationId: string;
  clientMessageId: string;
  message: string;
  stream: boolean;
}>;

export const COMPANION_CHAT_REQUEST_KEYS = Object.freeze([
  "companionId",
  "conversationId",
  "clientMessageId",
  "message",
  "stream",
]);

export function parseCompanionChatRequest(
  body: Record<string, unknown>,
): CompanionChatRequest {
  rejectUnknownKeys(body, COMPANION_CHAT_REQUEST_KEYS);
  requireExactKeys(body, COMPANION_CHAT_REQUEST_KEYS);
  const stream = body.stream;
  if (typeof stream !== "boolean") {
    throw new CompanionRuntimeError(
      "invalid_payload",
      "stream must be a boolean.",
      400,
    );
  }
  return Object.freeze({
    companionId: requireString(body, "companionId", 3, 80).toLowerCase(),
    conversationId: requireUuid(body, "conversationId"),
    clientMessageId: requireUuid(body, "clientMessageId"),
    message: requireString(body, "message", 1, 4_000),
    stream,
  });
}
