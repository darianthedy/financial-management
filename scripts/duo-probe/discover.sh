#!/usr/bin/env bash
# Records what the toolchain knows about iPhone Duo: runtimes, the device-type
# profile (screen specs), simctl commands, and any fold/hinge/display controls.
# Creates and boots a DuoProbe simulator and exports its UDID to $GITHUB_ENV.
#
# Usage: discover.sh <output-dir>
# Discovery is best-effort: a failing probe command is logged, not fatal.
set -uo pipefail

out="$1"
mkdir -p "$out"

run() { # run <file> <cmd...>: capture stdout+stderr of a command into a file
  local file="$1"; shift
  { echo "\$ $*"; "$@"; echo "[exit $?]"; } >"$out/$file" 2>&1
}

run xcode.txt xcodebuild -version
run sdks.txt xcodebuild -showsdks

if ! xcrun simctl list runtimes | grep -q "iOS 27.1"; then
  echo "iOS 27.1 runtime missing; downloading"
  xcodebuild -downloadPlatform iOS >"$out/download-platform.txt" 2>&1
fi
run runtimes.txt xcrun simctl list runtimes
xcrun simctl list -j runtimes >"$out/runtimes.json"
run devicetypes.txt xcrun simctl list devicetypes

# Every simctl verb, plus full help for the verbs most likely to control
# displays or posture.
run simctl-help.txt xcrun simctl help
for verb in io ui boot create status_bar spawn; do
  run "simctl-help-$verb.txt" xcrun simctl help "$verb"
done

# Device-type profile: holds the screen size/scale the simulator renders at
# and any second-display or fold metadata.
mkdir -p "$out/profiles"
dev_dir="$(xcode-select -p)"
find /Library/Developer/CoreSimulator "$dev_dir" -maxdepth 12 -iname "*Duo*.simdevicetype" 2>/dev/null |
  sort -u | while read -r bundle; do
    name="$(basename "$bundle" .simdevicetype | tr ' ' '_')"
    find "$bundle" -name "*.plist" | while read -r plist; do
      plutil -convert xml1 -o "$out/profiles/$name-$(basename "$plist")" "$plist" 2>/dev/null
    done
    find "$bundle" -type f >"$out/profiles/$name-files.txt"
  done

# Hunt for fold / hinge / posture / display controls in simctl and the
# simulator frameworks; these name the commands Device Hub drives.
pattern='fold|hinge|posture|unfold|duo|reservedregion|arrangement|innerdisplay|outerdisplay|coverdisplay'
for bin in \
  "$(xcrun -f simctl)" \
  /Library/Developer/PrivateFrameworks/CoreSimulator.framework/Versions/A/CoreSimulator \
  "$dev_dir/Applications/Simulator.app/Contents/MacOS/Simulator"; do
  [ -f "$bin" ] || continue
  strings "$bin" | grep -i -E "$pattern" | sort -u | head -600 >"$out/strings-$(basename "$bin").txt"
done

# Create and boot the probe device.
runtime="$(xcrun simctl list -j runtimes | jq -r '.runtimes[] | select(.version | startswith("27.1")) | .identifier' | head -1)"
devtype="$(xcrun simctl list -j devicetypes | jq -r '.devicetypes[] | select(.name | test("Duo"; "i")) | .identifier' | head -1)"
echo "runtime=$runtime devtype=$devtype" | tee "$out/device.txt"
udid="$(xcrun simctl create DuoProbe "$devtype" "$runtime")"
echo "udid=$udid" | tee -a "$out/device.txt"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >>"$out/device.txt" 2>&1

run io-enumerate.txt xcrun simctl io "$udid" enumerate
run device-json.txt xcrun simctl list -j devices "$udid"
xcrun simctl io "$udid" screenshot "$out/home.png" >/dev/null 2>&1
for display in internal external inner outer cover; do
  xcrun simctl io "$udid" screenshot --display="$display" "$out/home-$display.png" \
    >"$out/screenshot-$display.txt" 2>&1
done

[ -n "${GITHUB_ENV:-}" ] && echo "UDID=$udid" >>"$GITHUB_ENV"
exit 0
