import { companionCorsHeaders } from "./http.ts";

export type CompanionSseEvent = "meta" | "delta" | "done" | "error";

const encoder = new TextEncoder();

export function encodeCompanionSse(
  event: CompanionSseEvent,
  data: unknown,
): Uint8Array {
  return encoder.encode(`event: ${event}\ndata: ${JSON.stringify(data)}\n\n`);
}

export function companionStreamHeaders(): HeadersInit {
  return {
    ...companionCorsHeaders,
    "Content-Type": "text/event-stream; charset=utf-8",
    "Cache-Control": "no-cache, no-store, no-transform",
    Connection: "keep-alive",
    "X-Accel-Buffering": "no",
  };
}

export function completedTextStream(
  args: Readonly<{
    text: string;
    meta: Record<string, unknown>;
    done: Record<string, unknown>;
    chunkCharacters?: number;
  }>,
): Response {
  const chunks = chunkText(args.text, args.chunkCharacters ?? 48);
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(encodeCompanionSse("meta", args.meta));
      for (const chunk of chunks) {
        controller.enqueue(encodeCompanionSse("delta", { text: chunk }));
      }
      controller.enqueue(encodeCompanionSse("done", {
        ...args.done,
        text: args.text,
      }));
      controller.close();
    },
  });
  return new Response(stream, {
    status: 200,
    headers: companionStreamHeaders(),
  });
}

export function errorTextStream(
  code: string,
  message: string,
  status: number,
): Response {
  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(encodeCompanionSse("error", { code, message }));
      controller.close();
    },
  });
  return new Response(stream, {
    status,
    headers: companionStreamHeaders(),
  });
}

export function chunkText(text: string, maximumCharacters: number): string[] {
  const characters = Array.from(text);
  const size = Math.max(1, Math.round(maximumCharacters));
  const chunks: string[] = [];
  for (let index = 0; index < characters.length; index += size) {
    chunks.push(characters.slice(index, index + size).join(""));
  }
  return chunks;
}
