#!/usr/bin/env bash
# Builds the app + unit tests for the booted DuoProbe simulator and runs
# DuoProbeTests once per display phase:
#   outer — as booted (device closed: the app runs on the outer display)
#   inner — outer screen powered off, inner powered on (device opened)
# Each phase records layout metrics + screenshots from inside the app, and
# full-display simulator screenshots (with system chrome) every few seconds.
#
# Usage: run-probe.sh <output-dir>   (expects $UDID; run from iOS/FinancialManagement)
set -uo pipefail

out="$1"
dd="${RUNNER_TEMP:-/tmp}/duo-dd"
outer=1 # screen IDs from `simctl io enumerate`: LCD (outer) and LCD-1 (inner)
inner=3

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

mkdir -p "$out"
xcodebuild build-for-testing "${common[@]}" >"$out/build.log" 2>&1 ||
  { grep -E "error:" "$out/build.log"; echo "build-for-testing failed; see build.log"; exit 1; }

screen() { # screen <display> <power on|off>
  xcrun simctl io "$UDID" screenConfig --display="$1" power "$2" 2>&1
}

run_phase() { # run_phase <name>
  local name="$1" dir="$out/$1"
  mkdir -p "$dir/live"
  xcrun simctl io "$UDID" enumerate >"$dir/io-enumerate.txt" 2>&1

  ( while true; do
      t="$(date +%H%M%S)"
      xcrun simctl io "$UDID" screenshot --display="$outer" "$dir/live/$t-outer.png" >/dev/null 2>&1
      xcrun simctl io "$UDID" screenshot --display="$inner" "$dir/live/$t-inner.png" >/dev/null 2>&1
      sleep 4
    done ) &
  local shooter=$!

  # TEST_RUNNER_-prefixed variables reach the test process without the prefix.
  TEST_RUNNER_DUO_PROBE=1 TEST_RUNNER_DUO_OUT="$dir" \
    xcodebuild test-without-building "${common[@]}" \
    -only-testing:FinancialManagementTests/DuoProbeTests \
    -resultBundlePath "$dir/probe.xcresult" >"$dir/test.log" 2>&1
  echo "$name tests exit $?"
  grep -E "Test Case .*(passed|failed|skipped)|error:" "$dir/test.log"

  kill "$shooter" 2>/dev/null
  xcrun xcresulttool export attachments --path "$dir/probe.xcresult" \
    --output-path "$dir/attachments" >"$dir/attachments.log" 2>&1 || true
}

run_phase outer

# The inner display can't be reached from the command line: simctl has no
# fold/posture control (Device Hub's open/close buttons are GUI-only), and
# powering the outer screen off with `screenConfig power off` crashes
# SpringBoard rather than "opening" the device. Set DUO_TRY_INNER=1 to retry
# that experiment on a newer image.
if [ "${DUO_TRY_INNER:-0}" = "1" ]; then
  { screen "$outer" off; screen "$inner" on; } >"$out/inner-switch.txt"
  sleep 8
  run_phase inner
  { screen "$outer" on; screen "$inner" on; } >>"$out/inner-switch.txt"
fi
exit 0
