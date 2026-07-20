import { boundedContextObject, boundedContextText } from "./context.ts";

Deno.test("server context bounds oversized records and Unicode text", () => {
  assertEquals(boundedContextText("A🌙BC", 2), "A🌙");
  assertEquals(
    boundedContextObject({ notes: "x".repeat(100) }, 20),
    { contextStatus: "omitted_oversize" },
  );
  assertEquals(boundedContextObject({ sign: "aries" }, 100), {
    sign: "aries",
  });
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
