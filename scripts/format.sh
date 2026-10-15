#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SAFEQR_ROOT"
source "$SAFEQR_ROOT/scripts/tool-config.sh"
command -v swiftformat >/dev/null || { echo "SwiftFormatが必要です。" >&2; exit 1; }
safeqr_require_check_tools
swiftformat SafeQR/SafeQR SafeQR/SafeQRTests SafeQR/SafeQRUITests --cache ignore
