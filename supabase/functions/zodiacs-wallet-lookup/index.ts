export {};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-simastry-device-id",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ZodiacSign =
  | "aries"
  | "taurus"
  | "gemini"
  | "cancer"
  | "leo"
  | "virgo"
  | "libra"
  | "scorpio"
  | "sagittarius"
  | "capricorn"
  | "aquarius"
  | "pisces";

type Registry = {
  assets: Array<{
    representations: Array<{
      sign: string;
      chain: string;
      address: string;
      decimals: number;
      isOfficialRepresentation: boolean;
    }>;
  }>;
};

type TokenRepresentation = {
  sign: ZodiacSign;
  address: string;
  decimals: number;
};

type LookupEvent = {
  id: string;
  userId: string;
  deviceId: string | null;
};

let cachedRegistry: Registry | null = null;
let cachedRegistryAt = 0;

const registryCacheMs = integerEnv("ZODIACS_REGISTRY_CACHE_SECONDS", 3600) * 1000;
const walletLimits = [
  { windowMs: 60_000, maxEvents: integerEnv("SIMASTRY_WALLET_PER_MINUTE_LIMIT", 12), label: "per_minute" },
  { windowMs: 24 * 60 * 60_000, maxEvents: integerEnv("SIMASTRY_WALLET_PER_DAY_LIMIT", 80), label: "per_day" },
];

Deno.serve(async (request: Request): Promise<Response> => {
  let lookupEvent: LookupEvent | undefined;

  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({ error: { code: "method_not_allowed", message: "Method not allowed." } }, 405);
  }

  try {
    const user = await authenticateRequest(request);
    const deviceId = normalizedDeviceId(request.headers.get("x-simastry-device-id"));
    const body = await request.json().catch(() => null) as { publicAddress?: unknown } | null;
    const publicAddress = typeof body?.publicAddress === "string"
      ? body.publicAddress.trim()
      : "";
    if (!isSupportedPublicWalletAddress(publicAddress)) {
      throw new WalletLookupError("unsupported_address", "Unsupported wallet address.", 400);
    }

    const limit = await firstWalletLimitExceeded(user.id, deviceId);
    if (limit) {
      await insertLimitedLookupEvent(user.id, deviceId, publicAddress, limit.label);
      return jsonResponse({
        error: {
          code: "wallet_lookup_limit",
          message: "Wallet lookup is being used quickly. Please wait and try again.",
        },
      }, 429);
    }

    lookupEvent = await insertLookupEvent(user.id, deviceId, publicAddress);
    const registry = await loadRegistry();
    const chain = publicAddress.startsWith("0x") ? "base" : "solana";
    const zodiacCounts = chain === "base"
      ? await fetchBaseHoldings(publicAddress, registry)
      : await fetchSolanaHoldings(publicAddress, registry);
    const totalZodiacs = Object.values(zodiacCounts).reduce((total, value) => total + value, 0);

    await safeUpdateLookupEvent(lookupEvent.id, "completed", totalZodiacs, chain);
    return jsonResponse({
      publicAddress,
      zodiacCounts,
      chain,
      checkedAt: new Date().toISOString(),
      source: "official_zodiacs_registry",
    }, 200);
  } catch (error) {
    const lookupError = toWalletLookupError(error);
    if (lookupEvent) {
      await safeUpdateLookupEvent(lookupEvent.id, "failed", 0, null, lookupError.code);
    }
    return jsonResponse({
      error: {
        code: lookupError.code,
        message: lookupError.message,
      },
    }, lookupError.status);
  }
});

async function authenticateRequest(request: Request): Promise<{ id: string }> {
  const authHeader = request.headers.get("authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw new WalletLookupError("auth_required", "Please sign in again before checking a wallet.", 401);
  }

  const response = await fetch(`${requiredEnv("SUPABASE_URL")}/auth/v1/user`, {
    headers: {
      "apikey": requiredEnv("SUPABASE_ANON_KEY"),
      "authorization": `Bearer ${match[1]}`,
    },
  });
  if (!response.ok) {
    throw new WalletLookupError("auth_required", "Please sign in again before checking a wallet.", 401);
  }

  const body = await response.json();
  if (!body?.id || typeof body.id !== "string") {
    throw new WalletLookupError("auth_required", "Please sign in again before checking a wallet.", 401);
  }
  return { id: body.id };
}

async function loadRegistry(): Promise<Registry> {
  if (cachedRegistry && Date.now() - cachedRegistryAt < registryCacheMs) {
    return cachedRegistry;
  }

  const registryUrl = Deno.env.get("ZODIACS_REGISTRY_URL")
    ?? "https://raw.githubusercontent.com/ZodiacsOfficial/sdk/main/packages/sdk/registry/zodiacs.registry.json";
  const response = await fetch(registryUrl, {
    headers: { "accept": "application/json" },
  });
  if (!response.ok) {
    throw new WalletLookupError("registry_unavailable", "The official Zodiacs registry could not be loaded.", 503);
  }

  const registry = await response.json() as Registry;
  if (!Array.isArray(registry.assets)) {
    throw new WalletLookupError("registry_unavailable", "The official Zodiacs registry could not be read.", 503);
  }
  cachedRegistry = registry;
  cachedRegistryAt = Date.now();
  return registry;
}

async function fetchSolanaHoldings(ownerAddress: string, registry: Registry): Promise<Record<ZodiacSign, number>> {
  const officialMints = new Map(
    officialRepresentations(registry, "solana").map((token) => [token.address, token]),
  );
  const payload = {
    jsonrpc: "2.0",
    id: 1,
    method: "getTokenAccountsByOwner",
    params: [
      ownerAddress,
      { programId: "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA" },
      { encoding: "jsonParsed" },
    ],
  };

  const data = await postJSON(payload, solanaRPCURL());
  const accounts = data?.result?.value;
  if (!Array.isArray(accounts)) {
    throw new WalletLookupError("rpc_unavailable", "Wallet balance lookup is unavailable right now.", 503);
  }

  const counts = emptyCounts();
  for (const account of accounts) {
    const mint = account?.account?.data?.parsed?.info?.mint;
    const displayAmount = Number(account?.account?.data?.parsed?.info?.tokenAmount?.uiAmountString
      ?? account?.account?.data?.parsed?.info?.tokenAmount?.uiAmount
      ?? 0);
    const token = typeof mint === "string" ? officialMints.get(mint) : undefined;
    if (!token) continue;
    const count = auraCount(displayAmount);
    if (count > 0) counts[token.sign] += count;
  }
  return compactCounts(counts);
}

async function fetchBaseHoldings(ownerAddress: string, registry: Registry): Promise<Record<ZodiacSign, number>> {
  const tokens = officialRepresentations(registry, "base");
  if (tokens.length === 0) {
    throw new WalletLookupError("registry_unavailable", "The official Zodiacs registry could not be loaded.", 503);
  }

  const paddedOwner = ownerAddress.slice(2).toLowerCase().padStart(64, "0");
  const payload = tokens.map((token, index) => ({
    jsonrpc: "2.0",
    id: `${index}`,
    method: "eth_call",
    params: [
      {
        to: token.address,
        data: `0x70a08231${paddedOwner}`,
      },
      "latest",
    ],
  }));

  const responses = await postJSON(payload, baseRPCURL());
  if (!Array.isArray(responses)) {
    throw new WalletLookupError("rpc_unavailable", "Wallet balance lookup is unavailable right now.", 503);
  }

  const responseById = new Map(responses.map((response) => [String(response.id), response]));
  const counts = emptyCounts();
  for (const [index, token] of tokens.entries()) {
    const result = responseById.get(String(index))?.result;
    if (typeof result !== "string") continue;
    const minorUnits = doubleFromHexQuantity(result);
    const amount = minorUnits / Math.pow(10, token.decimals);
    const count = auraCount(amount);
    if (count > 0) counts[token.sign] += count;
  }
  return compactCounts(counts);
}

function officialRepresentations(registry: Registry, chain: "solana" | "base"): TokenRepresentation[] {
  return registry.assets.flatMap((asset) =>
    asset.representations.flatMap((representation) => {
      if (
        representation.chain !== chain
        || !representation.isOfficialRepresentation
        || !isZodiacSign(representation.sign)
      ) {
        return [];
      }
      return [{
        sign: representation.sign.toLowerCase() as ZodiacSign,
        address: representation.address,
        decimals: representation.decimals,
      }];
    })
  );
}

async function postJSON(payload: unknown, url: string): Promise<any> {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!response.ok) {
    throw new WalletLookupError("rpc_unavailable", "Wallet balance lookup is unavailable right now.", 503);
  }
  return await response.json();
}

async function firstWalletLimitExceeded(userId: string, deviceId: string | null) {
  for (const limit of walletLimits) {
    const userCount = await countLookupEvents({ userId, since: new Date(Date.now() - limit.windowMs) });
    if (userCount >= limit.maxEvents) return limit;
    if (deviceId) {
      const deviceCount = await countLookupEvents({ deviceId, since: new Date(Date.now() - limit.windowMs) });
      if (deviceCount >= limit.maxEvents) return limit;
    }
  }
  return null;
}

async function countLookupEvents(filters: { userId?: string; deviceId?: string; since: Date }): Promise<number> {
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/wallet_lookup_events`);
  url.searchParams.set("select", "id");
  url.searchParams.set("created_at", `gte.${filters.since.toISOString()}`);
  url.searchParams.set("status", "in.(started,completed)");
  url.searchParams.set("limit", "1000");
  if (filters.userId) url.searchParams.set("user_id", `eq.${filters.userId}`);
  if (filters.deviceId) url.searchParams.set("device_id", `eq.${filters.deviceId}`);
  const rows = await supabaseRest<Array<{ id: string }>>(url, { method: "GET" });
  return rows.length;
}

async function insertLookupEvent(
  userId: string,
  deviceId: string | null,
  publicAddress: string,
): Promise<LookupEvent> {
  const id = crypto.randomUUID();
  const publicAddressHash = await addressFingerprint(publicAddress);
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/wallet_lookup_events`);
  await supabaseRest(url, {
    method: "POST",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify({
      id,
      user_id: userId,
      device_id: deviceId,
      public_address_hash: publicAddressHash,
      chain: publicAddress.startsWith("0x") ? "base" : "solana",
      status: "started",
    }),
  });
  return { id, userId, deviceId };
}

async function insertLimitedLookupEvent(
  userId: string,
  deviceId: string | null,
  publicAddress: string,
  errorCode: string,
) {
  const publicAddressHash = await addressFingerprint(publicAddress);
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/wallet_lookup_events`);
  await supabaseRest(url, {
    method: "POST",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify({
      user_id: userId,
      device_id: deviceId,
      public_address_hash: publicAddressHash,
      chain: publicAddress.startsWith("0x") ? "base" : "solana",
      status: "limited",
      error_code: errorCode,
    }),
  });
}

async function addressFingerprint(publicAddress: string): Promise<string> {
  const normalized = publicAddress.trim().toLowerCase();
  const bytes = new TextEncoder().encode(normalized);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function updateLookupEvent(
  id: string,
  status: "completed" | "failed",
  totalZodiacs: number,
  chain: string | null,
  errorCode?: string,
) {
  const url = new URL(`${requiredEnv("SUPABASE_URL")}/rest/v1/wallet_lookup_events`);
  url.searchParams.set("id", `eq.${id}`);
  await supabaseRest(url, {
    method: "PATCH",
    headers: { "Prefer": "return=minimal" },
    body: JSON.stringify({
      status,
      chain,
      total_zodiacs: totalZodiacs,
      error_code: errorCode ?? null,
      updated_at: new Date().toISOString(),
    }),
  });
}

async function safeUpdateLookupEvent(
  id: string,
  status: "completed" | "failed",
  totalZodiacs: number,
  chain: string | null,
  errorCode?: string,
) {
  try {
    await updateLookupEvent(id, status, totalZodiacs, chain, errorCode);
  } catch (error) {
    console.error(JSON.stringify({
      event: "wallet_lookup_event_update_failed",
      lookupEventId: id,
      error: error instanceof Error ? error.message : String(error),
    }));
  }
}

type SupabaseRestInit = {
  method: string;
  headers?: Record<string, string>;
  body?: string;
};

async function supabaseRest<T = unknown>(url: URL, init: SupabaseRestInit): Promise<T> {
  const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(url, {
    ...init,
    headers: {
      "apikey": serviceRoleKey,
      "authorization": `Bearer ${serviceRoleKey}`,
      "content-type": "application/json",
      ...(init.headers ?? {}),
    },
  });
  if (!response.ok) {
    const detail = await response.text();
    console.error(JSON.stringify({
      event: "supabase_rest_failed",
      status: response.status,
      bodyExcerpt: detail.slice(0, 500),
    }));
    throw new WalletLookupError("backend_unavailable", "Wallet lookup is unavailable right now.", 503);
  }
  if (response.status === 204) return undefined as T;
  const text = await response.text();
  if (!text) return undefined as T;
  return JSON.parse(text) as T;
}

function isSupportedPublicWalletAddress(address: string): boolean {
  if (address.startsWith("0x") && address.length === 42) {
    return /^0x[0-9a-fA-F]{40}$/.test(address);
  }
  return /^[1-9A-HJ-NP-Za-km-z]{32,60}$/.test(address);
}

function isZodiacSign(value: string): boolean {
  return [
    "aries",
    "taurus",
    "gemini",
    "cancer",
    "leo",
    "virgo",
    "libra",
    "scorpio",
    "sagittarius",
    "capricorn",
    "aquarius",
    "pisces",
  ].includes(value.toLowerCase());
}

function emptyCounts(): Record<ZodiacSign, number> {
  return {
    aries: 0,
    taurus: 0,
    gemini: 0,
    cancer: 0,
    leo: 0,
    virgo: 0,
    libra: 0,
    scorpio: 0,
    sagittarius: 0,
    capricorn: 0,
    aquarius: 0,
    pisces: 0,
  };
}

function compactCounts(counts: Record<ZodiacSign, number>): Record<ZodiacSign, number> {
  return Object.fromEntries(
    Object.entries(counts).filter(([, value]) => value > 0),
  ) as Record<ZodiacSign, number>;
}

function auraCount(amount: number): number {
  if (!Number.isFinite(amount) || amount <= 0) return 0;
  return Math.max(1, Math.floor(amount));
}

function doubleFromHexQuantity(hexQuantity: string): number {
  const hex = hexQuantity.trim().replace(/^0x/i, "");
  let value = 0;
  for (const character of hex) {
    const digit = Number.parseInt(character, 16);
    if (!Number.isFinite(digit)) continue;
    value = value * 16 + digit;
  }
  return value;
}

function solanaRPCURL(): string {
  return Deno.env.get("SOLANA_RPC_URL") ?? "https://api.mainnet-beta.solana.com";
}

function baseRPCURL(): string {
  return Deno.env.get("BASE_RPC_URL") ?? "https://mainnet.base.org";
}

function normalizedDeviceId(value: string | null): string | null {
  const trimmed = value?.trim();
  if (!trimmed) return null;
  return /^[A-Za-z0-9._:-]{8,96}$/.test(trimmed) ? trimmed : null;
}

function integerEnv(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isFinite(value) && value > 0 ? Math.round(value) : fallback;
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) {
    throw new WalletLookupError("backend_misconfigured", `${name} is not configured.`, 503);
  }
  return value;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

class WalletLookupError extends Error {
  code: string;
  status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.code = code;
    this.status = status;
  }
}

function toWalletLookupError(error: unknown): WalletLookupError {
  if (error instanceof WalletLookupError) {
    return error;
  }
  if (error instanceof Error) {
    return new WalletLookupError("wallet_lookup_failed", error.message, 503);
  }
  return new WalletLookupError("wallet_lookup_failed", "Wallet lookup is unavailable right now.", 503);
}
