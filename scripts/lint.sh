#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SAFEQR_ROOT"
source "$SAFEQR_ROOT/scripts/tool-config.sh"
safeqr_require_check_tools
swiftlint lint --strict --no-cache
swiftformat SafeQR/SafeQR SafeQR/SafeQRTests SafeQR/SafeQRUITests --lint --cache ignore
