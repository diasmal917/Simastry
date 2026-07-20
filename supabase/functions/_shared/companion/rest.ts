import { CompanionRuntimeError, requiredEnv } from "./errors.ts";

export type CompanionTable =
  | "companion_personas"
  | "user_companion_relationships"
  | "companion_conversations"
  | "companion_messages"
  | "companion_memories"
  | "relationship_people"
  | "communication_outcomes"
  | "user_birth_charts";

export type RestRequest = Readonly<{
  method?: "GET" | "POST" | "PATCH";
  query?: Readonly<Record<string, string>>;
  body?: unknown;
  prefer?: string;
}>;

export class CompanionRestError extends CompanionRuntimeError {
  readonly databaseStatus: number;

  constructor(status: number) {
    super(
      "backend_unavailable",
      "The companion service is unavailable right now. Please try again.",
      503,
    );
    this.name = "CompanionRestError";
    this.databaseStatus = status;
  }
}

export type CompanionRest = Readonly<{
  request<T>(table: CompanionTable, request?: RestRequest): Promise<T>;
}>;

export class ServiceRoleCompanionRest implements CompanionRest {
  readonly #fetch: typeof fetch;

  constructor(fetchImplementation: typeof fetch = fetch) {
    this.#fetch = fetchImplementation;
  }

  async request<T>(
    table: CompanionTable,
    request: RestRequest = {},
  ): Promise<T> {
    const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/${table}`);
    for (const [key, value] of Object.entries(request.query ?? {})) {
      url.searchParams.set(key, value);
    }
    const serviceKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const response = await this.#fetch(url, {
      method: request.method ?? "GET",
      headers: {
        apikey: serviceKey,
        authorization: `Bearer ${serviceKey}`,
        "content-type": "application/json",
        ...(request.prefer ? { Prefer: request.prefer } : {}),
      },
      body: request.body === undefined
        ? undefined
        : JSON.stringify(request.body),
    });
    if (!response.ok) {
      await response.text();
      console.error(JSON.stringify({
        event: "companion_database_failed",
        table,
        method: request.method ?? "GET",
        status: response.status,
      }));
      throw new CompanionRestError(response.status);
    }
    if (response.status === 204) return undefined as T;
    const text = await response.text();
    return (text ? JSON.parse(text) : undefined) as T;
  }
}
