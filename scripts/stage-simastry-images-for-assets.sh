#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_HANDOFF_DIR="$ROOT_DIR/ExternalAssets/simastry-expert-asset-handoff"
DEFAULT_SOURCE_DIR="$DEFAULT_HANDOFF_DIR/source-images"
if [[ ! -d "$DEFAULT_SOURCE_DIR" ]]; then
  DEFAULT_SOURCE_DIR="$ROOT_DIR/output/imagegen/simastry-experts"
fi
SRC_DIR="${SRC_DIR:-$DEFAULT_SOURCE_DIR}"
STAGE_DIR="${STAGE_DIR:-$DEFAULT_HANDOFF_DIR}"

usage() {
  cat <<'EOF'
Usage:
  scripts/stage-simastry-images-for-assets.sh

Copies generated Simastry expert portraits into a Claude-ready handoff folder:
  ExternalAssets/simastry-expert-asset-handoff/

Expected source files:
  ExternalAssets/simastry-expert-asset-handoff/source-images/<expert-slug>-hero.png
  ExternalAssets/simastry-expert-asset-handoff/source-images/<expert-slug>-listening.png
  ExternalAssets/simastry-expert-asset-handoff/source-images/<expert-slug>-chart.png
  ExternalAssets/simastry-expert-asset-handoff/source-images/<expert-slug>-smile.png
  ExternalAssets/simastry-expert-asset-handoff/source-images/<expert-slug>-avatar.png

This script does not modify App/Assets.xcassets.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required source image: $path" >&2
    exit 1
  fi
}

copy_asset() {
  local source="$1"
  local legacy_name="$2"
  local imageset_dir="$STAGE_DIR/Assets.xcassets/$legacy_name.imageset"
  mkdir -p "$imageset_dir"
  cp "$source" "$imageset_dir/$legacy_name.png"
  cat > "$imageset_dir/Contents.json" <<EOF
{
  "images": [
    {
      "filename": "$legacy_name.png",
      "idiom": "universal"
    }
  ],
  "info": {
    "author": "xcode",
    "version": 1
  }
}
EOF
}

stage_expert() {
  local expert_slug="$1"
  local legacy_slug="$2"

  local hero="$SRC_DIR/$expert_slug-hero.png"
  local listening="$SRC_DIR/$expert_slug-listening.png"
  local chart="$SRC_DIR/$expert_slug-chart.png"
  local smile="$SRC_DIR/$expert_slug-smile.png"
  local avatar="$SRC_DIR/$expert_slug-avatar.png"

  require_file "$hero"
  require_file "$listening"
  require_file "$chart"
  require_file "$smile"
  require_file "$avatar"

  copy_asset "$avatar" "Factory_${legacy_slug}_profile"
  copy_asset "$hero" "Factory_${legacy_slug}_card"
  copy_asset "$hero" "Factory_${legacy_slug}_post1"
  copy_asset "$listening" "Factory_${legacy_slug}_post2"
  copy_asset "$chart" "Factory_${legacy_slug}_post3"
  copy_asset "$smile" "Factory_${legacy_slug}_post4"
  copy_asset "$hero" "Factory_${legacy_slug}_post5"
  copy_asset "$listening" "Factory_${legacy_slug}_post6"
  copy_asset "$chart" "Factory_${legacy_slug}_post7"
  copy_asset "$smile" "Factory_${legacy_slug}_post8"
  copy_asset "$hero" "Factory_${legacy_slug}_post9"
  copy_asset "$listening" "Factory_${legacy_slug}_post10"
}

write_manifest() {
  cat > "$STAGE_DIR/HANDOFF.md" <<'EOF'
# Simastry Expert Asset Handoff

This folder mirrors the legacy Factory imageset names that Claude should use to replace the current app assets.

Source identity mapping:

- Leyla -> `Factory_virgo-mara_*`
- Mateo -> `Factory_libra-mateo_*`
- Naomi -> `Factory_capricorn-naomi_*`
- Soren -> `Factory_aries-cassian_*`
- Nadia -> `Factory_sagittarius-nadia_*`

Replacement mapping per expert:

- `profile` uses the generated avatar crop
- `card` uses the generated hero portrait
- `post1`, `post5`, `post9` use the generated hero portrait
- `post2`, `post6`, `post10` use the generated listening portrait
- `post3`, `post7` use the generated chart portrait
- `post4`, `post8` use the generated smile portrait

Claude handoff:

- Replace matching imagesets under `App/Assets.xcassets` with the folders in `Assets.xcassets/`.
- The landing background swap and emblem set are intentionally separate from this portrait handoff.
- This folder does not modify the app by itself.
EOF
}

rm -rf "$STAGE_DIR/Assets.xcassets"
mkdir -p "$STAGE_DIR/Assets.xcassets"

stage_expert "leyla-western" "virgo-mara"
stage_expert "mateo-vedic" "libra-mateo"
stage_expert "naomi-chinese" "capricorn-naomi"
stage_expert "soren-ancient" "aries-cassian"
stage_expert "nadia-evolutionary" "sagittarius-nadia"
write_manifest

echo "Staged portrait asset handoff:"
echo "$STAGE_DIR"
