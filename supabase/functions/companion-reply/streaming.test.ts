import {
  anthropicErrorFromSseBlock,
  anthropicTextDeltaFromSseBlock,
  encodeSseEvent,
  shouldStreamReply,
} from "./streaming.ts";

Deno.test("shouldStreamReply preserves JSON default and supports opt-in SSE", () => {
  const jsonRequest = new Request(
    "https://example.test/functions/v1/companion-reply",
    {
      method: "POST",
    },
  );
  assertEquals(shouldStreamReply(jsonRequest), false);

  const acceptRequest = new Request(
    "https://example.test/functions/v1/companion-reply",
    {
      method: "POST",
      headers: { accept: "text/event-stream" },
    },
  );
  assertEquals(shouldStreamReply(acceptRequest), true);
  assertEquals(shouldStreamReply(jsonRequest, { stream: true }), true);
});

Deno.test("encodeSseEvent emits named JSON events", () => {
  const decoded = new TextDecoder().decode(
    encodeSseEvent("delta", { text: "hello" }),
  );
  assertEquals(decoded, 'event: delta\ndata: {"text":"hello"}\n\n');
});

Deno.test("anthropicTextDeltaFromSseBlock returns only assistant text deltas", () => {
  const textBlock = [
    "event: content_block_delta",
    'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Leyla"}}',
  ].join("\n");
  assertEquals(anthropicTextDeltaFromSseBlock(textBlock), "Leyla");

  const nonTextBlock = [
    "event: content_block_delta",
    'data: {"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"private"}}',
  ].join("\n");
  assertEquals(anthropicTextDeltaFromSseBlock(nonTextBlock), null);
});

Deno.test("anthropicErrorFromSseBlock extracts provider failures", () => {
  const errorBlock = [
    "event: error",
    'data: {"type":"error","error":{"type":"overloaded_error","message":"Provider overloaded"}}',
  ].join("\n");
  assertEquals(anthropicErrorFromSseBlock(errorBlock), {
    code: "overloaded_error",
    message: "Provider overloaded",
  });
});

function assertEquals(actual: unknown, expected: unknown) {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`Expected ${expectedJson}, got ${actualJson}`);
  }
}
