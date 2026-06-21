import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import postgres from "npm:postgres@3.4.5";

type CompanionReplyKind = "prediction" | "chat";
type CompanionReplyFeature =
  | "panel_chat"
  | "companion_chat"
  | "prediction"
  | "practice"
  | "playbook"
  | "moment_comment"
  | "daily_decision";

type CompanionReplyRequest = {
  kind?: CompanionReplyKind;
  feature?: CompanionReplyFeature;
  system?: string;
  user?: string;
  maxTokens?: number;
};

type AnthropicMessageResponse = {
  content?: Array<{
    type?: string;
    text?: string;
  }>;
  error?: {
    type?: string;
    message?: string;
  };
  usage?: {
    input_tokens?: number;
    output_tokens?: number;
  };
};

type AuthenticatedClaims = {
  userId: string;
};

type UsageReservation = {
  allowed: boolean;
  event_id: string | null;
  reason: string | null;
  tier: string;
  minute_used: number;
  hour_used: number;
  daily_used: number;
  daily_limit: number;
};

type UsageStatus = "success" | "failed";

const anthropicMessagesURL = "https://api.anthropic.com/v1/messages";
const anthropicVersion = "2023-06-01";
const defaultModel = "claude-sonnet-4-6";
const maxPromptChars = 18_000;
const minOutputTokens = 64;

const featureOutputCaps: Record<CompanionReplyFeature, number> = {
  panel_chat: 320,
  companion_chat: 320,
  prediction: 1_024,
  practice: 220,
  playbook: 220,
  moment_comment: 140,
  daily_decision: 180,
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json",
  "Connection": "keep-alive",
};

let sqlClient: ReturnType<typeof postgres> | null = null;

class UsageLimitError extends Error {
  constructor(readonly reservation: UsageReservation) {
    super(reservation.reason ?? "usage_limit");
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: jsonHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: { message: "Method not allowed" } }, 405);
  }

  const claims = authenticatedClaims(req);
  if (!claims) {
    return json({ error: { message: "Please sign in before using AI guides." } }, 401);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY")?.trim();
  if (!apiKey) {
    return json({ error: { message: "AI guide key is not configured." } }, 500);
  }

  let payload: CompanionReplyRequest;
  try {
    payload = await req.json();
  } catch {
    return json({ error: { message: "Invalid JSON body." } }, 400);
  }

  const kind = payload.kind === "prediction" ? "prediction" : "chat";
  const feature = normalizeFeature(payload.feature, kind);
  const system = cleanText(payload.system);
  const user = cleanText(payload.user);
  if (!system || !user) {
    return json({ error: { message: "System and user prompts are required." } }, 400);
  }

  const model = Deno.env.get("ANTHROPIC_MODEL")?.trim() || defaultModel;
  const maxTokens = clampOutputTokens(payload.maxTokens, feature);

  let reservation: UsageReservation;
  try {
    reservation = await reserveUsage(claims.userId, feature, model, maxTokens);
  } catch (error) {
    if (error instanceof UsageLimitError) {
      return json(
        {
          error: {
            code: error.reservation.reason ?? "usage_limit",
            message: limitMessage(error.reservation),
          },
        },
        429,
      );
    }

    console.error("companion-reply guardrail error", {
      errorType: safeErrorType(error),
      feature,
      model,
    });
    return json(
      { error: { message: "AI guide limits are unavailable right now. Please try again." } },
      503,
    );
  }

  const eventId = reservation.event_id;
  if (!eventId) {
    return json({ error: { message: "AI guide limits are unavailable right now. Please try again." } }, 503);
  }
  let response: Response;
  try {
    response = await fetch(anthropicMessagesURL, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": anthropicVersion,
      },
      body: JSON.stringify({
        model,
        max_tokens: maxTokens,
        system: systemPromptFor(kind, system),
        messages: [
          {
            role: "user",
            content: user,
          },
        ],
      }),
    });
  } catch (error) {
    await finalizeUsage(eventId, "failed", 0, 0, 0, "network_error");
    console.error("companion-reply anthropic network error", {
      eventId,
      feature,
      model,
      errorType: safeErrorType(error),
    });
    return json(
      { error: { message: "The AI guide is unavailable right now. Please try again." } },
      502,
    );
  }

  let body: AnthropicMessageResponse | null = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }

  const inputTokens = safeTokenCount(body?.usage?.input_tokens);
  const outputTokens = safeTokenCount(body?.usage?.output_tokens);
  const estimatedMicroUSD = estimateMicroUSD(model, inputTokens, outputTokens);

  if (!response.ok) {
    const errorType = body?.error?.type ?? `anthropic_${response.status}`;
    await finalizeUsage(eventId, "failed", inputTokens, outputTokens, estimatedMicroUSD, errorType);
    console.error("companion-reply anthropic error", {
      eventId,
      feature,
      model,
      status: response.status,
      errorType,
    });
    return json(
      { error: { message: "The AI guide is unavailable right now. Please try again." } },
      502,
    );
  }

  const text = extractText(body);
  if (!text) {
    await finalizeUsage(eventId, "failed", inputTokens, outputTokens, estimatedMicroUSD, "empty_response");
    return json({ error: { message: "The AI guide returned an empty reply." } }, 502);
  }

  await finalizeUsage(eventId, "success", inputTokens, outputTokens, estimatedMicroUSD, null);
  console.info("companion-reply success", {
    eventId,
    feature,
    model,
    inputTokens,
    outputTokens,
    estimatedMicroUSD,
  });

  return json({ text, usageEventId: eventId });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: jsonHeaders,
  });
}

function cleanText(value: unknown): string {
  return typeof value === "string"
    ? value.trim().slice(0, maxPromptChars)
    : "";
}

function normalizeFeature(
  feature: CompanionReplyFeature | undefined,
  kind: CompanionReplyKind,
): CompanionReplyFeature {
  if (feature && feature in featureOutputCaps) {
    return feature;
  }

  return kind === "prediction" ? "prediction" : "companion_chat";
}

function clampOutputTokens(value: unknown, feature: CompanionReplyFeature): number {
  const cap = featureOutputCaps[feature];
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return Math.min(512, cap);
  }

  return Math.max(minOutputTokens, Math.min(Math.trunc(value), cap));
}

function authenticatedClaims(req: Request): AuthenticatedClaims | null {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match?.[1]) {
    return null;
  }

  const parts = match[1].split(".");
  if (parts.length !== 3) {
    return null;
  }

  try {
    const claims = JSON.parse(base64URLDecode(parts[1])) as {
      role?: string;
      sub?: string;
    };
    if (claims.role !== "authenticated" || !claims.sub) {
      return null;
    }
    return { userId: claims.sub };
  } catch {
    return null;
  }
}

function base64URLDecode(value: string): string {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  return atob(padded);
}

function systemPromptFor(kind: CompanionReplyKind, system: string): string {
  if (kind === "prediction") {
    return [
      system,
      "Return only the JSON object requested by the app. Do not wrap it in markdown.",
    ].join("\n\n");
  }

  return [
    system,
    "Return only the guide reply text. Do not include markdown, labels, or analysis.",
  ].join("\n\n");
}

function extractText(body: AnthropicMessageResponse | null): string {
  const blocks = body?.content ?? [];
  return blocks
    .filter((block) => block.type === "text" && typeof block.text === "string")
    .map((block) => block.text?.trim() ?? "")
    .filter(Boolean)
    .join("\n\n")
    .trim();
}

function database(): ReturnType<typeof postgres> {
  if (sqlClient) {
    return sqlClient;
  }

  const databaseURL = Deno.env.get("SUPABASE_DB_URL")?.trim();
  if (!databaseURL) {
    throw new Error("database_unconfigured");
  }

  sqlClient = postgres(databaseURL, {
    max: 1,
    prepare: false,
    idle_timeout: 20,
    connect_timeout: 10,
  });
  return sqlClient;
}

async function reserveUsage(
  userId: string,
  feature: CompanionReplyFeature,
  model: string,
  maxTokens: number,
): Promise<UsageReservation> {
  const sql = database();
  const rows = await sql<UsageReservation[]>`
    select *
    from private.reserve_ai_usage(${userId}::uuid, ${feature}, ${model}, ${maxTokens})
  `;
  const reservation = rows[0];
  if (!reservation) {
    throw new Error("usage_reservation_missing");
  }
  if (!reservation.allowed) {
    throw new UsageLimitError(reservation);
  }
  return reservation;
}

async function finalizeUsage(
  eventId: string,
  status: UsageStatus,
  inputTokens: number,
  outputTokens: number,
  estimatedMicroUSD: number,
  errorType: string | null,
): Promise<void> {
  try {
    const sql = database();
    await sql`
      select private.finalize_ai_usage(
        ${eventId}::uuid,
        ${status},
        ${inputTokens},
        ${outputTokens},
        ${Math.trunc(estimatedMicroUSD)},
        ${errorType}
      )
    `;
  } catch (error) {
    console.error("companion-reply finalize error", {
      eventId,
      status,
      errorType: safeErrorType(error),
    });
  }
}

function safeTokenCount(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.max(0, Math.trunc(value))
    : 0;
}

function estimateMicroUSD(model: string, inputTokens: number, outputTokens: number): number {
  const pricing = pricingMicroUSDPerToken(model);
  return inputTokens * pricing.input + outputTokens * pricing.output;
}

function pricingMicroUSDPerToken(model: string): { input: number; output: number } {
  const normalized = model.toLowerCase();
  if (normalized.includes("opus")) {
    return { input: 5, output: 25 };
  }
  if (normalized.includes("haiku")) {
    return { input: 1, output: 5 };
  }
  return { input: 3, output: 15 };
}

function limitMessage(reservation: UsageReservation): string {
  switch (reservation.reason) {
    case "minute_limit":
      return "Give the AI guides a moment, then try again.";
    case "hour_limit":
      return "You have reached the hourly AI guide limit. Try again a little later.";
    case "daily_limit":
      return "You have reached today's AI guide limit.";
    default:
      return "AI guides are taking a short pause. Try again soon.";
  }
}

function safeErrorType(error: unknown): string {
  return error instanceof Error ? error.message.slice(0, 120) : "unknown_error";
}
