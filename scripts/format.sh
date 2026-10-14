#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SAFEQR_ROOT"
command -v swiftformat >/dev/null || { echo "SwiftFormatが必要です。" >&2; exit 1; }
swiftformat SafeQR/SafeQR SafeQR/SafeQRTests SafeQR/SafeQRUITests --cache ignore
