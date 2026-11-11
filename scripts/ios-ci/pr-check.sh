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
#
# UITESTS=1 (T3, ios-duo-gate.yml's `uitests` input) also runs the XCUITests
# (HappyPathUITests) against the live backend: it needs SUPABASE_URL,
# SUPABASE_ANON_KEY, UITEST_EMAIL and UITEST_PASSWORD in the environment, and
# writes uitests.log / uitests.xcresult.
set -euo pipefail

if [ "${UITESTS:-0}" = "1" ]; then
  for v in SUPABASE_URL SUPABASE_ANON_KEY UITEST_EMAIL UITEST_PASSWORD; do
    if [ -z "${!v:-}" ]; then
      echo "error: UITESTS=1 needs $v (add it as a repository secret)" >&2
      exit 1
    fi
  done
fi

out="$1"
mkdir -p "$out"
dd="${RUNNER_TEMP:-/tmp}/pr-dd"
packages="${RUNNER_TEMP:-/tmp}/SourcePackages"
start=$SECONDS

# --- Simulator -------------------------------------------------------------
runtimes="$(xcrun simctl list -j runtimes)"
# The newest iOS runtime with a matching device: iOS 27.1 ships only the Duo,
# so another DEVICE_FILTER (e.g. an iPad) lands on an older runtime.
pick="$(jq -r --arg want "${DEVICE_FILTER:-Duo}" '
  [.runtimes[] | select(.platform == "iOS" and .isAvailable)
   | {id: .identifier, version: .version,
      dev: ([.supportedDeviceTypes[]? | select(.name | test($want; "i")) | .identifier] | last)}]
  | sort_by(.version | split(".") | map(tonumber))
  | ([.[] | select(.dev != null)] | last) // last
  | "\(.id) \(.dev // "")"' <<<"$runtimes")"
runtime="${pick%% *}"
devtype="${pick#* }"
echo "runtime $runtime supports: $(jq -r --arg rt "$runtime" '.runtimes[] | select(.identifier == $rt) | [.supportedDeviceTypes[]?.name] | join(", ")' <<<"$runtimes")"
if [ -z "$devtype" ] && [ "${DEVICE_FILTER:-Duo}" != "Duo" ]; then
  echo "error: no simulator matches '$DEVICE_FILTER' on $runtime" | tee -a "$out/summary.txt"
  exit 1
fi
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
# unit tests never reach the backend. The XCUITests (UITESTS=1) launch the
# real app, so they get the real ones.
supabase_url="https://pr-check.invalid"
supabase_key="pr-check"
# Unsigned builds can't use the keychain, where Supabase keeps the session:
# sign-in succeeds but every later request fails with "Auth session missing".
# So the XCUITests build is ad-hoc signed, as Xcode's "Sign to Run Locally".
signing=(CODE_SIGNING_ALLOWED=NO)
if [ "${UITESTS:-0}" = "1" ]; then
  supabase_url="$SUPABASE_URL"
  supabase_key="$SUPABASE_ANON_KEY"
  signing=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=-" DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER=)
fi
common=(
  -project FinancialManagement.xcodeproj
  -scheme FinancialManagement
  -destination "id=$udid"
  -derivedDataPath "$dd"
  -clonedSourcePackagesDirPath "$packages"
  "${signing[@]}"
  "SUPABASE_URL=$supabase_url"
  "SUPABASE_ANON_KEY=$supabase_key"
)

# --- Build once ------------------------------------------------------------
# CI never debugs or indexes: build only the simulator's arch, skip the index
# store, and leave debug info in the object files instead of a dSYM.
fast=(ONLY_ACTIVE_ARCH=YES COMPILER_INDEX_STORE_ENABLE=NO DEBUG_INFORMATION_FORMAT=dwarf)
if ! xcodebuild build-for-testing "${common[@]}" "${fast[@]}" >"$out/build.log" 2>&1; then
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

# --- T3: XCUITests against the live backend --------------------------------
if [ "${UITESTS:-0}" = "1" ]; then
  ui_start=$SECONDS
  set +e
  TEST_RUNNER_UITEST_EMAIL="$UITEST_EMAIL" TEST_RUNNER_UITEST_PASSWORD="$UITEST_PASSWORD" \
    perl -e 'alarm shift; exec @ARGV' 900 \
    xcodebuild test-without-building "${common[@]}" \
    -only-testing:FinancialManagementUITests \
    -resultBundlePath "$out/uitests.xcresult" >"$out/uitests.log" 2>&1
  ui_status=$?
  set -e
  grep -E "Test Case .*(passed|failed|skipped)|error:" "$out/uitests.log" | head -50 || true
  # HappyPathUITests dumps the screen's accessibility tree when it times out.
  sed -n '/HAPPYPATH-SCREEN-BEGIN/,/HAPPYPATH-SCREEN-END/p' "$out/uitests.log" | head -400 || true
  {
    grep -E "Executed [0-9]+ tests?" "$out/uitests.log" | tail -1 || echo "no UI test summary"
    echo "uitests: $((SECONDS - ui_start))s (exit $ui_status)"
  } | tee -a "$out/summary.txt"
  [ "$ui_status" -eq 0 ] || status=$ui_status
fi

xcrun simctl delete "$udid" >/dev/null 2>&1 || true
exit "$status"
