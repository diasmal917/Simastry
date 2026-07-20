import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  rejectUnknownKeys,
  requireExactKeys,
  requireString,
  requireUuid,
} from "../_shared/companion/http.ts";

export type CompanionDecodeRequest = Readonly<{
  companionId: string;
  personId: string;
  message: string;
  persistMessage: false;
}>;

export const COMPANION_DECODE_REQUEST_KEYS = Object.freeze([
  "companionId",
  "personId",
  "message",
  "persistMessage",
]);

export function parseCompanionDecodeRequest(
  body: Record<string, unknown>,
): CompanionDecodeRequest {
  rejectUnknownKeys(body, COMPANION_DECODE_REQUEST_KEYS);
  requireExactKeys(body, COMPANION_DECODE_REQUEST_KEYS);
  if (body.persistMessage !== false) {
    throw new CompanionRuntimeError(
      "message_persistence_forbidden",
      "Decode message text cannot be persisted.",
      400,
    );
  }
  return Object.freeze({
    companionId: requireString(body, "companionId", 3, 80).toLowerCase(),
    personId: requireUuid(body, "personId"),
    message: requireString(body, "message", 1, 12_000),
    persistMessage: false,
  });
}
