export function boundedContextObject(
  value: Record<string, unknown> | null | undefined,
  maximumBytes: number,
): Record<string, unknown> | null {
  if (!value) return null;
  try {
    const serialized = JSON.stringify(value);
    if (new TextEncoder().encode(serialized).byteLength > maximumBytes) {
      return Object.freeze({ contextStatus: "omitted_oversize" });
    }
    return JSON.parse(serialized) as Record<string, unknown>;
  } catch {
    return Object.freeze({ contextStatus: "omitted_invalid" });
  }
}

export function boundedContextText(
  value: string,
  maximumCharacters: number,
): string {
  return Array.from(value).slice(0, maximumCharacters).join("");
}
