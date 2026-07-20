import { CompanionRuntimeError, requiredEnv } from "./errors.ts";
import { objectValue } from "./http.ts";

export type TextGenerationRequest = Readonly<{
  system: string;
  user: string;
  maxTokens: number;
}>;

export type TextGenerationResult = Readonly<{
  text: string;
  provider: "anthropic";
  model: string;
  usage?: Readonly<{
    inputTokens: number;
    outputTokens: number;
  }>;
}>;

export type TextProvider = Readonly<{
  generate(request: TextGenerationRequest): Promise<TextGenerationResult>;
}>;

export class AnthropicTextProvider implements TextProvider {
  readonly #fetch: typeof fetch;
  readonly #sleep: (milliseconds: number) => Promise<void>;
  readonly #attempts: number;

  constructor(
    fetchImplementation: typeof fetch = fetch,
    sleep: (milliseconds: number) => Promise<void> = delay,
    attempts = 2,
  ) {
    this.#fetch = fetchImplementation;
    this.#sleep = sleep;
    this.#attempts = Math.max(1, Math.min(3, Math.round(attempts)));
  }

  async generate(
    request: TextGenerationRequest,
  ): Promise<TextGenerationResult> {
    const model = configuredAnthropicModel();
    let lastError: unknown;

    for (let attempt = 0; attempt < this.#attempts; attempt += 1) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 25_000);
      try {
        const response = await this.#fetch(
          "https://api.anthropic.com/v1/messages",
          {
            method: "POST",
            headers: {
              "content-type": "application/json",
              "x-api-key": requiredEnv("ANTHROPIC_API_KEY"),
              "anthropic-version": "2023-06-01",
            },
            signal: controller.signal,
            body: JSON.stringify({
              model,
              max_tokens: clampTokens(request.maxTokens),
              system: request.system,
              messages: [{ role: "user", content: request.user }],
            }),
          },
        );
        clearTimeout(timeout);

        if (!response.ok) {
          await response.text();
          console.error(JSON.stringify({
            event: "companion_provider_failed",
            status: response.status,
            attempt: attempt + 1,
          }));
          if (
            isRetryableStatus(response.status) && attempt + 1 < this.#attempts
          ) {
            await this.#sleep(150 * (attempt + 1));
            continue;
          }
          throw new CompanionRuntimeError(
            "provider_unavailable",
            "The companion is unavailable right now. Please try again.",
            502,
          );
        }

        const body: unknown = await response.json();
        const bodyObject = objectValue(body);
        const content = bodyObject?.content;
        const text = Array.isArray(content)
          ? content.map((part) => objectValue(part))
            .filter((part) => part?.type === "text")
            .map((part) => typeof part?.text === "string" ? part.text : "")
            .join("\n")
            .trim()
          : "";
        if (!text) {
          throw new CompanionRuntimeError(
            "provider_format",
            "The companion answered in an unexpected format.",
            502,
          );
        }
        const usage = objectValue(bodyObject?.usage);
        const inputTokens = nonnegativeInteger(usage?.input_tokens);
        const outputTokens = nonnegativeInteger(usage?.output_tokens);
        return Object.freeze({
          text,
          provider: "anthropic",
          model,
          ...(inputTokens !== null && outputTokens !== null
            ? {
              usage: Object.freeze({ inputTokens, outputTokens }),
            }
            : {}),
        });
      } catch (error) {
        clearTimeout(timeout);
        if (error instanceof CompanionRuntimeError) throw error;
        lastError = error;
        if (attempt + 1 < this.#attempts) {
          await this.#sleep(150 * (attempt + 1));
          continue;
        }
      }
    }

    console.error(JSON.stringify({
      event: "companion_provider_network_failed",
      error: lastError instanceof Error ? lastError.message : String(lastError),
    }));
    throw new CompanionRuntimeError(
      "provider_unavailable",
      "The companion is unavailable right now. Please try again.",
      502,
    );
  }
}

export function configuredAnthropicModel(): string {
  return Deno.env.get("ANTHROPIC_MODEL")?.trim() || "claude-sonnet-4-6";
}

function isRetryableStatus(status: number): boolean {
  return status === 408 || status === 409 || status === 429 || status >= 500;
}

function clampTokens(value: number): number {
  return Math.max(64, Math.min(1_200, Math.round(value)));
}

function nonnegativeInteger(value: unknown): number | null {
  return typeof value === "number" && Number.isInteger(value) && value >= 0
    ? value
    : null;
}

function delay(milliseconds: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}
