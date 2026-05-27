#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROFILE_SELECTOR="${1:-all}"        # all | store | open
RUN_TESTS="${2:-true}"              # true | false

SCHEME="AgentIDEApp"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.0"
DERIVED_DATA="$ROOT_DIR/.ci/DerivedData"
ARTIFACTS_DIR="$ROOT_DIR/artifacts"
RESULTS_DIR="$ROOT_DIR/.ci/results"

mkdir -p "$DERIVED_DATA" "$ARTIFACTS_DIR" "$RESULTS_DIR"

echo "[CI] Installing/validating XcodeGen"
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

echo "[CI] Generating Xcode project"
xcodegen generate

echo "[CI] Available schemes"
xcodebuild -list -project AgentIDE.xcodeproj | tee "$ARTIFACTS_DIR/schemes.txt"

build_profile() {
  local profile="$1"
  local config="$2"
  local log_file="$ARTIFACTS_DIR/build-logs-${profile}.txt"
  local result_bundle="$RESULTS_DIR/${profile}.xcresult"

  echo "[CI] Build settings for ${profile}"
  xcodebuild \
    -project AgentIDE.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$config" \
    -destination "$DESTINATION" \
    -showBuildSettings | tee "$ARTIFACTS_DIR/build-settings-${profile}.txt"

  if [[ "$RUN_TESTS" == "true" ]]; then
    echo "[CI] Running tests for ${profile}"
    xcodebuild \
      -project AgentIDE.xcodeproj \
      -scheme "$SCHEME" \
      -configuration "$config" \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA" \
      -resultBundlePath "$result_bundle" \
      test | tee "$log_file"
  else
    echo "[CI] Running build only for ${profile}"
    xcodebuild \
      -project AgentIDE.xcodeproj \
      -scheme "$SCHEME" \
      -configuration "$config" \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA" \
      -resultBundlePath "$result_bundle" \
      build | tee "$log_file"
  fi
}

case "$PROFILE_SELECTOR" in
  all)
    build_profile "store" "StoreProfile-Debug"
    build_profile "open" "OpenProfile-Debug"
    ;;
  store)
    build_profile "store" "StoreProfile-Debug"
    ;;
  open)
    build_profile "open" "OpenProfile-Debug"
    ;;
  *)
    echo "Invalid profile selector: $PROFILE_SELECTOR (expected: all|store|open)"
    exit 2
    ;;
esac

echo "[CI] Collecting DerivedData diagnostics"
find "$DERIVED_DATA" -maxdepth 4 -type f | head -n 500 > "$ARTIFACTS_DIR/deriveddata-filelist.txt" || true

echo "[CI] Done"
