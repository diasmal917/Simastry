#!/usr/bin/env bash
set -euo pipefail

CANONICAL="/Users/chiburashka/Documents/Codex/Simastry"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

[[ "$ROOT" == "$CANONICAL" ]] || fail "wrong source path: $ROOT"
pass "canonical path"

cd "$ROOT"

[[ -f "Simastry.xcodeproj/project.pbxproj" ]] || fail "missing Xcode project"
[[ -f "Simastry/SimastryApp/Views/MainTabView.swift" ]] || fail "missing MainTabView"
[[ -f "Simastry/SimastryApp/Views/HomeView.swift" ]] || fail "missing HomeView"
[[ -f "Simastry/SimastryApp/Media/NadiaFeaturedGuide.mp4" ]] || fail "missing Nadia video"
[[ -d "Simastry/SimastryApp/Assets.xcassets/Factory_sagittarius-nadia_card.imageset" ]] || fail "missing Nadia Factory card asset"
pass "Nadia/Factory files"

grep -q 'Tab("Today"' "Simastry/SimastryApp/Views/MainTabView.swift" || fail "Today tab not found"
grep -q 'NadiaFeaturedGuide' "Simastry/SimastryApp/Views/HomeView.swift" || fail "HomeView does not reference Nadia video"
grep -q 'PRODUCT_BUNDLE_IDENTIFIER = app.simastry.ios;' "Simastry.xcodeproj/project.pbxproj" || fail "bundle id is not app.simastry.ios"
grep -q 'CURRENT_PROJECT_VERSION = 2;' "Simastry.xcodeproj/project.pbxproj" || fail "build number is not 2"
pass "project identity"

if [[ -f ".xcodebuildmcp/config.yaml" ]]; then
  grep -q 'activeSessionDefaultsProfile: simastry-canonical' ".xcodebuildmcp/config.yaml" || fail "xcodebuildmcp active profile is not simastry-canonical"
  grep -q 'projectPath: /Users/chiburashka/Documents/Codex/Simastry/Simastry.xcodeproj' ".xcodebuildmcp/config.yaml" || fail "xcodebuildmcp project path is not canonical"
  grep -q 'derivedDataPath: /Users/chiburashka/Library/Developer/Xcode/DerivedData/Simastry-canonical' ".xcodebuildmcp/config.yaml" || fail "xcodebuildmcp DerivedData is not canonical"
  grep -q 'bundleId: app.simastry.ios' ".xcodebuildmcp/config.yaml" || fail "xcodebuildmcp bundle id is not app.simastry.ios"
  if grep -n -E 'app\.rork|Simastry-finalization|Simastry-current|/tmp/simastry|_archives' ".xcodebuildmcp/config.yaml" >/tmp/simastry_xcodebuildmcp_stale.txt; then
    cat /tmp/simastry_xcodebuildmcp_stale.txt >&2
    fail "stale xcodebuildmcp profile reference found"
  fi
  pass "xcodebuildmcp canonical profile"
fi

if grep -R -n -E 'Rork|app\.rork|EXPO_PUBLIC_RORK' \
  --exclude-dir='.git' \
  --exclude-dir='DerivedData' \
  --exclude-dir='Build' \
  Simastry Simastry.xcodeproj SimastryTests SimastryUITests SimastryInfo.plist >/tmp/simastry_rork_scan.txt; then
  cat /tmp/simastry_rork_scan.txt >&2
  fail "stale Rork reference found"
fi
pass "no Rork references"

if find Simastry SimastryTests SimastryUITests -type f -flags +dataless | grep -q .; then
  find Simastry SimastryTests SimastryUITests -type f -flags +dataless >&2
  fail "cloud placeholder files found"
fi
pass "no cloud-placeholder files"

echo "Canonical Simastry source is ready."
