#!/usr/bin/env bash
# T1 PR check (docs/ios-iphone-duo-implementation-plan.md §1.1): build once,
# then run the unit + layout tests against the same DerivedData on an iPhone
# Duo simulator (falls back to the newest iPhone if the Duo type is missing).
#
# Usage: pr-check.sh <output-dir>   (run from iOS/FinancialManagement)
# Writes build.log, test.log, tests.xcresult and summary.txt to <output-dir>.
#
# GATE=1 (the T2 gate run, ios-duo-gate.yml) also runs DuoProbeTests and
# exports every screenshot attachment to <output-dir>/screens/<Test>/.
set -euo pipefail

out="$1"
mkdir -p "$out"
dd="${RUNNER_TEMP:-/tmp}/pr-dd"
packages="${RUNNER_TEMP:-/tmp}/SourcePackages"
start=$SECONDS

# --- Simulator -------------------------------------------------------------
runtime="$(xcrun simctl list -j runtimes |
  jq -r '[.runtimes[] | select(.platform == "iOS" and .isAvailable)] | sort_by(.version) | last | .identifier')"
devtype="$(xcrun simctl list -j devicetypes |
  jq -r --arg want "${DEVICE_FILTER:-Duo}" \
    '.devicetypes[] | select(.name | test($want; "i")) | .identifier' | head -1)"
if [ -z "$devtype" ]; then
  devtype="$(xcrun simctl list -j devicetypes |
    jq -r '[.devicetypes[] | select(.productFamily == "iPhone")] | last | .identifier')"
  echo "warning: no iPhone Duo device type; using $devtype" | tee -a "$out/summary.txt"
fi
udid="$(xcrun simctl create PRCheck "$devtype" "$runtime")"
# Boot in the background while the build runs.
xcrun simctl boot "$udid" &
echo "simulator: $devtype on $runtime ($udid)" | tee -a "$out/summary.txt"

# Config/*.xcconfig is git-ignored, so supply placeholder Supabase settings;
# unit tests never reach the backend.
common=(
  -project FinancialManagement.xcodeproj
  -scheme FinancialManagement
  -destination "id=$udid"
  -derivedDataPath "$dd"
  -clonedSourcePackagesDirPath "$packages"
  CODE_SIGNING_ALLOWED=NO
  "SUPABASE_URL=https://pr-check.invalid"
  SUPABASE_ANON_KEY=pr-check
)

# --- Build once ------------------------------------------------------------
if ! xcodebuild build-for-testing "${common[@]}" >"$out/build.log" 2>&1; then
  grep -E "error:" "$out/build.log" | sort -u | head -50
  echo "build-for-testing FAILED after $((SECONDS - start))s" | tee -a "$out/summary.txt"
  exit 1
fi
build_s=$((SECONDS - start))
echo "build-for-testing: ${build_s}s" | tee -a "$out/summary.txt"

# --- Test twice (unit + layout; XCUITests wait for gate G4 / T3) -----------
wait # simulator boot
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true

gate_env=()
if [ "${GATE:-0}" = "1" ]; then
  # TEST_RUNNER_-prefixed variables reach the test process without the prefix.
  gate_env=(TEST_RUNNER_DUO_PROBE=1 "TEST_RUNNER_DUO_OUT=$out/probe")
fi

status=0
# A hung test is killed after 3 min (with a spindump in the xcresult) and
# reported as failed, instead of stalling the job to its 30-min timeout. Each
# test case is echoed as it runs, so the job log names a stalled one. A
# main-thread hang escapes those allowances, so the whole step is also capped
# at 15 min (perl's alarm: macOS has no `timeout`); the suite takes ~2.
set +e
env ${gate_env[@]+"${gate_env[@]}"} perl -e 'alarm shift; exec @ARGV' 900 \
  xcodebuild test-without-building "${common[@]}" \
  -only-testing:FinancialManagementTests \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 180 \
  -maximum-test-execution-time-allowance 300 \
  -resultBundlePath "$out/tests.xcresult" 2>&1 \
  | tee "$out/test.log" | grep --line-buffered -E "^Test Case .*(started|passed|failed)"
status=${PIPESTATUS[0]}
set -e

grep -E "Test Case .*failed|error:" "$out/test.log" | head -100 || true
{
  grep -E "Executed [0-9]+ tests?" "$out/test.log" | tail -1 || echo "no test summary"
  echo "test-without-building: $((SECONDS - start - build_s))s (exit $status)"
  echo "total: $((SECONDS - start))s"
} | tee -a "$out/summary.txt"

if [ "${GATE:-0}" = "1" ]; then
  raw="$out/attachments"
  xcrun xcresulttool export attachments --path "$out/tests.xcresult" --output-path "$raw" \
    >"$out/attachments.log" 2>&1 || true
  # Name each file after its attachment, grouped by test class:
  # screens/RootTabLayoutTests/root-inner-landscape.png
  if [ -f "$raw/manifest.json" ]; then
    jq -r '.[] | .testIdentifier as $t | .attachments[] |
        [($t | split("/")[0]), .exportedFileName, .suggestedHumanReadableName] | @tsv' \
      "$raw/manifest.json" |
      while IFS=$'\t' read -r test file name; do
        [[ "$file" == *.png ]] || continue
        mkdir -p "$out/screens/$test"
        clean="$(echo "$name" | sed -E 's/_[0-9]+_[0-9A-F-]{36}//')"
        cp "$raw/$file" "$out/screens/$test/$clean"
      done
  fi
  echo "screenshots: $(find "$out/screens" -name '*.png' 2>/dev/null | wc -l | tr -d ' ')" | tee -a "$out/summary.txt"
fi

xcrun simctl delete "$udid" >/dev/null 2>&1 || true
exit "$status"
