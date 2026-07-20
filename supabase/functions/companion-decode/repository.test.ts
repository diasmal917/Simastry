import type {
  CompanionRest,
  CompanionTable,
  RestRequest,
} from "../_shared/companion/rest.ts";
import { getPilotPersona } from "../_shared/companion/registry.ts";
import type { CompanionDecodeRequest } from "./contract.ts";
import { SupabaseCompanionDecodeRepository } from "./repository.ts";

const userId = "cccccccc-cccc-4ccc-8ccc-cccccccccccc";
const request: CompanionDecodeRequest = Object.freeze({
  companionId: "pisces-zev",
  personId: "11111111-1111-4111-8111-111111111111",
  message: "What might this mean?",
  persistMessage: false,
});

Deno.test("Decode recursively allowlists and redacts third-party People context", async () => {
  const rest: CompanionRest = {
    request: <T>(table: CompanionTable, _call: RestRequest = {}) => {
      let value: unknown;
      if (table === "companion_personas") {
        value = [{
          id: "pisces-zev",
          status: "pilot_ready",
          active_persona_version: "pilot-2026-07-19.1",
        }];
      } else if (table === "user_companion_relationships") {
        value = [{
          id: "dddddddd-dddd-4ddd-8ddd-dddddddddddd",
          support_preferences: { tone: "warm" },
        }];
      } else if (table === "relationship_people") {
        value = [{
          id: request.personId,
          relationship_kind: "friend person@example.com",
          pronouns: "they/@private_handle",
          birth_chart: {
            sunSign: "Taurus",
            placements: {
              moon: { sign: "Libra", privateNote: "call +1 415 555 0199" },
            },
            rawMessage: "person@example.com",
          },
          notes: "DM @private_handle via https://private.example/path",
          communication_guide: {
            tips: ["Email person@example.com", "Ask @private_handle"],
            sections: [{
              title: "See private.example/path",
              body: "Call +1 415 555 0199",
              rawTranscript: "do not retain",
            }],
            rawMessage: "do not retain",
          },
        }];
      } else {
        value = [{
          sun_estimate: { signs: ["pisces"] },
          calculation_version: "test",
        }];
      }
      return Promise.resolve(value as T);
    },
  };
  const repository = new SupabaseCompanionDecodeRepository(rest);
  const context = await repository.authorizeAndLoad(
    userId,
    request,
    getPilotPersona(request.companionId),
  );
  const serialized = JSON.stringify(context.person);

  for (
    const secret of [
      "person@example.com",
      "@private_handle",
      "private.example",
      "415 555 0199",
      "do not retain",
    ]
  ) {
    assert(!serialized.includes(secret));
  }
  assert(serialized.includes("[email]"));
  assert(serialized.includes("[handle]"));
  assert(serialized.includes("[link]"));
  assert(serialized.includes("[phone]"));
  assert(!serialized.includes("rawMessage"));
  assert(!serialized.includes("rawTranscript"));
  assert(!serialized.includes("privateNote"));
  assertEquals(context.person.birthChart, {
    sunSign: "Taurus",
    placements: { moon: { sign: "Libra" } },
  });
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
