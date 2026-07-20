import {
  buildAuthorizedPersonContext,
  deterministicCommunicationGuide,
  explicitlyReferencedPerson,
  type RelationshipPersonRow,
} from "./relationshipContext.ts";

const maria = person(
  "11111111-1111-4111-8111-111111111111",
  "Maria",
  "libra",
);
const mariah = person(
  "22222222-2222-4222-8222-222222222222",
  "Mariah",
  "aries",
);

Deno.test("saved-person resolution requires one exact explicit display-name reference", () => {
  assertEquals(
    explicitlyReferencedPerson(
      "Can you help me answer Maria?",
      [maria, mariah],
      true,
    )?.id,
    maria.id,
  );
  assertEquals(
    explicitlyReferencedPerson("Can you help me answer Mariah?", [
      maria,
      mariah,
    ], true)?.id,
    mariah.id,
  );
  assertEquals(
    explicitlyReferencedPerson("Can you help me answer her?", [maria], true),
    null,
  );
});

Deno.test("ambiguous, partial, and incompletely bounded person sets are never assumed", () => {
  const duplicate = person(
    "33333333-3333-4333-8333-333333333333",
    "Maria",
    "pisces",
  );
  assertEquals(
    explicitlyReferencedPerson("Maria texted", [maria, duplicate], true),
    null,
  );
  assertEquals(
    explicitlyReferencedPerson("Mariah texted", [maria], true),
    null,
  );
  assertEquals(
    explicitlyReferencedPerson("Maria texted", [maria], false),
    null,
  );
});

Deno.test("server deterministic guide is transparent and sign-grounded", () => {
  const guide = deterministicCommunicationGuide({ sunSign: "Libra" });
  assertEquals(guide?.source, "server_deterministic_sun_sign");
  assertEquals(guide?.sign, "libra");
  assertStringIncludes(guide?.bestApproach ?? "", "fairly");
  assertStringIncludes(guide?.limitation ?? "", "not proof");
  assertEquals(deterministicCommunicationGuide({ moonSign: "Libra" }), null);
});

Deno.test("authorized person context allowlists and redacts every third-party field without mutation", () => {
  const sourcePerson = {
    ...maria,
    display_name: "Maria @maria_private",
    relationship_kind: "friend from private.example/profile",
    pronouns: "she/her @maria_private",
    birth_chart: {
      sunSign: "libra",
      moon: {
        resolvedSign: "gemini",
        privateNote: "DM @maria_private",
      },
      contactEmail: "maria@example.com",
    },
    notes:
      "Reach her at maria@example.com, +1 (415) 555-0199, or @maria_private.",
    communication_guide: {
      method: "deterministic-v1",
      tips: ["DM @maria_private", "Read https://private.example/guide"],
      sections: [{
        title: "Use private.example/script",
        body: "Email maria@example.com",
        phone: "+1 (415) 555-0199",
      }],
      contact: { email: "maria@example.com" },
    },
  };
  const originalPerson = structuredClone(sourcePerson);
  const context = buildAuthorizedPersonContext(sourcePerson, {
    action_text:
      "Send the draft to https://private.example/a and tag @maria_private",
    action_state: "completed",
    planned_for: null,
    acted_at: "2026-07-18T00:00:00Z",
    result_kind: "better",
    result_summary: "She replied from maria@example.com and it went well.",
    result_source: "user_recorded",
    result_recorded_at: "2026-07-18T01:00:00Z",
    follow_up_state: "due",
    updated_at: "2026-07-18T01:00:00Z",
  });
  assertEquals(sourcePerson, originalPerson);
  assertEquals(context.displayName, "Maria [handle]");
  assertEquals(context.relationshipKind, "friend from [link]");
  assertEquals(context.pronouns, "she/her [handle]");
  assertEquals(context.birthChart, {
    sunSign: "libra",
    moon: { resolvedSign: "gemini" },
  });
  assertEquals(
    (context.communicationGuide?.deterministic as Record<string, unknown>).sign,
    "libra",
  );
  assertEquals(context.communicationGuide?.saved, {
    method: "deterministic-v1",
    tips: ["DM [handle]", "Read [link]"],
    sections: [{
      title: "Use [link]",
      body: "Email [email]",
    }],
  });
  assertStringIncludes(context.notes ?? "", "[email]");
  assertStringIncludes(context.notes ?? "", "[phone]");
  assertStringIncludes(context.notes ?? "", "[handle]");
  assertStringIncludes(JSON.stringify(context.situation), "[link]");
  assertStringIncludes(JSON.stringify(context.situation), "[email]");
  assertStringIncludes(JSON.stringify(context.situation), "[handle]");
  const serializedContext = JSON.stringify(context);
  for (
    const directIdentifier of [
      "maria@example.com",
      "555-0199",
      "private.example",
      "@maria_private",
    ]
  ) {
    assert(!serializedContext.includes(directIdentifier));
  }
});

Deno.test("unrecorded outcome result is not exposed as a known situation result", () => {
  const context = buildAuthorizedPersonContext(maria, {
    action_text: "Ask one clear question",
    action_state: "planned",
    planned_for: null,
    acted_at: null,
    result_kind: "better",
    result_summary: "Should not be trusted",
    result_source: null,
    result_recorded_at: null,
    follow_up_state: "not_scheduled",
    updated_at: "2026-07-18T01:00:00Z",
  });
  assertEquals(context.situation?.resultKind, null);
  assertEquals(context.situation?.resultSummary, null);
  assertEquals(context.situation?.resultSource, null);
});

function person(
  id: string,
  displayName: string,
  sunSign: string,
): RelationshipPersonRow {
  return {
    id,
    display_name: displayName,
    relationship_kind: "friend",
    pronouns: "she/her",
    birth_chart: { sunSign },
    notes: null,
    communication_guide: null,
  };
}

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

function assert(condition: boolean): void {
  if (!condition) throw new Error("Assertion failed");
}
