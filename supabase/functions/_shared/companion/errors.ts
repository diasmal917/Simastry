export class CompanionRuntimeError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.name = "CompanionRuntimeError";
    this.code = code;
    this.status = status;
  }
}

export function runtimeError(error: unknown): CompanionRuntimeError {
  if (error instanceof CompanionRuntimeError) return error;
  console.error(JSON.stringify({
    event: "companion_runtime_unexpected_error",
    error: error instanceof Error ? error.message : String(error),
  }));
  return new CompanionRuntimeError(
    "backend_unavailable",
    "The companion service is unavailable right now. Please try again.",
    503,
  );
}

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new CompanionRuntimeError(
      "backend_misconfigured",
      `${name} is not configured.`,
      503,
    );
  }
  return value;
}
