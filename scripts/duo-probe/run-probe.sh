#!/usr/bin/env bash
# Builds the app + unit tests for the booted DuoProbe simulator and runs
# DuoProbeTests, which records layout metrics and screenshots per probe screen.
# While the tests run, full-display simulator screenshots (with system chrome:
# status bar, Dynamic Island, vertical bars) are captured every few seconds.
#
# Usage: run-probe.sh <output-dir>   (expects $UDID; run from iOS/FinancialManagement)
set -uo pipefail

out="$1"
mkdir -p "$out/probe" "$out/live"
dd="${RUNNER_TEMP:-/tmp}/duo-dd"

# Config/*.xcconfig is git-ignored, so supply placeholder Supabase settings;
# the probe never talks to the backend, it only needs the app to launch.
common=(
  -project FinancialManagement.xcodeproj
  -scheme FinancialManagement
  -destination "id=$UDID"
  -derivedDataPath "$dd"
  CODE_SIGNING_ALLOWED=NO
  "SUPABASE_URL=https://duo-probe.invalid"
  SUPABASE_ANON_KEY=duo-probe
)

xcodebuild build-for-testing "${common[@]}" 2>&1 | tee "$out/build.log" | grep -E "error:|warning: .*Duo|BUILD" || true
[ "${PIPESTATUS[0]}" -eq 0 ] || { echo "build-for-testing failed; see build.log"; exit 1; }

( while true; do
    xcrun simctl io "$UDID" screenshot "$out/live/$(date +%H%M%S).png" >/dev/null 2>&1
    sleep 3
  done ) &
shooter=$!

# TEST_RUNNER_-prefixed variables reach the test process without the prefix.
TEST_RUNNER_DUO_PROBE=1 TEST_RUNNER_DUO_OUT="$out/probe" \
  xcodebuild test-without-building "${common[@]}" \
  -only-testing:FinancialManagementTests/DuoProbeTests \
  -resultBundlePath "$out/probe.xcresult" 2>&1 | tee "$out/test.log" | grep -E "DUOPROBE|Test Case|error:" || true
status=${PIPESTATUS[0]}

kill "$shooter" 2>/dev/null

xcrun xcresulttool export attachments --path "$out/probe.xcresult" \
  --output-path "$out/attachments" >"$out/attachments.log" 2>&1 || true

exit "$status"
