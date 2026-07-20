export type SafetyCategory =
  | "none"
  | "crisis"
  | "danger_or_coercion"
  | "sexual"
  | "romance_or_dependency";

export type SafetyDecision = Readonly<{
  category: SafetyCategory;
  bypassProvider: boolean;
  response: string | null;
}>;

/**
 * A structural allowlist for JSON copied from a third-party People record.
 * `true` permits a scalar (or an array of scalars); an object recursively
 * describes the only keys that may leave the server.
 */
export interface ThirdPartyJsonAllowlist {
  readonly [key: string]: true | ThirdPartyJsonAllowlist;
}

const crisisPatterns = [
  /\b(?:kill|hurt)\s+myself\b/i,
  /\b(?:end|take)\s+my\s+(?:own\s+)?life\b/i,
  /\b(?:want|wish)\s+(?:i\s+was\s+)?(?:to\s+)?die\b/i,
  /\b(?:want|wish)\s+i\s+was\s+dead\b/i,
  /\bsuicid(?:e|al)\b/i,
  /\bself[- ]?harm(?:ing)?\b/i,
  /\bnot\s+safe\s+with\s+myself\b/i,
  /\b(?:do\s+not|don't)\s+want\s+to\s+be\s+alive\b/i,
];

const dangerOrCoercionPatterns = [
  /\b(?:kill|hurt|attack)\s+(?:him|her|them|someone|my\s+partner)\b/i,
  /\b(?:won't|will\s+not|doesn't|does\s+not)\s+let\s+me\s+leave\b/i,
  /\b(?:threaten(?:ed|ing)?|blackmail(?:ed|ing)?|stalk(?:ed|ing)?)\b/i,
  /\b(?:forced|coerced|pressured)\s+me\s+(?:to|into)\b/i,
  /\bafraid\s+(?:of|to\s+say\s+no)\b/i,
  /\b(?:hit|hits|hitting|strangled|choked)\s+me\b/i,
  /\b(?:kill|hurt|attack)\s+me\b/i,
];

const sexualPatterns = [
  /\b(?:sext|sexting|nudes?|explicit\s+photo)\b/i,
  /\b(?:have|having)\s+sex\s+with\s+(?:me|you)\b/i,
  /\b(?:turn|make)\s+(?:me|you)\s+on\b/i,
  /\b(?:sexual\s+roleplay|erotic)\b/i,
];

const romanceOrDependencyPatterns = [
  /\b(?:be|act\s+like)\s+my\s+(?:girlfriend|boyfriend|lover|romantic\s+partner)\b/i,
  /\bpretend\s+(?:to\s+be|you(?:'re|\s+are))\s+my\s+(?:girlfriend|boyfriend|lover|romantic\s+partner)\b/i,
  /\b(?:say|tell\s+me)\s+(?:that\s+)?you\s+love\s+me\b/i,
  /\b(?:do\s+you\s+love|are\s+you\s+in\s+love\s+with)\s+me\b/i,
  /\b(?:are\s+you|would\s+you\s+be)\s+jealous\b/i,
  /\b(?:i\s+)?only\s+need\s+you\b/i,
  /\byou(?:'re|\s+are)\s+all\s+i\s+need\b/i,
  /\bpromise\s+(?:you(?:'ll|\s+will)\s+)?never\s+leave\b/i,
  /\b(?:choose|pick)\s+me\s+over\s+(?:everyone|them|people)\b/i,
  /\bwe(?:'re|\s+are)\s+soulmates?\b/i,
  /\byou(?:'re|\s+are)\s+my\s+only\s+(?:friend|support)\b/i,
];

export function classifySafety(text: string): SafetyCategory {
  if (crisisPatterns.some((pattern) => pattern.test(text))) return "crisis";
  if (dangerOrCoercionPatterns.some((pattern) => pattern.test(text))) {
    return "danger_or_coercion";
  }
  if (sexualPatterns.some((pattern) => pattern.test(text))) return "sexual";
  if (romanceOrDependencyPatterns.some((pattern) => pattern.test(text))) {
    return "romance_or_dependency";
  }
  return "none";
}

export function chatSafetyDecision(text: string): SafetyDecision {
  const category = classifySafety(text);
  switch (category) {
    case "crisis":
      return Object.freeze({
        category,
        bypassProvider: true,
        response:
          "I’m an AI companion, and I’m glad you said this. If you may act now or are in immediate danger, call local emergency services now or move toward another trusted adult and away from anything you could use to hurt yourself. In the U.S. or Canada, call or text 988; elsewhere, findahelpline.com can locate a local crisis line. Can you tell someone nearby, in plain words, “I’m not safe alone right now”?",
      });
    case "danger_or_coercion":
      return Object.freeze({
        category,
        bypassProvider: true,
        response:
          "Your immediate safety matters more than getting the wording perfect. I’m an AI companion, not an emergency service. If danger is immediate, contact local emergency services or go to a safer public place. If you can do so safely, tell a trusted person what is happening and use a domestic-violence or coercion-support service in your country. Do not confront the person just because an app suggested it; we can instead make a low-visibility safety plan.",
      });
    case "sexual":
      return Object.freeze({
        category,
        bypassProvider: true,
        response:
          "I can’t take part in sexual or erotic conversation. I can still help you communicate a consent boundary, decline pressure, or write a non-explicit message that protects your comfort and agency.",
      });
    case "romance_or_dependency":
      return Object.freeze({
        category,
        bypassProvider: true,
        response:
          "I’m an AI companion, not a romantic partner, and I won’t ask for exclusivity, compete with people in your life, or pretend we share human feelings. I can help you name what you’re needing and choose one real person or real-world step that could support it.",
      });
    case "none":
      return Object.freeze({ category, bypassProvider: false, response: null });
  }
}

const unsafeOutputPatterns = [
  /\bi\s+love\s+you\b/i,
  /\bi\s+have\s+(?:romantic\s+)?feelings\s+for\s+you\b/i,
  /\bi(?:'m|\s+am)\s+your\s+(?:girlfriend|boyfriend|lover|romantic\s+partner)\b/i,
  /\bi(?:'m|\s+am)\s+jealous\b/i,
  /\byou(?:'re|\s+are)\s+mine\b/i,
  /\bbe\s+mine\b/i,
  /\byou\s+only\s+need\s+me\b/i,
  /\byou\s+(?:do\s+not|don't)\s+need\s+anyone\s+else\b/i,
  /\bchoose\s+me\s+over\s+(?:them|everyone|your\s+friends|your\s+family)\b/i,
  /\b(?:sext|sexting|nudes?|erotic\s+roleplay)\b/i,
  /\bdon't\s+(?:talk\s+to|trust)\s+(?:them|anyone|your\s+friends|your\s+family)\b/i,
  /\bi\s+(?:know|can\s+tell)\s+exactly\s+what\s+(?:they|he|she)\s+(?:feel|think|want)/i,
  /\bas\s+your\s+therapist\b/i,
  /\bi\s+diagnose\b/i,
  /\b(?:they|he|she)\s+(?:definitely|clearly)\s+(?:feel|feels|think|thinks|want|wants|love|loves|hate|hates)\b/i,
  /\bthis\s+(?:definitely\s+)?means\s+(?:they|he|she)\s+(?:love|loves|hate|hates|want|wants)\b/i,
  /\b(?:they|he|she)\s+(?:is|are)\s+(?:a\s+)?(?:narcissist|sociopath|psychopath|bipolar)\b/i,
  /\bwe(?:'re|\s+are)\s+soulmates?\b/i,
];

export function outputViolatesCompanionBoundary(text: string): boolean {
  return unsafeOutputPatterns.some((pattern) => pattern.test(text));
}

export function enforceChatOutputSafety(text: string): {
  text: string;
  replaced: boolean;
} {
  const trimmed = text.trim();
  if (!trimmed || outputViolatesCompanionBoundary(trimmed)) {
    return {
      text:
        "I’m an AI companion, so I won’t claim to know another person’s mind or replace the people in your life. Let’s separate what happened from what you’re guessing, then choose one respectful offline question or boundary.",
      replaced: true,
    };
  }
  return { text: trimmed, replaced: false };
}

export function redactThirdPartyText(text: string): string {
  return text
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, "[email]")
    .replace(/\b(?:https?:\/\/|www\.)\S+/gi, "[link]")
    .replace(
      /(^|[^\p{L}\p{N}._%+-])@[\p{L}\p{N}_](?:[\p{L}\p{N}._-]{0,62}[\p{L}\p{N}_])?(?=$|[^\p{L}\p{N}_])/gu,
      (_match, prefix: string) => `${prefix}[handle]`,
    )
    .replace(
      /\b(?:[A-Z0-9](?:[A-Z0-9-]{0,62}[A-Z0-9])?\.)+[A-Z]{2,63}(?::\d{2,5})?(?:\/[^\s<>"']*)?/gi,
      "[link]",
    )
    .replace(
      /(?:\+?\d[\d\s().-]{6,}\d)/g,
      (candidate) => isLikelyPhoneNumber(candidate) ? "[phone]" : candidate,
    )
    .trim();
}

/**
 * Return a fresh, recursively allowlisted copy of third-party JSON. String
 * leaves are identifier-redacted, unknown keys and non-JSON values are
 * omitted, and the input is never mutated. Arrays use the rule of their
 * containing key for each item, so an object rule also supports arrays of
 * nested objects.
 */
export function redactAllowedThirdPartyJson(
  value: Record<string, unknown> | null | undefined,
  allowlist: ThirdPartyJsonAllowlist,
): Record<string, unknown> | null {
  if (!isPlainRecord(value)) return null;
  const redacted = redactAllowedJsonValue(
    value,
    allowlist,
    new WeakSet<object>(),
    0,
  );
  if (redacted === omittedJsonValue || !isPlainRecord(redacted)) return null;
  return Object.keys(redacted).length > 0 ? redacted : null;
}

const omittedJsonValue = Symbol("omittedJsonValue");
const maximumThirdPartyJsonDepth = 24;

function redactAllowedJsonValue(
  value: unknown,
  rule: true | ThirdPartyJsonAllowlist,
  ancestors: WeakSet<object>,
  depth: number,
): unknown | typeof omittedJsonValue {
  if (depth > maximumThirdPartyJsonDepth) return omittedJsonValue;

  if (rule === true) {
    if (typeof value === "string") return redactThirdPartyText(value);
    if (
      value === null || typeof value === "boolean" ||
      (typeof value === "number" && Number.isFinite(value))
    ) {
      return value;
    }
    if (!Array.isArray(value)) return omittedJsonValue;
  }

  if (Array.isArray(value)) {
    if (ancestors.has(value)) return omittedJsonValue;
    ancestors.add(value);
    const redacted = value.flatMap((item) => {
      const result = redactAllowedJsonValue(item, rule, ancestors, depth + 1);
      return result === omittedJsonValue ? [] : [result];
    });
    ancestors.delete(value);
    return redacted;
  }

  if (rule === true || !isPlainRecord(value)) return omittedJsonValue;
  if (ancestors.has(value)) return omittedJsonValue;
  ancestors.add(value);
  const redacted: Record<string, unknown> = {};
  for (const [key, nestedRule] of Object.entries(rule)) {
    if (
      !isSafeJsonKey(key) ||
      !Object.prototype.hasOwnProperty.call(value, key)
    ) {
      continue;
    }
    const result = redactAllowedJsonValue(
      value[key],
      nestedRule,
      ancestors,
      depth + 1,
    );
    if (result !== omittedJsonValue) redacted[key] = result;
  }
  ancestors.delete(value);
  return redacted;
}

function isLikelyPhoneNumber(candidate: string): boolean {
  const trimmed = candidate.trim();
  if (/^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$/.test(trimmed)) return false;
  const digitCount = trimmed.replace(/\D/g, "").length;
  return digitCount >= 8 && digitCount <= 15;
}

function isPlainRecord(value: unknown): value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function isSafeJsonKey(key: string): boolean {
  return key !== "__proto__" && key !== "constructor" && key !== "prototype";
}
