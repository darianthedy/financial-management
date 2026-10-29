#!/usr/bin/env bash
# Pulls the real declarations of the iPhone Duo APIs the Duo plan relies on
# out of the iOS simulator SDK's Swift interfaces and UIKit headers, so the
# plan's API names can be checked against what actually shipped.
#
# Usage: sdk-apis.sh <output-file>
set -uo pipefail

out="$1"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
symbols='ReservedRegion|ArrangementView|arrangementViewStyle|overlayArrangementZIndex|onHingeChange|HingeInteraction|toolbarVerticalEdge|toolbarVerticalBehavior|VerticalBarBehavior|VisibilityPriority|ToolbarOverflowMenu|defaultTabBarPlacement|TabBarPlacement|effectiveGeometry|ConcentricRectangle|UICornerConfiguration|sceneAccessory|prominentTabIdentifier|WindowSceneActivation'

{
  echo "SDK: $sdk"
  xcodebuild -version
  echo
  find "$sdk/System/Library/Frameworks" -maxdepth 6 \
    \( -name "*.swiftinterface" -path "*arm64*" -o -name "*.h" \) \
    \( -path "*SwiftUI*" -o -path "*UIKit*" \) 2>/dev/null |
    while read -r f; do
      hits="$(grep -n -E "$symbols" "$f" 2>/dev/null | grep -v '^\s*//' | head -300)"
      [ -n "$hits" ] || continue
      echo "=================================================================="
      echo "== ${f#"$sdk"/}"
      echo "$hits"
    done
} >"$out" 2>&1

echo "Wrote $(wc -l <"$out") lines to $out"
