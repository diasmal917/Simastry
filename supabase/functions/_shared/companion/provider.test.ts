import { AnthropicTextProvider } from "./provider.ts";

Deno.test("provider retries a bounded transient failure once", async () => {
  const previous = Deno.env.get("ANTHROPIC_API_KEY");
  Deno.env.set("ANTHROPIC_API_KEY", "test-key");
  let calls = 0;
  const fakeFetch: typeof fetch = (_input, _init) => {
    calls += 1;
    if (calls === 1) {
      return Promise.resolve(new Response("overloaded", { status: 529 }));
    }
    return Promise.resolve(Response.json({
      content: [{ type: "text", text: "A bounded answer." }],
      usage: { input_tokens: 12, output_tokens: 7 },
    }));
  };
  try {
    const provider = new AnthropicTextProvider(
      fakeFetch,
      () => Promise.resolve(),
      2,
    );
    const result = await provider.generate({
      system: "approved",
      user: "hello",
      maxTokens: 100,
    });
    assertEquals(result.text, "A bounded answer.");
    assertEquals(result.usage?.inputTokens, 12);
    assertEquals(result.usage?.outputTokens, 7);
    assertEquals(calls, 2);
  } finally {
    if (previous === undefined) Deno.env.delete("ANTHROPIC_API_KEY");
    else Deno.env.set("ANTHROPIC_API_KEY", previous);
  }
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (actual !== expected) {
    throw new Error(`Expected ${expected}, got ${actual}`);
  }
}
