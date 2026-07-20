import { CompanionRuntimeError } from "./errors.ts";

export type RateLimiter = Readonly<{
  check(userId: string): void;
}>;

export class IsolateRateLimiter implements RateLimiter {
  readonly #events = new Map<string, number[]>();
  readonly #maximum: number;
  readonly #windowMs: number;
  readonly #now: () => number;

  constructor(
    maximum = positiveIntegerEnv("SIMASTRY_COMPANION_PER_MINUTE_LIMIT", 20),
    windowMs = 60_000,
    now: () => number = Date.now,
  ) {
    this.#maximum = maximum;
    this.#windowMs = windowMs;
    this.#now = now;
  }

  check(userId: string): void {
    const now = this.#now();
    const recent = (this.#events.get(userId) ?? []).filter((timestamp) =>
      now - timestamp < this.#windowMs
    );
    if (recent.length >= this.#maximum) {
      this.#events.set(userId, recent);
      throw new CompanionRuntimeError(
        "ai_usage_limit",
        "You are asking very quickly. Please wait a minute and try again.",
        429,
      );
    }
    recent.push(now);
    this.#events.set(userId, recent);
  }
}

function positiveIntegerEnv(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isInteger(value) && value > 0 ? value : fallback;
}
