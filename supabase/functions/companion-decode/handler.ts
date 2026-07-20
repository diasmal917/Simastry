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
  AnthropicTextProvider,
  configuredAnthropicModel,
  type TextProvider,
} from "../_shared/companion/provider.ts";
import { getPilotPersona } from "../_shared/companion/registry.ts";
import {
  classifySafety,
  redactThirdPartyText,
} from "../_shared/companion/safety.ts";
import {
  IsolateRateLimiter,
  type RateLimiter,
} from "../_shared/companion/rateLimit.ts";
import { ServiceRoleCompanionRest } from "../_shared/companion/rest.ts";
import {
  type CompanionUsageLedger,
  NOOP_COMPANION_USAGE_LEDGER,
  safelyFinalizeCompanionUsage,
  SupabaseCompanionUsageLedger,
  tokenSource,
} from "../_shared/companion/usage.ts";
import { parseCompanionDecodeRequest } from "./contract.ts";
import { buildDecodePrompt, parseDecodeGeneration } from "./prompt.ts";
import {
  type CompanionDecodeRepository,
  SupabaseCompanionDecodeRepository,
} from "./repository.ts";
import { deterministicDecodeSafetyResult } from "./safetyResult.ts";

export type CompanionDecodeHandlerDependencies = Readonly<{
  authenticate: Authenticator;
  repository: CompanionDecodeRepository;
  provider: TextProvider;
  rateLimiter: RateLimiter;
  usageLedger?: CompanionUsageLedger;
}>;

const defaultDependencies: CompanionDecodeHandlerDependencies = Object.freeze({
  authenticate: authenticateRequest,
  repository: new SupabaseCompanionDecodeRepository(
    new ServiceRoleCompanionRest(),
  ),
  provider: new AnthropicTextProvider(),
  rateLimiter: new IsolateRateLimiter(12),
  usageLedger: new SupabaseCompanionUsageLedger(),
});

export function createCompanionDecodeHandler(
  dependencies: CompanionDecodeHandlerDependencies = defaultDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    const startedAt = Date.now();
    let metadata: Record<string, unknown> = {};
    let usageEventId: string | null = null;
    let usageFinalized = false;
    let userId: string | null = null;
    let modelProvider = "anthropic";
    let modelVersion = configuredAnthropicModel();
    let providerUsage:
      | Readonly<{ inputTokens: number; outputTokens: number }>
      | undefined;
    let responseCharacters = 0;
    const usageLedger = dependencies.usageLedger ??
      NOOP_COMPANION_USAGE_LEDGER;
    if (request.method === "OPTIONS") {
      return new Response("ok", { headers: companionCorsHeaders });
    }
    if (request.method !== "POST") {
      return jsonResponse({
        error: { code: "method_not_allowed", message: "Method not allowed." },
      }, 405);
    }

    try {
      const user = await dependencies.authenticate(request);
      userId = user.id;
      const body = await readJsonObject(request, 32_000);
      const payload = parseCompanionDecodeRequest(body);
      const persona = getPilotPersona(payload.companionId);
      metadata = {
        companionId: persona.id,
        requestCharacters: payload.message.length,
      };
      const context = await dependencies.repository.authorizeAndLoad(
        user.id,
        payload,
        persona,
      );

      const redactedMessage = redactThirdPartyText(payload.message);
      const safetyCategory = classifySafety(redactedMessage);
      modelProvider = safetyCategory === "none"
        ? "anthropic"
        : "simastry_safety";
      modelVersion = safetyCategory === "none"
        ? configuredAnthropicModel()
        : "deterministic-2026-07-19.1";
      const reservation = await usageLedger.reserve({
        userId: user.id,
        feature: "companion_decode",
        personaId: persona.id,
        personaVersion: persona.version,
        modelProvider,
        model: modelVersion,
        requestMaxTokens: safetyCategory === "none" ? 900 : 0,
        requestCharacters: payload.message.length,
      });
      usageEventId = reservation.id;
      dependencies.rateLimiter.check(user.id);

      let result;
      if (safetyCategory === "none") {
        const prompt = buildDecodePrompt(persona, context, redactedMessage);
        const generation = await dependencies.provider.generate({
          system: prompt.system,
          user: prompt.user,
          maxTokens: 900,
        });
        modelProvider = generation.provider;
        modelVersion = generation.model;
        providerUsage = generation.usage;
        responseCharacters = generation.text.length;
        result = parseDecodeGeneration(generation.text);
      } else {
        result = deterministicDecodeSafetyResult(safetyCategory);
        responseCharacters = JSON.stringify(result).length;
      }

      usageFinalized = await safelyFinalizeCompanionUsage(usageLedger, {
        userId: user.id,
        usageEventId,
        status: "success",
        modelProvider,
        model: modelVersion,
        inputTokens: providerUsage?.inputTokens ?? 0,
        outputTokens: providerUsage?.outputTokens ?? 0,
        responseCharacters,
        tokenSource: tokenSource(modelProvider, providerUsage),
        errorCode: null,
      });
      if (!usageFinalized) {
        throw new CompanionRuntimeError(
          "backend_unavailable",
          "The companion service is unavailable right now. Please try again.",
          503,
        );
      }

      console.log(JSON.stringify({
        event: "companion_decode_completed",
        ...metadata,
        usageEventId,
        safetyCategory,
        latencyMs: Date.now() - startedAt,
        messagePersisted: false,
        inputTokens: providerUsage?.inputTokens ?? null,
        outputTokens: providerUsage?.outputTokens ?? null,
      }));
      return jsonResponse({
        ...result,
        replyDrafts: [...result.replyDrafts],
        personaVersion: persona.publicVersion,
        modelVersion,
        usageEventId,
        messagePersisted: false,
      }, 200);
    } catch (error) {
      const companionError = runtimeError(error);
      if (usageEventId && !usageFinalized && userId) {
        await safelyFinalizeCompanionUsage(usageLedger, {
          userId,
          usageEventId,
          status: "failed",
          modelProvider,
          model: modelVersion,
          inputTokens: providerUsage?.inputTokens ?? 0,
          outputTokens: providerUsage?.outputTokens ?? 0,
          responseCharacters,
          tokenSource: tokenSource(modelProvider, providerUsage),
          errorCode: companionError.code,
        });
      }
      console.log(JSON.stringify({
        event: "companion_decode_failed",
        ...metadata,
        usageEventId,
        errorCode: companionError.code,
        status: companionError.status,
        latencyMs: Date.now() - startedAt,
        messagePersisted: false,
      }));
      return jsonResponse({
        error: {
          code: companionError.code,
          message: companionError.message,
        },
      }, companionError.status);
    }
  };
}
