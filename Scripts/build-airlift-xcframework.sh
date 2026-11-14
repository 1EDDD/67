#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AIRCARD_REPO="https://github.com/Mak5er/AirCard-iOS.git"
AIRCARD_COMMIT="40640c4d827aeab8d798285b57d24fcf6be070d0"
BUILD_ROOT="/tmp/resolution-studio-aircard-$AIRCARD_COMMIT"
PATCH_FILE="$ROOT/Scripts/airlift-read-file.patch"

export DEVELOPER_DIR="$(xcode-select -p)"
export IPHONEOS_DEPLOYMENT_TARGET="18.0"

source "$HOME/.cargo/env" 2>/dev/null || true

# Reuse compiled Rust artifacts between CI runs to avoid rebuilding all Airlift dependencies.
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$HOME/.cache/67-airlift-target}"
mkdir -p "$CARGO_TARGET_DIR"

rm -rf "$BUILD_ROOT"
git clone --quiet --filter=blob:none "$AIRCARD_REPO" "$BUILD_ROOT"
git -C "$BUILD_ROOT" checkout --quiet --detach "$AIRCARD_COMMIT"

# The patch is authored against the pinned AirCard commit above. Use a normal
# context-checked apply: --3way requires the patch's old/new blob IDs to match,
# and those IDs change whenever our local patch is refined.
git -C "$BUILD_ROOT" apply --check "$PATCH_FILE"
git -C "$BUILD_ROOT" apply "$PATCH_FILE"

# AirCard's build script assumes Cargo's default target/ directory.
# Our CI cache relocates Cargo output, so point XCFramework packaging at that cache.
python3 - "$BUILD_ROOT/build-ios.sh" "$CARGO_TARGET_DIR" <<'PY'
from pathlib import Path
import sys
script = Path(sys.argv[1])
target_dir = sys.argv[2]
content = script.read_text()
content = content.replace("rust-core/target/", target_dir.rstrip("/") + "/")
script.write_text(content)
PY

"$BUILD_ROOT/build-ios.sh"

rm -rf "$ROOT/AirliftFFI.xcframework"
cp -R "$BUILD_ROOT/AirliftFFI.xcframework" "$ROOT/AirliftFFI.xcframework"

echo "AirliftFFI.xcframework ready."
