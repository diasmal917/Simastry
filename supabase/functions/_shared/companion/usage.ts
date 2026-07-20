import { CompanionRuntimeError, requiredEnv } from "./errors.ts";

export type CompanionUsageFeature =
  | "companion_chat"
  | "companion_decode";

export type CompanionTokenSource =
  | "provider"
  | "deterministic"
  | "unavailable";

export type CompanionUsageReservationRequest = Readonly<{
  userId: string;
  feature: CompanionUsageFeature;
  personaId: string;
  personaVersion: string;
  modelProvider: string;
  model: string;
  requestMaxTokens: number;
  requestCharacters: number;
  requestKey?: string;
}>;

export type CompanionUsageReservation = Readonly<{
  id: string | null;
}>;

export type CompanionUsageFinalization = Readonly<{
  userId: string;
  usageEventId: string | null;
  status: "success" | "failed";
  modelProvider: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  responseCharacters: number;
  tokenSource: CompanionTokenSource;
  errorCode: string | null;
}>;

export type CompanionUsageLedger = Readonly<{
  reserve(
    request: CompanionUsageReservationRequest,
  ): Promise<CompanionUsageReservation>;
  finalize(finalization: CompanionUsageFinalization): Promise<void>;
}>;

type ReservationRow = Readonly<{
  usage_event_id: string;
  allowed: boolean;
  limit_label: string | null;
}>;

export class SupabaseCompanionUsageLedger implements CompanionUsageLedger {
  readonly #fetch: typeof fetch;

  constructor(fetchImplementation: typeof fetch = fetch) {
    this.#fetch = fetchImplementation;
  }

  async reserve(
    request: CompanionUsageReservationRequest,
  ): Promise<CompanionUsageReservation> {
    const limits = limitsForFeature(request.feature);
    const response = await this.#rpc("reserve_companion_ai_usage", {
      p_user_id: request.userId,
      p_feature: request.feature,
      p_persona_id: request.personaId,
      p_persona_version: request.personaVersion,
      p_model_provider: request.modelProvider,
      p_model: request.model,
      p_request_max_tokens: request.requestMaxTokens,
      p_request_characters: request.requestCharacters,
      p_request_key: request.requestKey ?? null,
      p_per_minute_limit: limits.perMinute,
      p_per_day_limit: limits.perDay,
    });
    const row = reservationRow(response);
    if (!row) {
      throw backendUnavailable();
    }
    if (!row.allowed) {
      throw new CompanionRuntimeError(
        "ai_usage_limit",
        limitMessage(request.feature, row.limit_label),
        429,
      );
    }
    return Object.freeze({ id: row.usage_event_id });
  }

  async finalize(finalization: CompanionUsageFinalization): Promise<void> {
    if (!finalization.usageEventId) return;
    const result = await this.#rpc("finalize_companion_ai_usage", {
      p_user_id: finalization.userId,
      p_usage_event_id: finalization.usageEventId,
      p_status: finalization.status,
      p_model_provider: finalization.modelProvider,
      p_model: finalization.model,
      p_input_tokens: finalization.inputTokens,
      p_output_tokens: finalization.outputTokens,
      p_response_characters: finalization.responseCharacters,
      p_token_source: finalization.tokenSource,
      p_error_code: finalization.errorCode,
    });
    if (result !== true) throw backendUnavailable();
  }

  async #rpc(name: string, body: Record<string, unknown>): Promise<unknown> {
    const response = await this.#fetch(
      `${requiredEnv("SUPABASE_URL")}/rest/v1/rpc/${name}`,
      {
        method: "POST",
        headers: {
          apikey: requiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
          authorization: `Bearer ${requiredEnv("SUPABASE_SERVICE_ROLE_KEY")}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
      },
    );
    if (!response.ok) {
      await response.text();
      console.error(JSON.stringify({
        event: "companion_usage_rpc_failed",
        rpc: name,
        status: response.status,
      }));
      throw backendUnavailable();
    }
    const text = await response.text();
    if (!text) return null;
    try {
      return JSON.parse(text);
    } catch {
      throw backendUnavailable();
    }
  }
}

export const NOOP_COMPANION_USAGE_LEDGER: CompanionUsageLedger = Object.freeze({
  reserve: () => Promise.resolve(Object.freeze({ id: null })),
  finalize: () => Promise.resolve(),
});

export async function safelyFinalizeCompanionUsage(
  ledger: CompanionUsageLedger,
  finalization: CompanionUsageFinalization,
): Promise<boolean> {
  if (!finalization.usageEventId) return true;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      await ledger.finalize(finalization);
      return true;
    } catch (error) {
      console.error(JSON.stringify({
        event: "companion_usage_finalize_failed",
        usageEventId: finalization.usageEventId,
        attempt,
        willRetry: attempt < 3,
        error: error instanceof Error ? error.message : String(error),
      }));
      if (attempt < 3) {
        await new Promise((resolve) => setTimeout(resolve, attempt * 25));
      }
    }
  }
  return false;
}

export function tokenSource(
  modelProvider: string,
  usage: Readonly<{ inputTokens: number; outputTokens: number }> | undefined,
): CompanionTokenSource {
  if (modelProvider === "simastry_safety") return "deterministic";
  return usage ? "provider" : "unavailable";
}

function reservationRow(value: unknown): ReservationRow | null {
  const candidate = Array.isArray(value) ? value[0] : value;
  if (!candidate || typeof candidate !== "object" || Array.isArray(candidate)) {
    return null;
  }
  const row = candidate as Record<string, unknown>;
  if (
    typeof row.usage_event_id !== "string" ||
    typeof row.allowed !== "boolean" ||
    !(row.limit_label === null || typeof row.limit_label === "string")
  ) {
    return null;
  }
  return {
    usage_event_id: row.usage_event_id,
    allowed: row.allowed,
    limit_label: row.limit_label,
  };
}

function limitsForFeature(
  feature: CompanionUsageFeature,
): Readonly<{ perMinute: number; perDay: number }> {
  if (feature === "companion_decode") {
    return Object.freeze({
      perMinute: positiveIntegerEnv(
        "SIMASTRY_DECODE_PER_MINUTE_LIMIT",
        12,
      ),
      perDay: positiveIntegerEnv("SIMASTRY_DECODE_PER_DAY_LIMIT", 300),
    });
  }
  return Object.freeze({
    perMinute: positiveIntegerEnv(
      "SIMASTRY_COMPANION_PER_MINUTE_LIMIT",
      20,
    ),
    perDay: positiveIntegerEnv("SIMASTRY_COMPANION_PER_DAY_LIMIT", 300),
  });
}

function positiveIntegerEnv(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isInteger(value) && value > 0 && value <= 100_000
    ? value
    : fallback;
}

function limitMessage(
  feature: CompanionUsageFeature,
  label: string | null,
): string {
  if (label === "per_minute") {
    return "You are asking very quickly. Please wait a minute and try again.";
  }
  const noun = feature === "companion_decode" ? "Decode" : "companion";
  return `You have reached today's ${noun} limit. Please try again tomorrow.`;
}

function backendUnavailable(): CompanionRuntimeError {
  return new CompanionRuntimeError(
    "backend_unavailable",
    "The companion service is unavailable right now. Please try again.",
    503,
  );
}
