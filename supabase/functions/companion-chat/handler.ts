import {
  authenticateRequest,
  type Authenticator,
  companionCorsHeaders,
  jsonResponse,
  readJsonObject,
} from "../_shared/companion/http.ts";
import { runtimeError } from "../_shared/companion/errors.ts";
import {
  AnthropicTextProvider,
  configuredAnthropicModel,
  type TextProvider,
} from "../_shared/companion/provider.ts";
import {
  getPilotPersona,
  type PilotPersonaProgram,
} from "../_shared/companion/registry.ts";
import {
  chatSafetyDecision,
  enforceChatOutputSafety,
  redactThirdPartyText,
} from "../_shared/companion/safety.ts";
import {
  completedTextStream,
  errorTextStream,
} from "../_shared/companion/sse.ts";
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
import { parseCompanionChatRequest } from "./contract.ts";
import {
  type CompanionChatRequestFingerprinter,
  fingerprintCompanionChatRequest,
} from "./fingerprint.ts";
import { buildCompanionPrompt } from "./prompt.ts";
import {
  type CompanionChatRepository,
  SupabaseCompanionChatRepository,
} from "./repository.ts";

export type CompanionChatHandlerDependencies = Readonly<{
  authenticate: Authenticator;
  repository: CompanionChatRepository;
  provider: TextProvider;
  rateLimiter: RateLimiter;
  fingerprintRequest: CompanionChatRequestFingerprinter;
  usageLedger?: CompanionUsageLedger;
}>;

const defaultDependencies: CompanionChatHandlerDependencies = Object.freeze({
  authenticate: authenticateRequest,
  repository: new SupabaseCompanionChatRepository(
    new ServiceRoleCompanionRest(),
  ),
  provider: new AnthropicTextProvider(),
  rateLimiter: new IsolateRateLimiter(),
  fingerprintRequest: fingerprintCompanionChatRequest,
  usageLedger: new SupabaseCompanionUsageLedger(),
});

export function createCompanionChatHandler(
  dependencies: CompanionChatHandlerDependencies = defaultDependencies,
): (request: Request) => Promise<Response> {
  return async (request: Request): Promise<Response> => {
    const startedAt = Date.now();
    let streamRequested = false;
    let claimedMessageId: string | null = null;
    let userId: string | null = null;
    let persona: PilotPersonaProgram | null = null;
    let requestMetadata: Record<string, unknown> = {};
    let usageEventId: string | null = null;
    let usageFinalized = false;
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
      const body = await readJsonObject(request, 16_000);
      streamRequested = body.stream === true;
      const payload = parseCompanionChatRequest(body);
      const requestFingerprint = await dependencies.fingerprintRequest(payload);
      const runtimePayload = Object.freeze({
        ...payload,
        message: redactThirdPartyText(payload.message),
      });
      persona = getPilotPersona(payload.companionId);
      requestMetadata = {
        companionId: persona.id,
        requestCharacters: payload.message.length,
      };
      const preparation = await dependencies.repository.prepare(
        user.id,
        runtimePayload,
        persona,
        requestFingerprint,
      );
      if (preparation.kind === "replay") {
        usageEventId = preparation.usageEventId;
        const usageReconciled = !preparation.usageEventId ||
          (preparation.usage !== null &&
            await safelyFinalizeCompanionUsage(usageLedger, {
              userId: user.id,
              usageEventId: preparation.usageEventId,
              status: "success",
              modelProvider: preparation.usage.modelProvider,
              model: preparation.modelVersion,
              inputTokens: preparation.usage.inputTokens,
              outputTokens: preparation.usage.outputTokens,
              responseCharacters: preparation.usage.responseCharacters,
              tokenSource: preparation.usage.tokenSource,
              errorCode: null,
            }));
        logEvent("companion_chat_replayed", startedAt, {
          ...requestMetadata,
          usageEventId: preparation.usageEventId,
          usageReconciled,
        });
        return successResponse({
          stream: payload.stream,
          text: preparation.text,
          persona,
          conversationId: payload.conversationId,
          clientMessageId: payload.clientMessageId,
          modelVersion: preparation.modelVersion,
          replayed: true,
          usageEventId: preparation.usageEventId,
        });
      }
      claimedMessageId = preparation.userMessageId;

      const safety = chatSafetyDecision(runtimePayload.message);
      modelProvider = safety.bypassProvider ? "simastry_safety" : "anthropic";
      modelVersion = safety.bypassProvider
        ? "deterministic-2026-07-19.1"
        : configuredAnthropicModel();
      const reservation = await usageLedger.reserve({
        userId: user.id,
        feature: "companion_chat",
        personaId: persona.id,
        personaVersion: persona.version,
        modelProvider,
        model: modelVersion,
        requestMaxTokens: safety.bypassProvider ? 0 : 640,
        requestCharacters: payload.message.length,
        requestKey: payload.clientMessageId,
      });
      usageEventId = reservation.id;
      dependencies.rateLimiter.check(user.id);

      let generatedText: string;
      if (safety.bypassProvider) {
        generatedText = safety.response ??
          "Let’s pause and choose a safe real-world next step.";
      } else {
        const prompt = buildCompanionPrompt(
          persona,
          preparation.context,
          runtimePayload.message,
        );
        const generation = await dependencies.provider.generate({
          system: prompt.system,
          user: prompt.user,
          maxTokens: 640,
        });
        generatedText = generation.text;
        modelProvider = generation.provider;
        modelVersion = generation.model;
        providerUsage = generation.usage;
      }
      const safeOutput = enforceChatOutputSafety(generatedText);
      responseCharacters = safeOutput.text.length;
      const completed = await dependencies.repository.complete({
        userId: user.id,
        request: runtimePayload,
        persona,
        userMessageId: preparation.userMessageId,
        text: safeOutput.text,
        modelProvider,
        modelVersion,
        safetyCategory: safety.category,
        safetyOutputReplaced: safeOutput.replaced,
        usageEventId,
        requestFingerprint,
        usage: providerUsage,
      });
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
      logEvent("companion_chat_completed", startedAt, {
        ...requestMetadata,
        usageEventId: completed.usageEventId ?? usageEventId,
        safetyCategory: safety.category,
        safetyOutputReplaced: safeOutput.replaced,
        responseCharacters: completed.text.length,
        replayed: completed.replayed,
        inputTokens: providerUsage?.inputTokens ?? null,
        outputTokens: providerUsage?.outputTokens ?? null,
        usageFinalized,
      });
      return successResponse({
        stream: payload.stream,
        text: completed.text,
        persona,
        conversationId: payload.conversationId,
        clientMessageId: payload.clientMessageId,
        modelVersion: completed.modelVersion,
        replayed: completed.replayed,
        usageEventId: completed.usageEventId ?? usageEventId,
      });
    } catch (error) {
      const companionError = runtimeError(error);
      if (
        usageEventId && !usageFinalized && userId
      ) {
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
      if (claimedMessageId) {
        await dependencies.repository.fail(
          claimedMessageId,
          companionError.code,
        );
      }
      logEvent("companion_chat_failed", startedAt, {
        ...requestMetadata,
        usageEventId,
        errorCode: companionError.code,
        status: companionError.status,
      });
      if (streamRequested) {
        return errorTextStream(
          companionError.code,
          companionError.message,
          companionError.status,
        );
      }
      return jsonResponse({
        error: {
          code: companionError.code,
          message: companionError.message,
        },
      }, companionError.status);
    }
  };
}

type SuccessResponseArgs = Readonly<{
  stream: boolean;
  text: string;
  persona: PilotPersonaProgram;
  conversationId: string;
  clientMessageId: string;
  modelVersion: string;
  replayed: boolean;
  usageEventId: string | null;
}>;

function successResponse(args: SuccessResponseArgs): Response {
  const metadata = {
    usageEventId: args.usageEventId,
    specialistId: null,
    mode: "primary_companion",
    companionId: args.persona.id,
    conversationId: args.conversationId,
    clientMessageId: args.clientMessageId,
    personaVersion: args.persona.publicVersion,
    modelVersion: args.modelVersion,
    replayed: args.replayed,
  };
  if (args.stream) {
    return completedTextStream({
      text: args.text,
      meta: metadata,
      done: { ...metadata, messagePersisted: true },
    });
  }
  return jsonResponse({
    text: args.text,
    ...metadata,
    messagePersisted: true,
  }, 200);
}

function logEvent(
  event: string,
  startedAt: number,
  metadata: Record<string, unknown>,
): void {
  console.log(JSON.stringify({
    event,
    latencyMs: Date.now() - startedAt,
    ...metadata,
  }));
}
