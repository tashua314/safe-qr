#!/usr/bin/env bash
set -euo pipefail
SAFEQR_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SAFEQR_ROOT"
source "$SAFEQR_ROOT/scripts/tool-config.sh"

for tool in swiftlint swiftformat xcodebuild python3; do
    command -v "$tool" >/dev/null || { echo "$tool が必要です。" >&2; exit 1; }
done
safeqr_require_check_tools
SAFEQR_ARTIFACTS="${SAFEQR_ARTIFACTS:-$SAFEQR_ROOT/.artifacts}"
mkdir -p "$SAFEQR_ARTIFACTS"
SAFEQR_TIMES="$SAFEQR_ARTIFACTS/phase-times.log"
: > "$SAFEQR_TIMES"
SAFEQR_STARTED_AT="$(date +%s)"
SAFEQR_BOOT_PID=""
SAFEQR_RESTORE_CAMERA=0

record_time() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" | tee -a "$SAFEQR_TIMES"
}
write_summary() {
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
        {
            echo '### iOS validation timings'
            echo '| Phase | Seconds | Result |'
            echo '|---|---:|---|'
            while IFS=$'\t' read -r phase seconds result; do
                printf '| %s | %s | %s |\n' "$phase" "$seconds" "$result"
            done < "$SAFEQR_TIMES"
            echo 'Simulator readiness wait is the remaining wait after overlapping boot with builds.'
        } >> "$GITHUB_STEP_SUMMARY"
    fi
}
cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n "$SAFEQR_BOOT_PID" ]]; then
        kill "$SAFEQR_BOOT_PID" 2>/dev/null || true
        wait "$SAFEQR_BOOT_PID" 2>/dev/null || true
    fi
    if [[ "$SAFEQR_RESTORE_CAMERA" == 1 ]]; then
        if ! xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" grant camera jp.techguide.SafeQR; then
            echo '検証専用Simulatorのカメラ権限復元に失敗しました。' >&2
            status=1
        fi
    fi
    record_time Total "$(( $(date +%s) - SAFEQR_STARTED_AT ))" "$status"
    write_summary
    exit "$status"
}
trap cleanup EXIT

run_phase() {
    local name="$1" logfile="$2" started status
    shift 2
    started="$(date +%s)"
    echo "$name: 開始"
    if "$@" > "$logfile" 2>&1; then status=0; else status=$?; fi
    record_time "$name" "$(( $(date +%s) - started ))" "$status"
    if [[ "$status" != 0 ]]; then cat "$logfile"; return "$status"; fi
}

xcodebuild -version
run_phase Portable "$SAFEQR_ARTIFACTS/portable.log" scripts/check-portable.sh
run_phase Lint "$SAFEQR_ARTIFACTS/lint.log" scripts/lint.sh
plutil -lint SafeQR/SafeQR.xcodeproj/project.pbxproj SafeQR/SafeQR/Info.plist
SAFEQR_SIMULATOR_ID="${SAFEQR_SIMULATOR_ID:-$(python3 scripts/simulator_destination.py)}"
SAFEQR_DERIVED_DATA="$SAFEQR_ARTIFACTS/DerivedData"
COMMON=(-project SafeQR/SafeQR.xcodeproj -scheme SafeQR -derivedDataPath "$SAFEQR_DERIVED_DATA" CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES)
DESTINATION="platform=iOS Simulator,id=$SAFEQR_SIMULATOR_ID"

# 専用端末の起動を先に開始し、Debug/Releaseビルドと準備時間を重ねる。
xcrun simctl bootstatus "$SAFEQR_SIMULATOR_ID" -b > "$SAFEQR_ARTIFACTS/simulator-boot.log" 2>&1 &
SAFEQR_BOOT_PID=$!
run_phase Debug-build-for-testing "$SAFEQR_ARTIFACTS/Debug-build.log" xcodebuild "${COMMON[@]}" \
    -configuration Debug -destination "$DESTINATION" build-for-testing
run_phase Release-build "$SAFEQR_ARTIFACTS/Release-build.log" xcodebuild "${COMMON[@]}" \
    -configuration Release -destination 'generic/platform=iOS Simulator' build

SAFEQR_WAIT_STARTED="$(date +%s)"
if ! wait "$SAFEQR_BOOT_PID"; then
    SAFEQR_BOOT_PID=""
    cat "$SAFEQR_ARTIFACTS/simulator-boot.log"
    exit 1
fi
SAFEQR_BOOT_PID=""
record_time Simulator-readiness-wait "$(( $(date +%s) - SAFEQR_WAIT_STARTED ))" 0
xcrun simctl install "$SAFEQR_SIMULATOR_ID" "$SAFEQR_DERIVED_DATA/Build/Products/Debug-iphonesimulator/SafeQR.app"
xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" grant camera jp.techguide.SafeQR

# 同じDebug成果物で通常と拒否状態を検証する。test-without-buildingでも全ケースを維持する。
SAFEQR_RESULT="$SAFEQR_ARTIFACTS/Tests-$(date +%s)-$$.xcresult"
run_phase Tests "$SAFEQR_ARTIFACTS/tests.log" xcodebuild "${COMMON[@]}" -configuration Debug \
    -destination "$DESTINATION" -parallel-testing-enabled NO -resultBundlePath "$SAFEQR_RESULT" test-without-building
SAFEQR_RESTORE_CAMERA=1
xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" revoke camera jp.techguide.SafeQR
SAFEQR_DENIED_RESULT="$SAFEQR_ARTIFACTS/CameraDenied-$(date +%s)-$$.xcresult"
run_phase Camera-denied "$SAFEQR_ARTIFACTS/tests-camera-denied.log" env TEST_RUNNER_SAFEQR_TEST_CAMERA_DENIED=1 \
    xcodebuild "${COMMON[@]}" -configuration Debug -destination "$DESTINATION" -parallel-testing-enabled NO \
    -only-testing:SafeQRUITests/CameraPermissionUITests -resultBundlePath "$SAFEQR_DENIED_RESULT" test-without-building
xcrun simctl privacy "$SAFEQR_SIMULATOR_ID" grant camera jp.techguide.SafeQR
SAFEQR_RESTORE_CAMERA=0
echo 'lint・整形・Debug/Releaseビルド・iOS全テスト・カメラ拒否の個別テスト: 成功'
