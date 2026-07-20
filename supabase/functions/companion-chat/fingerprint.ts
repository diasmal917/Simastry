import {
  CompanionRuntimeError,
  requiredEnv,
} from "../_shared/companion/errors.ts";
import type { CompanionChatRequest } from "./contract.ts";

export type CompanionChatRequestFingerprint = Readonly<{
  keyId: "v1";
  value: string;
}>;

export type CompanionChatRequestFingerprinter = (
  request: CompanionChatRequest,
) => Promise<CompanionChatRequestFingerprint>;

export async function fingerprintCompanionChatRequest(
  request: CompanionChatRequest,
): Promise<CompanionChatRequestFingerprint> {
  const keyBytes = new TextEncoder().encode(
    requiredEnv("SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY"),
  );
  if (keyBytes.byteLength < 32) {
    throw new CompanionRuntimeError(
      "backend_misconfigured",
      "SIMASTRY_COMPANION_IDEMPOTENCY_HMAC_KEY must contain at least 32 UTF-8 bytes.",
      503,
    );
  }
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const canonical = [
    "companion-chat-fingerprint-v1",
    request.companionId,
    request.conversationId,
    request.clientMessageId,
    request.message,
  ].join("\0");
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(canonical),
  );
  return Object.freeze({ keyId: "v1", value: hex(signature) });
}

function hex(value: ArrayBuffer): string {
  return Array.from(
    new Uint8Array(value),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}
