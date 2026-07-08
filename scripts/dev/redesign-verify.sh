#!/bin/zsh
# Build Simastry from a clean mirror (repo builds hang while Codex is active),
# install on the iPhone 17 Pro sim, launch with the given args, screenshot.
# Usage:
#   scripts/dev/redesign-verify.sh build
#   scripts/dev/redesign-verify.sh shoot <name> <wait-seconds> [launch-args...]
#   scripts/dev/redesign-verify.sh landing <name>       # fresh-install, signed-out
set -u
REPO="$(cd "$(dirname "$0")/../.." && pwd)" || exit 1
WORK="${SIMASTRY_VERIFY_DIR:-$HOME/.cache/simastry-verify}"
MIRROR="$WORK/mirror"; DD="$WORK/DerivedData"; OUT="$WORK/shots"
BUNDLE="app.bitrig.new.97a916bd-b131-48aa-a70e-082a3526b819"
SIM="${SIMASTRY_SIM_UDID:-$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 17 Pro \(/{print $2; exit}')}"
APP="$DD/Build/Products/Debug-iphonesimulator/Simastry.app"
mkdir -p "$MIRROR" "$OUT"

case "${1:-}" in
build)
  rsync -a --delete \
    --exclude '.git' --exclude 'build' --exclude 'output' --exclude 'website' \
    --exclude 'reports' --exclude 'node_modules' --exclude 'Simastry.xcodeproj' \
    "$REPO/" "$MIRROR/"
  cd "$MIRROR" || exit 1
  xcodegen generate --spec Project.json || exit 1
  xcodebuild -project Simastry.xcodeproj -scheme Simastry -configuration Debug \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build > "$WORK/build.log" 2>&1
  rc=$?
  if [ $rc -ne 0 ]; then echo "BUILD FAILED"; grep -m8 -B2 "error:" "$WORK/build.log"; exit 1; fi
  tail -2 "$WORK/build.log"
  xattr -cr "$APP"
  find "$APP" \( -name '*.dylib' -o -name '*.framework' -o -name '*.appex' \) -print0 |
    while IFS= read -r -d '' i; do codesign --force --sign - "$i" 2>/dev/null; done
  codesign --force --sign - "$APP/Simastry" 2>/dev/null
  codesign --force --sign - "$APP" 2>/dev/null
  xcrun simctl boot "$SIM" 2>/dev/null; open -a Simulator
  xcrun simctl install "$SIM" "$APP" || exit 1
  echo "BUILD+INSTALL OK ($SIM)"
  ;;
shoot)
  name=$2; wait=$3; shift 3
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null
  xcrun simctl launch "$SIM" "$BUNDLE" "$@" >/dev/null || { echo "LAUNCH FAIL"; exit 1; }
  python3 -c "import time,sys; time.sleep(float(sys.argv[1]))" "$wait"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$OUT/$name.png"
  ;;
landing)
  name=$2
  xcrun simctl terminate "$SIM" "$BUNDLE" 2>/dev/null
  xcrun simctl uninstall "$SIM" "$BUNDLE"; xcrun simctl install "$SIM" "$APP" || { echo "INSTALL FAIL"; exit 1; }
  xcrun simctl launch "$SIM" "$BUNDLE" >/dev/null || { echo "LAUNCH FAIL"; exit 1; }
  python3 -c "import time; time.sleep(8)"
  xcrun simctl io "$SIM" screenshot "$OUT/$name.png" >/dev/null 2>&1 && echo "$OUT/$name.png"
  ;;
*) echo "usage: build | shoot <name> <wait> [args...] | landing <name>"; exit 2;;
esac
