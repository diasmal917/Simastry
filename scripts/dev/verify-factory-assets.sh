#!/bin/zsh

# Verifies the frozen 24-person Factory cast and every approved image slot.
# The initial manifest restores the approved iOS asset blobs from 498b244e.
# Use --update only after an intentional asset approval to rewrite the hashes.

set -euo pipefail

factory_repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
factory_catalog="$factory_repo_root/App/Models/AppModels.swift"
factory_assets="$factory_repo_root/App/Assets.xcassets"
factory_manifest="$factory_repo_root/docs/factory-approved-assets.sha256"
factory_mode="${1:---check}"

if [[ "$factory_mode" != "--check" && "$factory_mode" != "--update" ]]; then
  echo "usage: scripts/dev/verify-factory-assets.sh [--check|--update]" >&2
  exit 2
fi

factory_slugs_file="$(mktemp /tmp/simastry-factory-slugs.XXXXXX)"
factory_expected_paths_file="$(mktemp /tmp/simastry-factory-paths.XXXXXX)"
factory_expected_sets_file="$(mktemp /tmp/simastry-factory-sets.XXXXXX)"
factory_actual_sets_file="$(mktemp /tmp/simastry-factory-actual-sets.XXXXXX)"
factory_manifest_paths_file="$(mktemp /tmp/simastry-factory-manifest-paths.XXXXXX)"
factory_computed_manifest="$(mktemp /tmp/simastry-factory-manifest.XXXXXX)"

factory_cleanup() {
  rm -f -- \
    "$factory_slugs_file" \
    "$factory_expected_paths_file" \
    "$factory_expected_sets_file" \
    "$factory_actual_sets_file" \
    "$factory_manifest_paths_file" \
    "$factory_computed_manifest"
}
trap factory_cleanup EXIT

sed -nE 's/^[[:space:]]*profile\("([a-z0-9-]+)",.*/\1/p' "$factory_catalog" \
  | LC_ALL=C sort > "$factory_slugs_file"

factory_slug_count="$(wc -l < "$factory_slugs_file" | tr -d ' ')"
if [[ "$factory_slug_count" -ne 24 ]]; then
  echo "Factory cast must contain exactly 24 profiles; found $factory_slug_count." >&2
  exit 1
fi

factory_duplicate_slugs="$(uniq -d "$factory_slugs_file")"
if [[ -n "$factory_duplicate_slugs" ]]; then
  echo "Factory companion slugs must be unique:" >&2
  echo "$factory_duplicate_slugs" >&2
  exit 1
fi

factory_catalog_post_counts="$(
  sed -n '/static let all: \[FactoryCompanionProfile\]/,/^    ]/p' "$factory_catalog" \
    | sed -nE 's/.*postCount: ([0-9]+).*/\1/p'
)"
if [[ -n "$factory_catalog_post_counts" ]]; then
  while IFS= read -r factory_catalog_post_count; do
    if [[ "$factory_catalog_post_count" -ne 10 ]]; then
      echo "Every Factory companion must expose ten posts; found postCount: $factory_catalog_post_count." >&2
      exit 1
    fi
  done <<< "$factory_catalog_post_counts"
fi

for factory_sign in \
  aries taurus gemini cancer leo virgo \
  libra scorpio sagittarius capricorn aquarius pisces; do
  factory_sign_count="$(awk -F- -v sign="$factory_sign" '$1 == sign { count += 1 } END { print count + 0 }' "$factory_slugs_file")"
  if [[ "$factory_sign_count" -ne 2 ]]; then
    echo "Factory cast must contain exactly two $factory_sign profiles; found $factory_sign_count." >&2
    exit 1
  fi
done

while IFS= read -r factory_slug; do
  for factory_slot in profile card; do
    factory_stem="Factory_${factory_slug}_${factory_slot}"
    echo "App/Assets.xcassets/${factory_stem}.imageset/${factory_stem}.jpg" >> "$factory_expected_paths_file"
    echo "App/Assets.xcassets/${factory_stem}.imageset" >> "$factory_expected_sets_file"
  done

  for factory_post_number in {1..10}; do
    factory_stem="Factory_${factory_slug}_post${factory_post_number}"
    echo "App/Assets.xcassets/${factory_stem}.imageset/${factory_stem}.jpg" >> "$factory_expected_paths_file"
    echo "App/Assets.xcassets/${factory_stem}.imageset" >> "$factory_expected_sets_file"
  done
done < "$factory_slugs_file"

LC_ALL=C sort -o "$factory_expected_paths_file" "$factory_expected_paths_file"
LC_ALL=C sort -o "$factory_expected_sets_file" "$factory_expected_sets_file"

factory_slot_count="$(wc -l < "$factory_expected_paths_file" | tr -d ' ')"
factory_unique_slot_count="$(uniq "$factory_expected_paths_file" | wc -l | tr -d ' ')"
if [[ "$factory_slot_count" -ne 288 || "$factory_unique_slot_count" -ne 288 ]]; then
  echo "Factory manifest must resolve to 288 unique slots; found $factory_slot_count rows and $factory_unique_slot_count unique rows." >&2
  exit 1
fi

find "$factory_assets" -maxdepth 1 -type d -name 'Factory_*.imageset' \
  | sed "s#^$factory_repo_root/##" \
  | LC_ALL=C sort > "$factory_actual_sets_file"

if ! diff -u "$factory_expected_sets_file" "$factory_actual_sets_file"; then
  echo "Factory asset catalog has a missing, duplicate, or unexpected image set." >&2
  exit 1
fi

while IFS= read -r factory_relative_path; do
  factory_image_path="$factory_repo_root/$factory_relative_path"
  factory_set_path="${factory_image_path:h}"
  factory_contents_path="$factory_set_path/Contents.json"
  factory_expected_filename="${factory_image_path:t}"

  if [[ ! -f "$factory_image_path" || ! -f "$factory_contents_path" ]]; then
    echo "Missing Factory slot or Contents.json: $factory_relative_path" >&2
    exit 1
  fi

  factory_set_file_count="$(find "$factory_set_path" -maxdepth 1 -type f | wc -l | tr -d ' ')"
  if [[ "$factory_set_file_count" -ne 2 ]]; then
    echo "Factory image set must contain exactly Contents.json plus one approved image: ${factory_set_path#$factory_repo_root/}" >&2
    exit 1
  fi

  factory_referenced_filename="$(plutil -extract images.0.filename raw -o - "$factory_contents_path")"
  if [[ "$factory_referenced_filename" != "$factory_expected_filename" ]]; then
    echo "Factory Contents.json references '$factory_referenced_filename' instead of '$factory_expected_filename'." >&2
    exit 1
  fi

  factory_digest="$(shasum -a 256 "$factory_image_path" | awk '{ print $1 }')"
  printf '%s  %s\n' "$factory_digest" "$factory_relative_path" >> "$factory_computed_manifest"
done < "$factory_expected_paths_file"

if [[ "$factory_mode" == "--update" ]]; then
  cp "$factory_computed_manifest" "$factory_manifest"
  echo "Updated $factory_manifest with 288 approved SHA-256 hashes."
fi

if [[ ! -f "$factory_manifest" ]]; then
  echo "Missing approved Factory asset manifest: $factory_manifest" >&2
  exit 1
fi

if ! awk 'NF != 2 || length($1) != 64 || $1 !~ /^[0-9a-f]+$/ { exit 1 }' "$factory_manifest"; then
  echo "Factory manifest contains a malformed row." >&2
  exit 1
fi

awk '{ print $2 }' "$factory_manifest" > "$factory_manifest_paths_file"
factory_manifest_count="$(wc -l < "$factory_manifest_paths_file" | tr -d ' ')"
factory_manifest_unique_count="$(LC_ALL=C sort "$factory_manifest_paths_file" | uniq | wc -l | tr -d ' ')"
if [[ "$factory_manifest_count" -ne 288 || "$factory_manifest_unique_count" -ne 288 ]]; then
  echo "Factory manifest must contain exactly 288 unique asset paths; found $factory_manifest_count rows and $factory_manifest_unique_count unique rows." >&2
  exit 1
fi

if ! diff -u "$factory_expected_paths_file" "$factory_manifest_paths_file"; then
  echo "Factory manifest paths are missing, duplicated, unexpected, or out of deterministic order." >&2
  exit 1
fi

if ! diff -u "$factory_manifest" "$factory_computed_manifest"; then
  echo "Factory asset hash mismatch. Run with --update only after intentional asset approval." >&2
  exit 1
fi

(
  cd "$factory_repo_root"
  shasum -a 256 --check --strict --status "$factory_manifest"
)

echo "Factory assets verified: 24 unique companions, 288 image sets, 288 approved SHA-256 hashes."
