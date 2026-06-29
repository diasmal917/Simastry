import { buildPrompt, type CompanionReplyPayload } from "./specialistPrompt.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (request: Request): Promise<Response> => {
  const startedAt = Date.now();
  let payload: CompanionReplyPayload | undefined;
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return jsonResponse({ error: { message: "Method not allowed." } }, 405);
  }

  try {
    payload = await request.json() as CompanionReplyPayload;
    logReplyEvent("companion_reply_started", payload, startedAt);
    const prompt = buildPrompt(payload);
    const text = await callAnthropic(prompt.system, prompt.user, payload.maxTokens ?? 512);
    logReplyEvent("companion_reply_completed", payload, startedAt, { responseCharacters: text.length });
    return jsonResponse({ text, usageEventId: null }, 200);
  } catch (error) {
    const message = error instanceof Error ? error.message : "The AI guide is unavailable right now.";
    logReplyEvent("companion_reply_failed", payload, startedAt, { error: message });
    return jsonResponse({ error: { message } }, 400);
  }
});

async function callAnthropic(system: string, user: string, maxTokens: number): Promise<string> {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    throw new Error("ANTHROPIC_API_KEY is not configured.");
  }
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
    throw new Error("The AI guide is unavailable right now. Please try again.");
  }

  const body = await response.json();
  const text = body?.content
    ?.filter((part: { type?: string }) => part.type === "text")
    ?.map((part: { text?: string }) => part.text ?? "")
    ?.join("\n")
    ?.trim();
  if (!text) {
    throw new Error("The AI guide answered in an unexpected format.");
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

function clampMaxTokens(value: number): number {
  if (!Number.isFinite(value)) return 512;
  return Math.max(64, Math.min(1200, Math.round(value)));
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
