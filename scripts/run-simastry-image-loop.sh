#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_GEN="${IMAGE_GEN:-${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/image_gen.py}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PROMPT_DIR="$ROOT_DIR/prompts/imagegen/simastry-experts"
STYLE_DNA_FILE="$PROMPT_DIR/style-dna.txt"
HERO_MANIFEST="$PROMPT_DIR/heroes.jsonl"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/output/imagegen/simastry-experts}"
PHASE="${1:-help}"

if [[ "$PHASE" != "help" ]]; then
  shift || true
fi

usage() {
  cat <<'EOF'
Usage:
  scripts/run-simastry-image-loop.sh heroes [--dry-run] [--force]
  scripts/run-simastry-image-loop.sh variants [--dry-run] [--force]
  scripts/run-simastry-image-loop.sh council [--dry-run] [--force]
  scripts/run-simastry-image-loop.sh validate

Environment:
  OPENAI_API_KEY   Required for live API runs.
  OUT_DIR          Optional output directory. Defaults to output/imagegen/simastry-experts.
  IMAGE_GEN        Optional path to the bundled image_gen.py CLI.
  PYTHON_BIN       Optional Python executable. Defaults to python3.

Run order:
  1. heroes
  2. inspect the five *-hero.png files
  3. variants
  4. council
  5. validate
EOF
}

require_cli() {
  if [[ ! -f "$IMAGE_GEN" ]]; then
    echo "Missing image generation CLI: $IMAGE_GEN" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

style_dna() {
  cat "$STYLE_DNA_FILE"
}

run_heroes() {
  require_cli
  require_file "$HERO_MANIFEST"
  mkdir -p "$OUT_DIR"
  "$PYTHON_BIN" "$IMAGE_GEN" generate-batch \
    --input "$HERO_MANIFEST" \
    --out-dir "$OUT_DIR" \
    --model gpt-image-2 \
    --quality high \
    --output-format png \
    --no-augment \
    --concurrency 1 \
    --fail-fast \
    "$@"
}

expert_hero_path() {
  local slug="$1"
  printf '%s/%s-hero.png' "$OUT_DIR" "$slug"
}

variant_prompt() {
  local slug="$1"
  local request="$2"
  local label="$3"
  cat <<EOF
$(style_dna)

Asset type: expert portrait variant for Simastry.
Primary request: Same exact person as the reference image, same lighting and wardrobe: $request
Composition/framing: 4:5 editorial portrait, 85mm shallow depth of field, dark observatory studio, calm modern consultant energy.
Identity lock: preserve the reference person's face, apparent age, hair, skin tone, wardrobe, and overall presence. This is $slug, and the output must look like the same person as the approved hero portrait.
Variant label: $label.
Constraints: no text; no watermark; keep anatomy natural; preserve Simastry's champagne-gold, celestial-blue, muted-violet, deep-black visual language.
Avoid: no pastel zodiac clip-art, no neon, no lens flares, no fantasy costumes or wizard props, no tarot-shop clutter, no plastic 3D render look, no oversaturation, no extra fingers or warped anatomy, nothing that looks AI-generated.
EOF
}

avatar_prompt() {
  local slug="$1"
  cat <<EOF
$(style_dna)

Asset type: square avatar portrait for Simastry.
Primary request: Same exact person as the reference image, tight head-and-shoulders crop, centered, calm neutral expression, for a circular avatar that must read clearly at 40 pixels.
Composition/framing: 1:1 square, centered head-and-shoulders crop, clean silhouette, eyes readable, dark observatory background with very subtle gold hairline detail.
Identity lock: preserve the reference person's face, apparent age, hair, skin tone, wardrobe, and overall presence. This is $slug, and the output must look like the same person as the approved hero portrait.
Constraints: no text; no watermark; no busy background; strong readability at small UI sizes.
Avoid: no pastel zodiac clip-art, no neon, no lens flares, no fantasy costumes or wizard props, no tarot-shop clutter, no plastic 3D render look, no oversaturation, no extra fingers or warped anatomy, nothing that looks AI-generated.
EOF
}

run_variant_for_expert() {
  local slug="$1"
  local hero
  hero="$(expert_hero_path "$slug")"
  require_file "$hero"

  "$PYTHON_BIN" "$IMAGE_GEN" edit \
    --image "$hero" \
    --prompt "$(variant_prompt "$slug" "listening attentively, head slightly tilted." "listening")" \
    --model gpt-image-2 \
    --size 2560x3200 \
    --quality high \
    --output-format png \
    --no-augment \
    --out "$OUT_DIR/$slug-listening.png" \
    "$@"

  "$PYTHON_BIN" "$IMAGE_GEN" edit \
    --image "$hero" \
    --prompt "$(variant_prompt "$slug" "looking down consulting a chart on a brass table, hands visible." "chart")" \
    --model gpt-image-2 \
    --size 2560x3200 \
    --quality high \
    --output-format png \
    --no-augment \
    --out "$OUT_DIR/$slug-chart.png" \
    "$@"

  "$PYTHON_BIN" "$IMAGE_GEN" edit \
    --image "$hero" \
    --prompt "$(variant_prompt "$slug" "soft genuine smile, eyes to camera." "smile")" \
    --model gpt-image-2 \
    --size 2560x3200 \
    --quality high \
    --output-format png \
    --no-augment \
    --out "$OUT_DIR/$slug-smile.png" \
    "$@"

  "$PYTHON_BIN" "$IMAGE_GEN" edit \
    --image "$hero" \
    --prompt "$(avatar_prompt "$slug")" \
    --model gpt-image-2 \
    --size 2048x2048 \
    --quality high \
    --output-format png \
    --no-augment \
    --out "$OUT_DIR/$slug-avatar.png" \
    "$@"
}

run_variants() {
  require_cli
  mkdir -p "$OUT_DIR"
  run_variant_for_expert "leyla-western" "$@"
  run_variant_for_expert "mateo-vedic" "$@"
  run_variant_for_expert "naomi-chinese" "$@"
  run_variant_for_expert "soren-ancient" "$@"
  run_variant_for_expert "nadia-evolutionary" "$@"
}

council_prompt() {
  cat <<'EOF'
Style DNA - Simastry. Design language: Apple keynote restraint meets a dark observatory. Deep space-black backgrounds (#0A0A0F), one warm champagne-gold accent light, secondary cool celestial blue and muted violet. Celestial ornament is drawn as thin engraved hairline linework (like a brass star chart), never filled shapes. Glass is real Apple "Liquid Glass": transparent panes with soft refraction, 1px light rims, gentle inner glow - not frosted plastic, not neumorphism. Photography is editorial and cinematic: soft key light, honest skin texture, shallow depth of field.

Asset type: council key art for Simastry landing and website hero.
Primary request: Group editorial photograph of five consultants, using these exact five people from the reference images: Leyla, Mateo, Naomi, Soren, and Nadia. They stand and sit around a circular black-glass table in a dark observatory studio; on the table, a star chart glows in thin gold hairlines, lighting their faces from below like a strategy table. Staggered depth, each person distinct, calm and collegial - a council of specialists, not a band photo. One gold key light logic across all five, faint blue atmosphere. 16:9, cinematic.
Identity lock: preserve the five reference identities clearly. Do not merge faces, swap genders, duplicate a person, or replace anyone with a generic model.
Constraints: no text; no watermark; natural anatomy and hands; believable editorial photography; clean negative space suitable for a landing hero.
Avoid: no pastel zodiac clip-art, no neon, no lens flares, no fantasy costumes or wizard props, no tarot-shop clutter, no plastic 3D render look, no oversaturation, no extra fingers or warped anatomy, nothing that looks AI-generated.
EOF
}

run_council() {
  require_cli
  mkdir -p "$OUT_DIR"
  local leyla mateo naomi soren nadia
  leyla="$(expert_hero_path "leyla-western")"
  mateo="$(expert_hero_path "mateo-vedic")"
  naomi="$(expert_hero_path "naomi-chinese")"
  soren="$(expert_hero_path "soren-ancient")"
  nadia="$(expert_hero_path "nadia-evolutionary")"
  require_file "$leyla"
  require_file "$mateo"
  require_file "$naomi"
  require_file "$soren"
  require_file "$nadia"

  "$PYTHON_BIN" "$IMAGE_GEN" edit \
    --image "$leyla" \
    --image "$mateo" \
    --image "$naomi" \
    --image "$soren" \
    --image "$nadia" \
    --prompt "$(council_prompt)" \
    --model gpt-image-2 \
    --size 3840x2160 \
    --quality high \
    --output-format png \
    --no-augment \
    --out "$OUT_DIR/council-key-art-16x9.png" \
    "$@"
}

validate_dimensions() {
  local file="$1"
  local expected_width="$2"
  local expected_height="$3"
  require_file "$file"
  local width height
  width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ {print $2}')"
  height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ {print $2}')"
  if [[ "$width" != "$expected_width" || "$height" != "$expected_height" ]]; then
    echo "Dimension mismatch: $file is ${width}x${height}, expected ${expected_width}x${expected_height}" >&2
    exit 1
  fi
  echo "OK $file ${width}x${height}"
}

run_validate() {
  local slug
  for slug in leyla-western mateo-vedic naomi-chinese soren-ancient nadia-evolutionary; do
    validate_dimensions "$OUT_DIR/$slug-hero.png" 2560 3200
    validate_dimensions "$OUT_DIR/$slug-listening.png" 2560 3200
    validate_dimensions "$OUT_DIR/$slug-chart.png" 2560 3200
    validate_dimensions "$OUT_DIR/$slug-smile.png" 2560 3200
    validate_dimensions "$OUT_DIR/$slug-avatar.png" 2048 2048
  done
  validate_dimensions "$OUT_DIR/council-key-art-16x9.png" 3840 2160
}

case "$PHASE" in
  help|-h|--help)
    usage
    ;;
  heroes)
    run_heroes "$@"
    ;;
  variants)
    run_variants "$@"
    ;;
  council)
    run_council "$@"
    ;;
  validate)
    run_validate
    ;;
  *)
    echo "Unknown phase: $PHASE" >&2
    usage >&2
    exit 1
    ;;
esac
