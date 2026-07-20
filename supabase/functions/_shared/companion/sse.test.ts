import { chunkText, completedTextStream, encodeCompanionSse } from "./sse.ts";

Deno.test("SSE encoder emits named JSON events", () => {
  const text = new TextDecoder().decode(
    encodeCompanionSse("delta", { text: "hello" }),
  );
  assertEquals(text, 'event: delta\ndata: {"text":"hello"}\n\n');
});

Deno.test("SSE text chunks preserve Unicode scalar pairs", () => {
  const chunks = chunkText("A🌙BC", 2);
  assertEquals(chunks, ["A🌙", "BC"]);
  assertEquals(chunks.join(""), "A🌙BC");
});

Deno.test("completed stream orders meta, delta, and done", async () => {
  const response = completedTextStream({
    text: "grounded clarity",
    meta: { companionId: "taurus-theo" },
    done: { messagePersisted: true },
    chunkCharacters: 8,
  });
  const body = await response.text();
  const meta = body.indexOf("event: meta");
  const delta = body.indexOf("event: delta");
  const done = body.indexOf("event: done");
  assert(meta >= 0 && delta > meta && done > delta);
  assert(body.includes('"messagePersisted":true'));
  assert(body.includes('"text":"grounded clarity"'));
});

function assert(condition: boolean): void {
  if (!condition) throw new Error("Assertion failed");
}

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
