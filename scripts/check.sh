#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SAFEQR_ROOT"
source "$SAFEQR_ROOT/scripts/tool-config.sh"

for tool in swiftlint swiftformat xcodebuild python3; do
    command -v "$tool" >/dev/null || { echo "$tool が必要です。" >&2; exit 1; }
done

safeqr_require_check_tools
xcodebuild -version
swiftlint version
swiftformat --version
swiftlint lint --strict --no-cache
swiftformat SafeQR/SafeQR SafeQR/SafeQRTests SafeQR/SafeQRUITests --lint --cache ignore
python3 scripts/check-log-policy.py
plutil -lint SafeQR/SafeQR.xcodeproj/project.pbxproj SafeQR/SafeQR/Info.plist

SAFEQR_SIMULATOR_ID="${SAFEQR_SIMULATOR_ID:-$(python3 scripts/simulator_destination.py)}"
SAFEQR_ARTIFACTS="${SAFEQR_ARTIFACTS:-$SAFEQR_ROOT/.artifacts}"
mkdir -p "$SAFEQR_ARTIFACTS"
SAFEQR_DERIVED_DATA="$SAFEQR_ARTIFACTS/DerivedData"
COMMON=(-project SafeQR/SafeQR.xcodeproj -scheme SafeQR -derivedDataPath "$SAFEQR_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES)

run_build() {
    local configuration="$1"
    local logfile="$SAFEQR_ARTIFACTS/$configuration-build.log"
    if ! xcodebuild "${COMMON[@]}" -configuration "$configuration" -destination 'generic/platform=iOS Simulator' build > "$logfile" 2>&1; then
        cat "$logfile"
        return 1
    fi
    echo "$configuration build: 成功"
}
run_build Debug
run_build Release

# カメラ権限は検証専用Simulator内に限る。実機カメラの許可を確認した扱いにはしない。
xcrun simctl bootstatus "$SAFEQR_SIMULATOR_ID" -b
xcrun simctl install "$SAFEQR_SIMULATOR_ID" "$SAFEQR_DERIVED_DATA/Build/Products/Debug-iphonesimulator/SafeQR.app"
xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" grant camera jp.techguide.SafeQR

SAFEQR_RESULT="$SAFEQR_ARTIFACTS/Tests-$(date +%s)-$$.xcresult"
if ! xcodebuild "${COMMON[@]}" -configuration Debug -destination "platform=iOS Simulator,id=$SAFEQR_SIMULATOR_ID" -parallel-testing-enabled NO -resultBundlePath "$SAFEQR_RESULT" test > "$SAFEQR_ARTIFACTS/tests.log" 2>&1; then
    cat "$SAFEQR_ARTIFACTS/tests.log"
    exit 1
fi
# 拒否状態は通常スイートと分離し、CIでも必ず実行する。終了/失敗時は専用端末の許可を戻す。
trap 'xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" grant camera jp.techguide.SafeQR' EXIT
xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" revoke camera jp.techguide.SafeQR
SAFEQR_DENIED_RESULT="$SAFEQR_ARTIFACTS/CameraDenied-$(date +%s)-$$.xcresult"
if ! TEST_RUNNER_SAFEQR_TEST_CAMERA_DENIED=1 xcodebuild "${COMMON[@]}" -configuration Debug \
    -destination "platform=iOS Simulator,id=$SAFEQR_SIMULATOR_ID" -parallel-testing-enabled NO \
    -only-testing:SafeQRUITests/CameraPermissionUITests -resultBundlePath "$SAFEQR_DENIED_RESULT" test \
    > "$SAFEQR_ARTIFACTS/tests-camera-denied.log" 2>&1; then
    cat "$SAFEQR_ARTIFACTS/tests-camera-denied.log"
    exit 1
fi
xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" grant camera jp.techguide.SafeQR
trap - EXIT
echo "カメラ権限拒否の個別テスト: 成功"
echo "lint・整形・Debug/Releaseビルド・iOSテスト: 成功"
