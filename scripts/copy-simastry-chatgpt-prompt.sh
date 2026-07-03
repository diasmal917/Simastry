#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STYLE_DNA_FILE="$ROOT_DIR/prompts/imagegen/simastry-experts/style-dna.txt"
OPEN_CHATGPT="${OPEN_CHATGPT:-1}"

usage() {
  cat <<'EOF'
Usage:
  scripts/copy-simastry-chatgpt-prompt.sh <prompt-id>

Prompt ids:
  leyla-hero | mateo-hero | naomi-hero | soren-hero | nadia-hero
  listening | chart | smile | avatar
  council

Recommended ChatGPT Pro loop:
  1. Start one new ChatGPT chat per expert.
  2. Run this script with the expert hero prompt id.
  3. Paste/send in ChatGPT and save the image with the expected filename.
  4. In the same expert chat, run listening, chart, smile, and avatar.
  5. After all five hero images are saved, attach them in a new chat, then run council.

The selected prompt is copied to the macOS clipboard. By default the script opens ChatGPT.
Set OPEN_CHATGPT=0 to only copy the prompt.
EOF
}

require_style_dna() {
  if [[ ! -f "$STYLE_DNA_FILE" ]]; then
    echo "Missing style DNA file: $STYLE_DNA_FILE" >&2
    exit 1
  fi
}

style_dna() {
  cat "$STYLE_DNA_FILE"
}

copy_prompt() {
  local prompt="$1"
  printf '%s' "$prompt" | pbcopy
  echo "Copied prompt to clipboard."
  if [[ "$OPEN_CHATGPT" == "1" ]]; then
    open -a ChatGPT || true
  fi
}

hero_prompt() {
  local title="$1"
  local filename="$2"
  local body="$3"
  cat <<EOF
$(style_dna)

Generate this as a PNG at the largest size offered. Use a 4:5 portrait aspect ratio.

Asset: $title
Expected saved filename: $filename

$body

Important: no text in the image, no watermark. Keep this as a believable editorial photograph and preserve the Style DNA exactly.
EOF
}

same_person_prompt() {
  local request="$1"
  cat <<EOF
Same exact person, same lighting and wardrobe: $request

Keep the Simastry Style DNA exactly: Apple keynote restraint meets a dark observatory; deep space-black background; champagne-gold accent light; secondary cool celestial blue and muted violet; thin engraved gold celestial linework; real Apple Liquid Glass where glass appears; editorial cinematic photography; honest skin texture.

No text, no watermark, no pastel zodiac clip-art, no neon, no lens flares, no fantasy costume, no tarot-shop clutter, no plastic 3D render look, no oversaturation, no warped anatomy.
EOF
}

council_prompt() {
  cat <<'EOF'
Use the five attached hero portraits as identity references. Generate these exact five people together.

Group editorial photograph of five consultants - Leyla, Mateo, Naomi, Soren, and Nadia - standing and seated around a circular black-glass table in a dark observatory studio; on the table, a star chart glows in thin gold hairlines, lighting their faces from below like a strategy table. Staggered depth, each person distinct, calm and collegial - a council of specialists, not a band photo. One gold key light logic across all five, faint blue atmosphere. 16:9, cinematic.

Style DNA - Simastry: Apple keynote restraint meets a dark observatory. Deep space-black backgrounds (#0A0A0F), one warm champagne-gold accent light, secondary cool celestial blue and muted violet. Celestial ornament is drawn as thin engraved hairline linework, never filled shapes. Glass is real Apple Liquid Glass: transparent panes with soft refraction, 1px light rims, gentle inner glow - not frosted plastic, not neumorphism. Editorial cinematic photography, soft key light, honest skin texture, shallow depth of field.

Constraints: preserve the five reference identities clearly. Do not merge faces, swap genders, duplicate a person, or replace anyone with a generic model. No text, no watermark, natural anatomy and hands, clean negative space suitable for a landing hero.
Avoid: no pastel zodiac clip-art, no neon, no lens flares, no fantasy costumes or wizard props, no tarot-shop clutter, no plastic 3D render look, no oversaturation, no extra fingers or warped anatomy, nothing that looks AI-generated.

Expected saved filename: council-key-art-16x9.png
EOF
}

main() {
  local prompt_id="${1:-}"
  if [[ -z "$prompt_id" || "$prompt_id" == "-h" || "$prompt_id" == "--help" ]]; then
    usage
    exit 0
  fi

  require_style_dna

  case "$prompt_id" in
    leyla-hero)
      copy_prompt "$(hero_prompt "Leyla - Western Astrologer hero portrait" "leyla-western-hero.png" "Editorial cinematic portrait of a warm, confident woman in her early 30s, Mediterranean features, long dark hair, wearing an elegant charcoal blazer over a simple top - a modern consultant, not a mystic. She sits in a dark navy studio; softly out of focus behind her, a natal chart wheel is projected in thin gold hairlines on glass, like a heads-up display. Champagne-gold key light from the left, faint cool blue rim light. Shot on 85mm f/1.8, honest skin texture, quiet confidence, direct intelligent gaze.")"
      ;;
    mateo-hero)
      copy_prompt "$(hero_prompt "Mateo - Vedic Astrologer hero portrait" "mateo-vedic-hero.png" "Editorial cinematic portrait of a grounded, thoughtful man in his mid 30s, South Asian features, short dark hair and trimmed beard, wearing a collarless deep-indigo shirt - calm scholar energy, modern, no religious costume. Dark studio with a warm amber glow as if from a single brass oil lamp just out of frame; behind him, a faint band of star positions etched in thin gold lines on dark glass. Warm amber key, deep blue shadows, 85mm, serene and steady expression.")"
      ;;
    naomi-hero)
      copy_prompt "$(hero_prompt "Naomi - Chinese Astrologer hero portrait" "naomi-chinese-hero.png" "Editorial cinematic portrait of a composed, precise woman in her late 20s to early 30s, East Asian features, sleek dark hair, wearing a minimal ink-black high-neck top with one jade-green detail - strategist energy. Dark studio; behind a pane of glass, blurred calligraphic strokes for the Five Elements characters in muted jade and gold hairline. Cool porcelain key light with warm skin fill, 85mm, calm assessing gaze with the hint of a knowing smile. No dragons, no lanterns, no red-and-gold cliche.")"
      ;;
    soren-hero)
      copy_prompt "$(hero_prompt "Soren - Ancient Astrologer hero portrait" "soren-ancient-hero.png" "Editorial cinematic portrait of a precise, reserved man in his late 30s, Northern European features, short blond-grey hair, wearing a dark wool crewneck - a classicist scholar, austere but warm-eyed. Dark studio suggesting a library at night: behind him, softly defocused, a brass astrolabe and the edge of a marble column lit by candle-warm light. Cooler marble-toned key light, single warm accent, 85mm, measured direct gaze. No toga, no beard-wizard, no runes.")"
      ;;
    nadia-hero)
      copy_prompt "$(hero_prompt "Nadia - Evolutionary Astrologer hero portrait" "nadia-evolutionary-hero.png" "Editorial cinematic portrait of an open, perceptive woman in her mid 30s, warm brown skin, natural curly hair, wearing a soft plum-toned knit - spacious therapist-adjacent warmth without clinical sterility. Dark studio at dusk: violet-blue window light from the right, a thin gold crescent of light tracing the wall behind her like a lunar node diagram. Gentle contrast, 85mm, relaxed posture, kind steady eyes that look like they just heard the real question. No crystals, no incense, no bohemian clutter.")"
      ;;
    listening)
      copy_prompt "$(same_person_prompt "listening attentively, head slightly tilted. PNG at the largest size offered, 4:5 portrait. Save as <expert-slug>-listening.png.")"
      ;;
    chart)
      copy_prompt "$(same_person_prompt "looking down consulting a chart on a brass table, hands visible. PNG at the largest size offered, 4:5 portrait. Save as <expert-slug>-chart.png.")"
      ;;
    smile)
      copy_prompt "$(same_person_prompt "soft genuine smile, eyes to camera. PNG at the largest size offered, 4:5 portrait. Save as <expert-slug>-smile.png.")"
      ;;
    avatar)
      copy_prompt "$(same_person_prompt "tight head-and-shoulders crop, centered, calm neutral expression, for a circular avatar that must read clearly at 40 pixels. PNG at the largest square size offered. Save as <expert-slug>-avatar.png.")"
      ;;
    council)
      copy_prompt "$(council_prompt)"
      ;;
    *)
      echo "Unknown prompt id: $prompt_id" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
