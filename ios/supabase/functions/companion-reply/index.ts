// Supabase Edge Function: companion-reply
//
// Server-side proxy for Simastry's AI readings so the Anthropic API key
// never ships inside the app binary. JWT verification is on by default —
// only signed-in users can invoke it.
//
// Deploy:
//   supabase functions deploy companion-reply
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Request:  POST { kind: "prediction" | "chat", system: string, user: string, maxTokens?: number }
// Response: 200 { text: string } | 4xx/5xx { error: string }

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const MODEL = "claude-sonnet-4-6";
const DEFAULT_MAX_TOKENS = 1024;
const MAX_ALLOWED_TOKENS = 2048;
const MAX_PROMPT_CHARS = 24_000;

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return json({ error: "Prediction channel not configured" }, 503);
  }

  let payload: { kind?: string; system?: string; user?: string; maxTokens?: number };
  try {
    payload = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { kind, system, user } = payload;
  if (
    (kind !== "prediction" && kind !== "chat") ||
    typeof system !== "string" || system.length === 0 ||
    typeof user !== "string" || user.length === 0
  ) {
    return json({ error: "Expected { kind, system, user }" }, 400);
  }

  if (system.length + user.length > MAX_PROMPT_CHARS) {
    return json({ error: "Prompt too long" }, 413);
  }

  const maxTokens = Math.min(
    Math.max(1, payload.maxTokens ?? DEFAULT_MAX_TOKENS),
    MAX_ALLOWED_TOKENS,
  );

  const anthropicResponse = await fetch(ANTHROPIC_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: maxTokens,
      system,
      messages: [{ role: "user", content: user }],
    }),
  });

  if (anthropicResponse.status === 429) {
    return json({ error: "The stars are busy — try again in a moment." }, 429);
  }

  if (!anthropicResponse.ok) {
    return json({ error: "The reading service had a hiccup. Try again." }, 502);
  }

  const body = await anthropicResponse.json();
  const text = body?.content?.[0]?.text;
  if (typeof text !== "string" || text.length === 0) {
    return json({ error: "Empty reading" }, 502);
  }

  return json({ text }, 200);
});

function json(body: Record<string, unknown>, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
