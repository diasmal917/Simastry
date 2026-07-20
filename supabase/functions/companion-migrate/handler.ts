import {
  authenticateRequest,
  type Authenticator,
  companionCorsHeaders,
  jsonResponse,
  readJsonObject,
} from "../_shared/companion/http.ts";
import {
  CompanionRuntimeError,
  runtimeError,
} from "../_shared/companion/errors.ts";
import {
  getPilotPersona,
  isPilotCompanionId,
} from "../_shared/companion/registry.ts";
import { ServiceRoleCompanionRest } from "../_shared/companion/rest.ts";
import {
  COMPANION_MIGRATION_VERSION,
  parseCompanionMigrationRequest,
} from "./contract.ts";
import {
  type CompanionMigrationRepository,
  SupabaseCompanionMigrationRepository,
} from "./repository.ts";

export type CompanionMigrationHandlerDependencies = Readonly<{
  authenticate: Authenticator;
  repository: CompanionMigrationRepository;
  now: () => Date;
}>;

const defaultDependencies: CompanionMigrationHandlerDependencies = Object
  .freeze({
    authenticate: authenticateRequest,
    repository: new SupabaseCompanionMigrationRepository(
      new ServiceRoleCompanionRest(),
    ),
    now: () => new Date(),
  });

export function createCompanionMigrationHandler(
  dependencies: CompanionMigrationHandlerDependencies = defaultDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    const startedAt = Date.now();
    let metadata: Record<string, unknown> = {};
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: companionCorsHeaders });
    }
    if (request.method !== "POST") {
      return jsonResponse({
        error: { code: "method_not_allowed", message: "Method not allowed." },
        preserveLocal: true,
      }, 405);
    }

    try {
      const user = await dependencies.authenticate(request);
      const body = await readJsonObject(request, 2_000_000);
      const payload = parseCompanionMigrationRequest(body);
      if (!isPilotCompanionId(payload.companionId)) {
        throw new CompanionRuntimeError(
          "unmatched_legacy_companion",
          "This identity is not an exact certified pilot companion slug. Keep it as a read-only legacy record on this device.",
          422,
        );
      }
      const persona = getPilotPersona(payload.companionId);
      metadata = {
        userId: user.id,
        companionId: persona.id,
        conversationCount: payload.conversations.length,
        messageCount: payload.conversations.reduce(
          (count, conversation) => count + conversation.messages.length,
          0,
        ),
      };
      const result = await dependencies.repository.importConsentedThreads(
        user.id,
        payload,
        persona,
        dependencies.now().toISOString(),
      );
      console.log(JSON.stringify({
        event: "companion_legacy_migration_completed",
        ...metadata,
        ...result.counts,
        latencyMs: Date.now() - startedAt,
      }));
      return jsonResponse({
        migrationVersion: COMPANION_MIGRATION_VERSION,
        ...result,
        conversations: [...result.conversations],
        localDataDisposition: "retain_until_server_counts_are_verified",
      }, 200);
    } catch (error) {
      const companionError = runtimeError(error);
      console.log(JSON.stringify({
        event: "companion_legacy_migration_failed",
        ...metadata,
        errorCode: companionError.code,
        status: companionError.status,
        latencyMs: Date.now() - startedAt,
      }));
      return jsonResponse({
        error: {
          code: companionError.code,
          message: companionError.message,
        },
        preserveLocal: true,
        localDataDisposition: companionError.code ===
            "unmatched_legacy_companion"
          ? "unmatched_read_only_local"
          : "retain_for_retry",
      }, companionError.status);
    }
  };
}
