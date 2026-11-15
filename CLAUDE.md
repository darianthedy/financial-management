# financial-management — notes for Claude

## iOS builds are local (since 2026-11-14)
- We work on a **Mac Mini** with Xcode 27.2 and an iPhone Duo simulator. Build, test,
  screenshot and upload the iOS app **here** — procedure: `iOS/README-Local.md`.
- Do **not** use GitHub Actions macOS runners or any other external build service:
  no `gh workflow run ios-*`, no waiting on `ios-pr-check` / `ios-duo-*` / `ios-testflight`.
  "CI green" in older plans/prompts now means the local equivalent
  (`scripts/ios-ci/pr-check.sh`, `bundle exec fastlane beta`) passed.
- Docs that say "no Mac" / "every PR waits on macOS CI" (`iOS/README-TestFlight.md`,
  `iOS/TestFlight-Setup-Progress.md`, `docs/ios-iphone-duo-implementation-plan.md`,
  `iOS/uikit-root-split-rewrite-prompt.md`) describe the old setup.
- The web app's GitHub Pages deploy is unaffected.
