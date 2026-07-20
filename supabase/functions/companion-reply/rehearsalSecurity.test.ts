import {
  isCurrentPrimaryCompanion,
  redactRehearsalForProvider,
} from "./rehearsalSecurity.ts";

Deno.test("rehearsal coach must match the one active primary relationship", () => {
  const rows = [{
    companion_id: "aries-amara",
    status: "active",
    is_primary: true,
  }, {
    companion_id: "taurus-theo",
    status: "active",
    is_primary: false,
  }];
  assertEquals(isCurrentPrimaryCompanion(rows, "aries-amara"), true);
  assertEquals(isCurrentPrimaryCompanion(rows, "taurus-theo"), false);
  assertEquals(
    isCurrentPrimaryCompanion([{
      companion_id: "aries-amara",
      status: "archived",
      is_primary: true,
    }], "aries-amara"),
    false,
  );
});

Deno.test("rehearsal redacts user and partner text before provider prompting", () => {
  const sanitized = redactRehearsalForProvider({
    mode: "coach",
    personaName: "Maria",
    goal: "Ask about https://private.example/a",
    personaNotes: "Email maria@example.com",
    coachCompanionId: "aries-amara",
    transcript: [{
      role: "user",
      content: "Call me at +1 (415) 555-0199",
    }, {
      role: "partner",
      content: "Use maria@example.com instead",
    }],
  });
  assertStringIncludes(sanitized.goal, "[link]");
  assertStringIncludes(sanitized.personaNotes ?? "", "[email]");
  assertStringIncludes(sanitized.transcript?.[0].content ?? "", "[phone]");
  assertStringIncludes(sanitized.transcript?.[1].content ?? "", "[email]");
  assertEquals(JSON.stringify(sanitized).includes("555-0199"), false);
  assertEquals(JSON.stringify(sanitized).includes("maria@example.com"), false);
});

function assertEquals(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}

function assertStringIncludes(actual: string, expected: string): void {
  if (!actual.includes(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(actual)} to include ${expected}`,
    );
  }
}
