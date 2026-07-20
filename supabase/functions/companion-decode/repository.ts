import { CompanionRuntimeError } from "../_shared/companion/errors.ts";
import {
  boundedContextObject,
  boundedContextText,
} from "../_shared/companion/context.ts";
import type { CompanionRest } from "../_shared/companion/rest.ts";
import type { PilotPersonaProgram } from "../_shared/companion/registry.ts";
import {
  sanitizedThirdPartyBirthChart,
  sanitizedThirdPartyCommunicationGuide,
} from "../_shared/companion/relationshipContext.ts";
import { redactThirdPartyText } from "../_shared/companion/safety.ts";
import type { CompanionDecodeRequest } from "./contract.ts";

type PersonaRow = Readonly<{
  id: string;
  status: string;
  active_persona_version: string | null;
}>;

type RelationshipRow = Readonly<{
  id: string;
  support_preferences: Record<string, unknown> | null;
}>;

type PersonRow = Readonly<{
  id: string;
  relationship_kind: string | null;
  pronouns: string | null;
  birth_chart: Record<string, unknown> | null;
  notes: string | null;
  communication_guide: Record<string, unknown> | null;
}>;

export type CompanionDecodeContext = Readonly<{
  supportPreferences: Record<string, unknown>;
  userChart: Record<string, unknown> | null;
  person: Readonly<{
    relationshipKind: string | null;
    pronouns: string | null;
    birthChart: Record<string, unknown> | null;
    notes: string | null;
    communicationGuide: Record<string, unknown> | null;
  }>;
}>;

export type CompanionDecodeRepository = Readonly<{
  authorizeAndLoad(
    userId: string,
    request: CompanionDecodeRequest,
    persona: PilotPersonaProgram,
  ): Promise<CompanionDecodeContext>;
}>;

export class SupabaseCompanionDecodeRepository
  implements CompanionDecodeRepository {
  readonly #rest: CompanionRest;

  constructor(rest: CompanionRest) {
    this.#rest = rest;
  }

  async authorizeAndLoad(
    userId: string,
    request: CompanionDecodeRequest,
    persona: PilotPersonaProgram,
  ): Promise<CompanionDecodeContext> {
    const [personaRows, relationshipRows, personRows, chartRows] = await Promise
      .all([
        this.#rest.request<PersonaRow[]>("companion_personas", {
          query: {
            id: `eq.${persona.id}`,
            select: "id,status,active_persona_version",
            limit: "1",
          },
        }),
        this.#rest.request<RelationshipRow[]>(
          "user_companion_relationships",
          {
            query: {
              user_id: `eq.${userId}`,
              companion_id: `eq.${persona.id}`,
              status: "eq.active",
              is_primary: "eq.true",
              select: "id,support_preferences",
              limit: "1",
            },
          },
        ),
        this.#rest.request<PersonRow[]>("relationship_people", {
          query: {
            id: `eq.${request.personId}`,
            user_id: `eq.${userId}`,
            archived_at: "is.null",
            ai_context_enabled: "eq.true",
            select:
              "id,relationship_kind,pronouns,birth_chart,notes,communication_guide",
            limit: "1",
          },
        }),
        this.#rest.request<Record<string, unknown>[]>("user_birth_charts", {
          query: {
            user_id: `eq.${userId}`,
            select:
              "birth_time_precision,sun_estimate,moon_estimate,rising_estimate,calculation_version,provenance,confirmed_at",
            limit: "1",
          },
        }),
      ]);

    const personaRow = personaRows[0];
    if (
      !personaRow || !["pilot_ready", "active"].includes(personaRow.status) ||
      personaRow.active_persona_version !== persona.version
    ) {
      throw new CompanionRuntimeError(
        "companion_unavailable",
        "This companion is not available right now.",
        409,
      );
    }
    const relationship = relationshipRows[0];
    if (!relationship) {
      throw new CompanionRuntimeError(
        "primary_companion_required",
        "Choose this companion as your primary before using Decode.",
        403,
      );
    }
    const person = personRows[0];
    if (!person) {
      throw new CompanionRuntimeError(
        "person_not_authorized",
        "Choose a private People record you have authorized for AI context.",
        404,
      );
    }

    return Object.freeze({
      supportPreferences: boundedContextObject(
        relationship.support_preferences,
        2_000,
      ) ?? {},
      userChart: boundedContextObject(chartRows[0], 12_000),
      person: Object.freeze({
        relationshipKind: person.relationship_kind
          ? boundedContextText(
            redactThirdPartyText(person.relationship_kind),
            80,
          )
          : null,
        pronouns: person.pronouns
          ? boundedContextText(redactThirdPartyText(person.pronouns), 80)
          : null,
        birthChart: sanitizedThirdPartyBirthChart(person.birth_chart),
        notes: person.notes
          ? boundedContextText(redactThirdPartyText(person.notes), 2_000)
          : null,
        communicationGuide: sanitizedThirdPartyCommunicationGuide(
          person.communication_guide,
        ),
      }),
    });
  }
}
