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

  # Availability of the key SwiftUI entry points (the @available lines above
  # each declaration).
  echo
  echo "=================================================================="
  echo "== SwiftUI availability context"
  find "$sdk/System/Library/Frameworks" -maxdepth 6 -name "arm64-apple-ios-simulator.swiftinterface" -path "*SwiftUI*" |
    while read -r f; do
      grep -n -B4 -E "func (defaultTabBarPlacement|visibilityPriority|onHingeChange|reservedRegions|arrangementViewStyle)|struct (ArrangementView|ReservedRegion|ToolbarOverflowMenu)<?|var toolbarVerticalEdge" "$f" |
        grep -E "available|func |struct |var " | cut -c1-240
    done

  # Full member lists of the fold types, so the public geometry accessors
  # (frame / isActive / hinge angle) can be confirmed. FoldContext reads
  # ReservedRegion's frame by reflection until these are known.
  echo
  echo "=================================================================="
  echo "== Fold type members"
  find "$sdk/System/Library/Frameworks" -maxdepth 6 -name "arm64-apple-ios-simulator.swiftinterface" \
    \( -path "*SwiftUI*" -o -path "*UIKit*" \) |
    while read -r f; do
      awk '/(struct|enum|class) (ReservedRegion|DeviceHingeContext|UIHingeInteraction)[ :<]/,/^}/' "$f" |
        grep -v '^\s*//' | cut -c1-240 | head -200
    done
} >"$out" 2>&1

echo "Wrote $(wc -l <"$out") lines to $out"
