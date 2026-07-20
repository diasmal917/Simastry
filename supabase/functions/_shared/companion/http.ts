import { CompanionRuntimeError, requiredEnv } from "./errors.ts";

export const companionCorsHeaders: Readonly<Record<string, string>> = Object
  .freeze({
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type, accept, x-simastry-device-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  });

export type AuthenticatedUser = Readonly<{ id: string }>;

export type Authenticator = (request: Request) => Promise<AuthenticatedUser>;

export async function authenticateRequest(
  request: Request,
): Promise<AuthenticatedUser> {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.match(/^Bearer\s+([^\s]+)$/i)?.[1];
  if (!token) {
    throw new CompanionRuntimeError(
      "auth_required",
      "Please sign in again before continuing.",
      401,
    );
  }

  const response = await fetch(`${requiredEnv("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      apikey: requiredEnv("SUPABASE_ANON_KEY"),
      authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) {
    throw new CompanionRuntimeError(
      "auth_required",
      "Please sign in again before continuing.",
      401,
    );
  }

  const body: unknown = await response.json();
  const id = objectValue(body)?.id;
  if (typeof id !== "string" || !isUuid(id)) {
    throw new CompanionRuntimeError(
      "auth_required",
      "Please sign in again before continuing.",
      401,
    );
  }
  return Object.freeze({ id });
}

export async function readJsonObject(
  request: Request,
  maxBytes: number,
): Promise<Record<string, unknown>> {
  const contentLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(contentLength) && contentLength > maxBytes) {
    throw new CompanionRuntimeError(
      "payload_too_large",
      "The request is too large.",
      413,
    );
  }

  let rawBody: string;
  try {
    rawBody = await request.text();
  } catch {
    throw new CompanionRuntimeError(
      "invalid_json",
      "The request body must be valid JSON.",
      400,
    );
  }
  if (new TextEncoder().encode(rawBody).byteLength > maxBytes) {
    throw new CompanionRuntimeError(
      "payload_too_large",
      "The request is too large.",
      413,
    );
  }
  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    throw new CompanionRuntimeError(
      "invalid_json",
      "The request body must be valid JSON.",
      400,
    );
  }
  const object = objectValue(body);
  if (!object) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      "The request body must be a JSON object.",
      400,
    );
  }
  return object;
}

export function rejectUnknownKeys(
  body: Record<string, unknown>,
  allowed: readonly string[],
): void {
  const allowedSet = new Set(allowed);
  const unknown = Object.keys(body).filter((key) => !allowedSet.has(key));
  if (unknown.length > 0) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      `Unsupported request field: ${unknown.sort()[0]}.`,
      400,
    );
  }
}

export function requireExactKeys(
  body: Record<string, unknown>,
  required: readonly string[],
): void {
  const missing = required.filter((key) => !Object.hasOwn(body, key));
  if (missing.length > 0) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      `Missing request field: ${missing[0]}.`,
      400,
    );
  }
}

export function requireString(
  body: Record<string, unknown>,
  key: string,
  minLength: number,
  maxLength: number,
): string {
  const value = body[key];
  if (typeof value !== "string") {
    throw new CompanionRuntimeError(
      "invalid_payload",
      `${key} must be a string.`,
      400,
    );
  }
  const trimmed = value.trim();
  if (trimmed.length < minLength || trimmed.length > maxLength) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      `${key} must be between ${minLength} and ${maxLength} characters.`,
      400,
    );
  }
  return trimmed;
}

export function requireUuid(
  body: Record<string, unknown>,
  key: string,
): string {
  const value = requireString(body, key, 36, 36).toLowerCase();
  if (!isUuid(value)) {
    throw new CompanionRuntimeError(
      "invalid_payload",
      `${key} must be a UUID.`,
      400,
    );
  }
  return value;
}

export function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

export function objectValue(
  value: unknown,
): Record<string, unknown> | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

export function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...companionCorsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
