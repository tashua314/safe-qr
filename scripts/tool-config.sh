#!/usr/bin/env bash
# この組合せで整形・lint・Debug/Release・全テストを検証する。
SAFEQR_SWIFTLINT_VERSION=0.63.2
SAFEQR_SWIFTFORMAT_VERSION=0.61.1
SAFEQR_SWIFTLINT_SHA256=c59a405c85f95b92ced677a500804e081596a4cae4a6a485af76065557d6ed29
SAFEQR_SWIFTFORMAT_SHA256=b990400779aceb7d7020796eb9ba814d4480543f671d38fc0ff48cb72f04c584
SAFEQR_TOOLS_DIR="$SAFEQR_ROOT/.artifacts/tools"
export PATH="$SAFEQR_TOOLS_DIR/swiftlint:$SAFEQR_TOOLS_DIR/swiftformat:$PATH"

safeqr_require_check_tools() {
    command -v swiftlint >/dev/null && command -v swiftformat >/dev/null || { echo "make tools が必要です。" >&2; return 1; }
    [[ "$(swiftlint version)" == "$SAFEQR_SWIFTLINT_VERSION" ]] || { echo "make tools でSwiftLintの固定版を用意してください。" >&2; return 1; }
    [[ "$(swiftformat --version)" == "$SAFEQR_SWIFTFORMAT_VERSION" ]] || { echo "make tools でSwiftFormatの固定版を用意してください。" >&2; return 1; }
}
