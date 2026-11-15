#!/usr/bin/env bash
# Build, sign and upload the iOS app to TestFlight from this Mac
# (replaces the old ios-testflight.yml GitHub workflow).
#
# Usage: scripts/ios-release/testflight.sh
#
# This is `bundle exec fastlane beta` plus cleanup. The Fastfile loads its own
# config: signing from ~/.config/ios-signing/signing.env (shared by all apps,
# see ~/.config/ios-signing/README.md) and SUPABASE_URL / SUPABASE_ANON_KEY
# from ~/.config/financial-management/testflight.env.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)/iOS/FinancialManagement"

# The lane switches the app target to manual signing by editing the pbxproj;
# undo that afterwards. Refuse to start if the pbxproj already has local edits,
# so restoring it can't throw away your work.
pbxproj=FinancialManagement.xcodeproj/project.pbxproj
if ! git diff --quiet HEAD -- "$pbxproj"; then
  echo "error: $pbxproj has uncommitted changes; commit or stash them first" >&2
  exit 1
fi
trap 'git checkout -- "$pbxproj"' EXIT

export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
bundle install --quiet
bundle exec fastlane beta
