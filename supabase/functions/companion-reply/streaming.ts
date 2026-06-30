import type { CompanionReplyPayload } from "./specialistPrompt.ts";

export type CompanionReplySseEvent = "meta" | "delta" | "done" | "error";

export type AnthropicStreamError = {
  code: string;
  message: string;
};

const encoder = new TextEncoder();

export function shouldStreamReply(
  request: Request,
  payload?: CompanionReplyPayload,
): boolean {
  if (payload?.stream === true) return true;
  return request.headers.get("accept")?.toLowerCase().includes(
    "text/event-stream",
  ) === true;
}

export function streamHeaders(
  corsHeaders: Record<string, string>,
): HeadersInit {
  return {
    ...corsHeaders,
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-transform",
    "Connection": "keep-alive",
    "X-Accel-Buffering": "no",
  };
}

export function encodeSseEvent(
  event: CompanionReplySseEvent,
  data: unknown,
): Uint8Array {
  return encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

export function anthropicTextDeltaFromSseBlock(block: string): string | null {
  const payload = anthropicPayloadFromSseBlock(block);
  if (!payload || payload.type !== "content_block_delta") return null;
  const delta = objectValue(payload.delta);
  if (!delta || delta.type !== "text_delta" || typeof delta.text !== "string") {
    return null;
  }
  return delta.text;
}

export function anthropicErrorFromSseBlock(
  block: string,
): AnthropicStreamError | null {
  const payload = anthropicPayloadFromSseBlock(block);
  if (!payload || payload.type !== "error") return null;
  const error = objectValue(payload.error);
  return {
    code: typeof error?.type === "string" ? error.type : "provider_unavailable",
    message: typeof error?.message === "string" && error.message.trim()
      ? error.message.trim()
      : "The AI specialist is unavailable right now. Please try again.",
  };
}

function objectValue(value: unknown): Record<string, unknown> | null {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function anthropicPayloadFromSseBlock(
  block: string,
): Record<string, unknown> | null {
  const dataLines = block
    .split("\n")
    .map((line) => line.trimEnd())
    .filter((line) => line.startsWith("data:"))
    .map((line) => line.slice(5).trimStart());
  if (dataLines.length === 0) return null;

  const data = dataLines.join("\n").trim();
  if (!data || data === "[DONE]") return null;

  try {
    const parsed = JSON.parse(data);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed as Record<string, unknown>
      : null;
  } catch {
    return null;
  }
}
