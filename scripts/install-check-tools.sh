#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$SAFEQR_ROOT/scripts/tool-config.sh"

install_tool() {
    local name="$1" url="$2" expected="$3"
    local archive="$SAFEQR_TOOLS_DIR/$name.zip"
    mkdir -p "$SAFEQR_TOOLS_DIR/$name"
    if [[ ! -f "$archive" ]] || [[ "$(shasum -a 256 "$archive" | awk '{print $1}')" != "$expected" ]]; then
        curl --fail --location --silent --show-error "$url" -o "$archive"
    fi
    local actual
    actual="$(shasum -a 256 "$archive" | awk '{print $1}')"
    [[ "$actual" == "$expected" ]] || { echo "$name のSHA-256が一致しません。" >&2; exit 1; }
    unzip -qo "$archive" -d "$SAFEQR_TOOLS_DIR/$name"
    chmod +x "$SAFEQR_TOOLS_DIR/$name/$name"
}

install_tool swiftlint "https://github.com/realm/SwiftLint/releases/download/$SAFEQR_SWIFTLINT_VERSION/portable_swiftlint.zip" "$SAFEQR_SWIFTLINT_SHA256"
install_tool swiftformat "https://github.com/nicklockwood/SwiftFormat/releases/download/$SAFEQR_SWIFTFORMAT_VERSION/swiftformat.zip" "$SAFEQR_SWIFTFORMAT_SHA256"
swiftlint version
swiftformat --version
