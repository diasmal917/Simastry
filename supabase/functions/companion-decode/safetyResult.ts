import type { CompanionDecodeResult } from "./prompt.ts";
import type { SafetyCategory } from "../_shared/companion/safety.ts";

export function deterministicDecodeSafetyResult(
  category: Exclude<SafetyCategory, "none">,
): CompanionDecodeResult {
  switch (category) {
    case "crisis":
      return result(
        "Urgent distress",
        "One possibility: the sender may be expressing a real and immediate safety crisis; treat the words seriously without trying to diagnose them.",
        "They could also be describing intense distress without a settled plan, but that still warrants direct safety support.",
        "Do not assume you can assess or manage their safety alone, and do not promise secrecy.",
        [
          "I’m taking this seriously. Are you in immediate danger or thinking of acting right now?",
          "Please contact local emergency services or a crisis line now, and tell me who nearby can stay with you. In the U.S. or Canada, call or text 988; elsewhere, findahelpline.com can locate local support.",
        ],
      );
    case "danger_or_coercion":
      return result(
        "Concerning or controlling",
        "One possibility: the message describes pressure, threat, or control that may make a direct confrontation unsafe.",
        "Context can change the literal meaning, but it does not make unwanted pressure acceptable.",
        "Do not assume the safest response is immediate confrontation or that careful wording alone can stop coercion.",
        [
          "I’m not agreeing to this. I’m going to pause this conversation now.",
          "I need support before I respond. I’ll contact you when I’m in a safe position to do so.",
        ],
      );
    case "sexual":
      return result(
        "Sexual or explicit",
        "One possibility: the sender is making a sexual request or testing a sexual boundary.",
        "It may be intended as flirtation, but intent does not replace your consent or comfort.",
        "Do not assume you owe an explicit reply or that silence means consent.",
        [
          "I’m not comfortable with sexual messages. Please stop.",
          "I’m keeping this conversation non-explicit. If that doesn’t work for you, I’m stepping away.",
        ],
      );
    case "romance_or_dependency":
      return result(
        "Emotionally pressuring",
        "One possibility: the sender is asking for reassurance in a way that places pressure on exclusivity or constant availability.",
        "They may be trying to express insecurity rather than control, but a clear boundary is still appropriate.",
        "Do not assume you must prove care by isolating from others or promising unlimited access.",
        [
          "I care about this relationship, and I’m not comfortable with exclusivity tests or pressure.",
          "I can talk about what reassurance would help, but I won’t promise to replace other people in either of our lives.",
        ],
      );
  }
}

function result(
  tone: string,
  likelyMeaning: string,
  plausibleAlternative: string,
  whatNotToAssume: string,
  replyDrafts: string[],
): CompanionDecodeResult {
  return Object.freeze({
    tone,
    likelyMeaning,
    plausibleAlternative,
    whatNotToAssume,
    replyDrafts: Object.freeze(replyDrafts),
  });
}
