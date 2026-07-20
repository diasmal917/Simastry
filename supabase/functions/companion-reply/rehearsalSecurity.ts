import { redactThirdPartyText } from "../_shared/companion/safety.ts";
import type { ConversationRehearsalRequest } from "./rehearsalPrompt.ts";

export type PrimaryCompanionRelationshipRow = Readonly<{
  companion_id: string;
  status: string;
  is_primary: boolean;
}>;

export function isCurrentPrimaryCompanion(
  rows: readonly PrimaryCompanionRelationshipRow[],
  companionId: string,
): boolean {
  return rows.some((row) =>
    row.companion_id === companionId && row.status === "active" &&
    row.is_primary === true
  );
}

/**
 * This is the final boundary before a rehearsal request is turned into a
 * provider prompt. The database stores no raw rehearsal transcript; direct
 * contact identifiers are redacted on both sides of the practice exchange.
 */
export function redactRehearsalForProvider(
  request: ConversationRehearsalRequest,
): ConversationRehearsalRequest {
  return {
    ...request,
    goal: redactThirdPartyText(request.goal),
    personaNotes: request.personaNotes
      ? redactThirdPartyText(request.personaNotes)
      : undefined,
    transcript: (request.transcript ?? []).map((message) => ({
      ...message,
      content: redactThirdPartyText(message.content),
    })),
  };
}
