import { buildPrompt, normalizedSpecialistId, type CompanionReplyPayload } from "./specialistPrompt.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-simastry-device-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type AuthenticatedUser = {
  id: string;
};

type UsageLimit = {
  windowMs: number;
  maxEvents: number;
  label: string;
};

type UsageEvent = {
  id: string;
  userId: string;
  deviceId: string | null;
  payload: CompanionReplyPayload;
  requestCharacters: number;
};

const usageLimits: UsageLimit[] = [
  {
    windowMs: 60_000,
    maxEvents: integerEnv("SIMASTRY_AI_PER_MINUTE_LIMIT", 20),
    label: "per_minute",
  },
  {
    windowMs: 60 * 60_000,
    maxEvents: integerEnv("SIMASTRY_AI_PER_HOUR_LIMIT", 150),
    label: "per_hour",
  },
  {
    windowMs: 24 * 60 * 60_000,
    maxEvents: integerEnv("SIMASTRY_AI_PER_DAY_LIMIT", 300),
    label: "per_day",
  },
];

const deviceUsageLimits: UsageLimit[] = [
  {
    windowMs: 60_000,
    maxEvents: integerEnv("SIMASTRY_AI_DEVICE_PER_MINUTE_LIMIT", 25),
    label: "device_per_minute",
  },
  {
    windowMs: 24 * 60 * 60_000,
    maxEvents: integerEnv("SIMASTRY_AI_DEVICE_PER_DAY_LIMIT", 400),
    label: "device_per_day",
  },
];

Deno.serve(async (request: Request): Promise<Response> => {
  const startedAt = Date.now();
  let payload: CompanionReplyPayload | undefined;
  let usageEvent: UsageEvent | undefined;

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: { code: "method_not_allowed", message: "Method not allowed." } }, 405);
  }

  try {
    const user = await authenticateRequest(request);
    const deviceId = normalizedDeviceId(request.headers.get("x-simastry-device-id"));
    payload = await readPayload(request);
    validatePayload(payload);
    payload = normalizePayload(payload);

    const requestCharacters = estimateRequestCharacters(payload);
    const limit = await firstUsageLimitExceeded(user.id, deviceId);
    if (limit) {
      await insertLimitedUsageEvent(user.id, deviceId, payload, requestCharacters, limit.label);
      logReplyEvent("companion_reply_limited", payload, startedAt, {
        userId: user.id,
        deviceId,
        limit: limit.label,
      });
      return jsonResponse({
        error: {
          code: "ai_usage_limit",
          message: limitMessage(limit),
        },
      }, 429);
    }

    usageEvent = await insertUsageEvent(user.id, deviceId, payload, requestCharacters);
    logReplyEvent("companion_reply_started", payload, startedAt, {
      userId: user.id,
      deviceId,
      usageEventId: usageEvent.id,
    });

    const prompt = buildPrompt(payload);
    const text = await callAnthropic(prompt.system, prompt.user, payload.maxTokens ?? 512);
    await safeUpdateUsageEvent(usageEvent.id, "success", text.length);
    logReplyEvent("companion_reply_completed", payload, startedAt, {
      userId: user.id,
      deviceId,
      usageEventId: usageEvent.id,
      responseCharacters: text.length,
    });
    return jsonResponse({ text, usageEventId: usageEvent.id }, 200);
  } catch (error) {
    const companionError = toCompanionReplyError(error);
    if (usageEvent) {
      await safeUpdateUsageEvent(usageEvent.id, "failed", 0, companionError.code);
    }
    logReplyEvent("companion_reply_failed", payload, startedAt, {
      errorCode: companionError.code,
      status: companionError.status,
    });
    return jsonResponse({
      error: {
        code: companionError.code,
        message: companionError.message,
      },
    }, companionError.status);
  }
});

async function readPayload(request: Request): Promise<CompanionReplyPayload> {
  const contentLength = request.headers.get("content-length");
  if (contentLength && Number(contentLength) > 32_000) {
    throw new CompanionReplyError("payload_too_large", "The request is too large.", 413);
  }

  try {
    return await request.json() as CompanionReplyPayload;
  } catch {
    throw new CompanionReplyError("invalid_json", "The request body must be valid JSON.", 400);
  }
}

async function authenticateRequest(request: Request): Promise<AuthenticatedUser> {
  const authHeader = request.headers.get("authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new CompanionReplyError("auth_required", "Please sign in again before continuing.", 401);
  }

  const supabaseUrl = requiredEnv("SUPABASE_URL");
  const anonKey = requiredEnv("SUPABASE_ANON_KEY");
  const response = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      "apikey": anonKey,
      "authorization": `Bearer ${match[1]}`,
    },
  });

  if (!response.ok) {
    throw new CompanionReplyError("auth_required", "Please sign in again before continuing.", 401);
  }

  const body = await response.json();
  if (!body?.id || typeof body.id !== "string") {
    throw new CompanionReplyError("auth_required", "Please sign in again before continuing.", 401);
  }
  return { id: body.id };
}

function validatePayload(payload: CompanionReplyPayload) {
  if (!payload || typeof payload !== "object") {
    throw new CompanionReplyError("invalid_payload", "The AI request is missing.", 400);
  }

  if (payload.maxTokens !== undefined && (!Number.isFinite(payload.maxTokens) || payload.maxTokens < 1)) {
    throw new CompanionReplyError("invalid_payload", "The max token request is invalid.", 400);
  }

  if (payload.feature === "expert_astrologer") {
    const expert = payload.expertAstrologerRequest;
    if (!expert) {
      throw new CompanionReplyError("invalid_payload", "The specialist request is missing.", 400);
    }
    if (!normalizedSpecialistId(expert.specialistId)) {
      throw new CompanionReplyError("invalid_specialist", "Unknown astrology specialist.", 400);
    }
    validateText("userQuestion", expert.userQuestion, 1, 1_500);
    if (expert.transcript && expert.transcript.length > 24) {
      throw new CompanionReplyError("payload_too_large", "The conversation transcript is too long.", 413);
    }
    for (const message of expert.transcript ?? []) {
      validateText("transcript.content", message.content, 1, 2_000);
    }
    validateOptionalStringArray("knownDataPoints", expert.knownDataPoints, 80, 160);
    validateOptionalStringArray("missingDataPoints", expert.missingDataPoints, 120, 220);
    validateOptionalStringArray("dataLimitations", expert.dataLimitations, 120, 320);
    validateOptionalRecord("userSuppliedTraditionData", expert.userSuppliedTraditionData, 24, 500);
    validateOptionalRecord("calculatedTraditionData", expert.calculatedTraditionData, 24, 500);
    if (expert.readinessSummary !== undefined) {
      validateText("readinessSummary", expert.readinessSummary, 1, 800);
    }
    return;
  }

  validateText("system", payload.system, 1, 8_000);
  validateText("user", payload.user, 1, 8_000);
}

function normalizePayload(payload: CompanionReplyPayload): CompanionReplyPayload {
  const expert = payload.expertAstrologerRequest;
  if (!expert) return payload;
  const specialistId = normalizedSpecialistId(expert.specialistId);
  if (!specialistId) return payload;
  return {
    ...payload,
    expertAstrologerRequest: {
      ...expert,
      specialistId,
      userQuestion: expert.userQuestion.trim(),
      transcript: (expert.transcript ?? []).slice(-16).map((message) => ({
        ...message,
        content: message.content.trim().slice(0, 2_000),
      })),
      knownDataPoints: sanitizeStringArray(expert.knownDataPoints, 80, 160),
      missingDataPoints: sanitizeStringArray(expert.missingDataPoints, 120, 220),
      userSuppliedTraditionData: sanitizeRecord(expert.userSuppliedTraditionData, 24, 500),
      calculatedTraditionData: sanitizeRecord(expert.calculatedTraditionData, 24, 500),
      readinessSummary: expert.readinessSummary?.trim().slice(0, 800),
      dataLimitations: sanitizeStringArray(expert.dataLimitations, 120, 320),
    },
  };
}

function validateText(field: string, value: unknown, min: number, max: number) {
  if (typeof value !== "string") {
    throw new CompanionReplyError("invalid_payload", `Missing ${field}.`, 400);
  }
  const length = value.trim().length;
  if (length < min) {
    throw new CompanionReplyError("invalid_payload", `Missing ${field}.`, 400);
  }
  if (length > max) {
    throw new CompanionReplyError("payload_too_large", `${field} is too long.`, 413);
  }
}

function validateOptionalStringArray(field: string, value: unknown, maxItems: number, maxCharacters: number) {
  if (value === undefined) return;
  if (!Array.isArray(value) || value.length > maxItems) {
    throw new CompanionReplyError("invalid_payload", `${field} is invalid.`, 400);
  }
  for (const item of value) {
    validateText(field, item, 1, maxCharacters);
  }
}

function validateOptionalRecord(field: string, value: unknown, maxItems: number, maxCharacters: number) {
  if (value === undefined) return;
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new CompanionReplyError("invalid_payload", `${field} is invalid.`, 400);
  }
  const entries = Object.entries(value as Record<string, unknown>);
  if (entries.length > maxItems) {
    throw new CompanionReplyError("invalid_payload", `${field} has too many entries.`, 400);
  }
  for (const [key, item] of entries) {
    validateText(`${field}.${key}`, item, 1, maxCharacters);
  }
}

function sanitizeStringArray(value: unknown, maxItems: number, maxCharacters: number): string[] | undefined {
  if (!Array.isArray(value)) return undefined;
  return value
    .slice(0, maxItems)
    .map((item) => String(item).trim().slice(0, maxCharacters))
    .filter(Boolean);
}

function sanitizeRecord(value: unknown, maxItems: number, maxCharacters: number): Record<string, string> | undefined {
  if (!value || typeof value !== "object" || Array.isArray(value)) return undefined;
  const entries = Object.entries(value as Record<string, unknown>)
    .slice(0, maxItems)
    .map(([key, item]) => [key.trim().slice(0, 80), String(item).trim().slice(0, maxCharacters)] as const)
    .filter(([key, item]) => key.length > 0 && item.length > 0);
  return entries.length > 0 ? Object.fromEntries(entries) : undefined;
}

async function firstUsageLimitExceeded(userId: string, deviceId: string | null): Promise<UsageLimit | null> {
  for (const limit of usageLimits) {
    const count = await countUsageEvents({
      userId,
      since: new Date(Date.now() - limit.windowMs),
    });
    if (count >= limit.maxEvents) return limit;
  }

  if (deviceId) {
    for (const limit of deviceUsageLimits) {
      const count = await countUsageEvents({
        deviceId,
        since: new Date(Date.now() - limit.windowMs),
      });
      if (count >= limit.maxEvents) return limit;
    }
  }

  return null;
}

async function countUsageEvents(filters: { userId?: string; deviceId?: string; since: Date }): Promise<number> {
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/ai_usage_events`);
  url.searchParams.set("select", "id");
  url.searchParams.set("created_at", `gte.${filters.since.toISOString()}`);
  url.searchParams.set("status", "in.(reserved,success)");
  url.searchParams.set("limit", "1000");
  if (filters.userId) url.searchParams.set("user_id", `eq.${filters.userId}`);
  if (filters.deviceId) url.searchParams.set("device_id", `eq.${filters.deviceId}`);

  const rows = await supabaseRest<Array<{ id: string }>>(url, { method: "GET" });
  return rows.length;
}

async function insertUsageEvent(
  userId: string,
  deviceId: string | null,
  payload: CompanionReplyPayload,
  requestCharacters: number,
): Promise<UsageEvent> {
  const id = crypto.randomUUID();
  const expert = payload.expertAstrologerRequest;
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/ai_usage_events`);
  const body = {
    id,
    user_id: userId,
    device_id: deviceId,
    feature: payload.feature ?? "unknown",
    model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6",
    kind: payload.kind ?? null,
    specialist_id: expert?.specialistId ?? null,
    mode: expert?.mode ?? null,
    status: "reserved",
    request_max_tokens: clampMaxTokens(payload.maxTokens ?? 512),
    request_characters: requestCharacters,
    response_characters: 0,
    metadata: {
      conversationId: expert?.conversationId ?? null,
      multiConsultationId: expert?.multiConsultationId ?? null,
    },
  };
  await supabaseRest(url, {
    method: "POST",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify(body),
  });
  return { id, userId, deviceId, payload, requestCharacters };
}

async function insertLimitedUsageEvent(
  userId: string,
  deviceId: string | null,
  payload: CompanionReplyPayload,
  requestCharacters: number,
  limitLabel: string,
) {
  const expert = payload.expertAstrologerRequest;
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/ai_usage_events`);
  await supabaseRest(url, {
    method: "POST",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify({
      user_id: userId,
      device_id: deviceId,
      feature: payload.feature ?? "unknown",
      model: Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6",
      kind: payload.kind ?? null,
      specialist_id: expert?.specialistId ?? null,
      mode: expert?.mode ?? null,
      status: "rate_limited",
      request_max_tokens: clampMaxTokens(payload.maxTokens ?? 512),
      request_characters: requestCharacters,
      response_characters: 0,
      error_code: limitLabel,
    }),
  });
}

async function updateUsageEvent(
  id: string,
  status: "success" | "failed",
  responseCharacters: number,
  errorCode?: string,
) {
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/ai_usage_events`);
  url.searchParams.set("id", `eq.${id}`);
  await supabaseRest(url, {
    method: "PATCH",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify({
      status,
      output_tokens: responseCharacters,
      total_tokens: responseCharacters,
      response_characters: responseCharacters,
      finalized_at: new Date().toISOString(),
      error_code: errorCode ?? null,
      error_type: errorCode ?? null,
      updated_at: new Date().toISOString(),
    }),
  });
}

async function safeUpdateUsageEvent(
  id: string,
  status: "success" | "failed",
  responseCharacters: number,
  errorCode?: string,
) {
  try {
    await updateUsageEvent(id, status, responseCharacters, errorCode);
  } catch (error) {
    console.error(JSON.stringify({
      event: "usage_event_update_failed",
      usageEventId: id,
      error: error instanceof Error ? error.message : String(error),
    }));
  }
}

type SupabaseRestInit = {
  method: string;
  headers?: Record<string, string>;
  body?: string;
};

async function supabaseRest<T = unknown>(url: URL, init: SupabaseRestInit): Promise<T> {
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(url, {
    ...init,
    headers: {
      "apikey": serviceRoleKey,
      "authorization": `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error(JSON.stringify({
      event: "supabase_rest_failed",
      status: response.status,
      bodyExcerpt: detail.slice(0, 500),
    }));
    throw new CompanionReplyError("backend_unavailable", "The AI service is unavailable right now. Please try again.", 503);
  }

  if (response.status === 204) {
    return undefined as T;
  }
  const text = await response.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

async function callAnthropic(system: string, user: string, maxTokens: number): Promise<string> {
  const apiKey = requiredEnv("ANTHROPIC_API_KEY");
  const model = Deno.env.get("ANTHROPIC_MODEL") ?? "claude-sonnet-4-6";
  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: clampMaxTokens(maxTokens),
      system,
      messages: [{ role: "user", content: user }],
    }),
  });

  if (!response.ok) {
    const detail = await response.text();
    console.error(JSON.stringify({
      event: "anthropic_request_failed",
      status: response.status,
      bodyExcerpt: detail.slice(0, 800),
    }));
    throw new CompanionReplyError("provider_unavailable", "The AI specialist is unavailable right now. Please try again.", 502);
  }

  const body = await response.json();
  const text = body?.content
    ?.filter((part: { type?: string }) => part.type === "text")
    ?.map((part: { text?: string }) => part.text ?? "")
    ?.join("\n")
    ?.trim();
  if (!text) {
    throw new CompanionReplyError("provider_format", "The AI specialist answered in an unexpected format.", 502);
  }
  return text;
}

function logReplyEvent(
  event: string,
  payload: CompanionReplyPayload | undefined,
  startedAt: number,
  extra: Record<string, unknown> = {},
) {
  const expert = payload?.expertAstrologerRequest;
  console.log(JSON.stringify({
    event,
    feature: payload?.feature ?? "unknown",
    kind: payload?.kind ?? "unknown",
    specialistId: expert?.specialistId ?? null,
    mode: expert?.mode ?? null,
    conversationId: expert?.conversationId ?? null,
    multiConsultationId: expert?.multiConsultationId ?? null,
    latencyMs: Date.now() - startedAt,
    ...extra,
  }));
}

function estimateRequestCharacters(payload: CompanionReplyPayload): number {
  if (payload.expertAstrologerRequest) {
    const expert = payload.expertAstrologerRequest;
    return expert.userQuestion.length
      + (expert.transcript ?? []).reduce((total, message) => total + message.content.length, 0)
      + (expert.profileContext ? JSON.stringify(expert.profileContext).length : 0)
      + (expert.knownDataPoints ? JSON.stringify(expert.knownDataPoints).length : 0)
      + (expert.missingDataPoints ? JSON.stringify(expert.missingDataPoints).length : 0)
      + (expert.userSuppliedTraditionData ? JSON.stringify(expert.userSuppliedTraditionData).length : 0)
      + (expert.calculatedTraditionData ? JSON.stringify(expert.calculatedTraditionData).length : 0)
      + (expert.readinessSummary?.length ?? 0)
      + (expert.dataLimitations ? JSON.stringify(expert.dataLimitations).length : 0);
  }
  return (payload.system?.length ?? 0) + (payload.user?.length ?? 0);
}

function limitMessage(limit: UsageLimit): string {
  switch (limit.label) {
    case "per_minute":
    case "device_per_minute":
      return "You are asking very quickly. Please wait a minute and try again.";
    case "per_hour":
      return "You have reached this hour's AI usage limit. Please try again later.";
    default:
      return "You have reached today's AI usage limit. Please try again tomorrow.";
  }
}

function normalizedDeviceId(value: string | null): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  return /^[A-Za-z0-9._:-]{8,96}$/.test(trimmed) ? trimmed : null;
}

function clampMaxTokens(value: number): number {
  if (!Number.isFinite(value)) return 512;
  return Math.max(64, Math.min(1200, Math.round(value)));
}

function integerEnv(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isFinite(value) && value > 0 ? Math.round(value) : fallback;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new CompanionReplyError("backend_misconfigured", `${name} is not configured.`, 503);
  }
  return value;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

class CompanionReplyError extends Error {
  code: string;
  status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

function toCompanionReplyError(error: unknown): CompanionReplyError {
  if (error instanceof CompanionReplyError) {
    return error;
  }
  if (error instanceof Error) {
    return new CompanionReplyError("unknown_error", error.message, 400);
  }
  return new CompanionReplyError("unknown_error", "The AI specialist is unavailable right now.", 400);
}
