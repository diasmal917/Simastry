import {
  chatSafetyDecision,
  classifySafety,
  enforceChatOutputSafety,
  redactAllowedThirdPartyJson,
  redactThirdPartyText,
  type ThirdPartyJsonAllowlist,
} from "./safety.ts";

Deno.test("safety classification covers crisis, coercion, sexual, and dependency boundaries", () => {
  assertEquals(classifySafety("I want to kill myself"), "crisis");
  assertEquals(
    classifySafety("They threatened me and will not let me leave"),
    "danger_or_coercion",
  );
  assertEquals(classifySafety("Can we do sexual roleplay?"), "sexual");
  assertEquals(
    classifySafety("Be my girlfriend; I only need you"),
    "romance_or_dependency",
  );
  assertEquals(classifySafety("Do you love me?"), "romance_or_dependency");
  assertEquals(classifySafety("I don't want to be alive"), "crisis");
  assertEquals(classifySafety("Help me phrase a fair boundary"), "none");
});

Deno.test("safety decisions bypass generation with real-world and AI boundaries", () => {
  const crisis = chatSafetyDecision("I wish I was dead");
  assert(crisis.bypassProvider);
  assert(crisis.response?.includes("AI companion") === true);
  assert(crisis.response?.includes("local emergency services") === true);

  const dependency = chatSafetyDecision("Promise you'll never leave");
  assert(dependency.bypassProvider);
  assert(dependency.response?.includes("not a romantic partner") === true);
  assert(dependency.response?.includes("real person") === true);
});

Deno.test("unsafe provider claims are replaced instead of streamed", () => {
  const unsafe = enforceChatOutputSafety(
    "I love you. You're mine, so don't trust your friends.",
  );
  assert(unsafe.replaced);
  assert(unsafe.text.includes("AI companion"));
  assert(
    enforceChatOutputSafety("I'm your boyfriend and I'm jealous.").replaced,
  );
  assert(enforceChatOutputSafety("They definitely love you.").replaced);

  const safe = enforceChatOutputSafety(
    "One possibility is that the timing felt abrupt. You could ask what they meant.",
  );
  assert(!safe.replaced);
});

Deno.test("third-party text redaction removes direct contact identifiers", () => {
  const result = redactThirdPartyText(
    "Email Casey@example.com, call +1 (415) 555-0123, visit https://example.com/a or private.example/path, and DM @casey.dev or @มาลี. Keep 2026-07-18.",
  );
  assert(!result.includes("Casey@example.com"));
  assert(!result.includes("555-0123"));
  assert(!result.includes("example.com/a"));
  assert(!result.includes("private.example/path"));
  assert(!result.includes("@casey.dev"));
  assert(!result.includes("@มาลี"));
  assert(result.includes("[email]"));
  assert(result.includes("[phone]"));
  assert(result.includes("[link]"));
  assert(result.includes("[handle]"));
  assert(result.includes("2026-07-18"));
});

Deno.test("third-party JSON is recursively allowlisted and redacted without input mutation", () => {
  const input = {
    summary: "Email Casey@example.com or DM @casey",
    placement: {
      sign: "Libra",
      note: "Call +1 (415) 555-0123",
      email: "casey@example.com",
    },
    sections: [
      {
        title: "See private.example/path",
        body: "Ask @casey first",
        phone: "+1 (415) 555-0199",
      },
    ],
    tips: ["Keep it short", "Review https://private.example/guide"],
    metadata: { when: "2026-07-18" },
    owner_email: "owner@example.com",
  };
  const original = structuredClone(input);
  const allowlist: ThirdPartyJsonAllowlist = {
    summary: true,
    placement: { sign: true, note: true },
    sections: { title: true, body: true },
    tips: true,
    metadata: { when: true },
  };

  const result = redactAllowedThirdPartyJson(input, allowlist);

  assertEquals(input, original);
  assert(result !== input);
  assert(result?.placement !== input.placement);
  assert(result?.sections !== input.sections);
  assertEquals(result, {
    summary: "Email [email] or DM [handle]",
    placement: {
      sign: "Libra",
      note: "Call [phone]",
    },
    sections: [{
      title: "See [link]",
      body: "Ask [handle] first",
    }],
    tips: ["Keep it short", "Review [link]"],
    metadata: { when: "2026-07-18" },
  });
  assertEquals(redactAllowedThirdPartyJson(input, { missing: true }), null);
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
