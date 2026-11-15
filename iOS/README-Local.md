# Building the iOS app on the Mac Mini (local, default since 2026-11-14)

We now have a **Mac Mini** (Apple Silicon, macOS 27, **Xcode 27.2**, iOS 27.2 simulators
including **iPhone Duo**). PR checks and TestFlight builds run **here**; their
`ios-pr-check`, `ios-duo-probe` and `ios-testflight` workflows have been deleted.
Don't add Codemagic or other cloud builders.

The one iOS workflow left on GitHub is **`ios-duo-gate.yml`**: the nightly T3 run
(full suite + HappyPathUITests against the live backend), also runnable from the
Actions tab or with the `duo-gate` PR label.

`TestFlight-Setup-Progress.md` describes the retired CI pipeline (history only).

## One-time setup

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer   # still points at CommandLineTools
xcodebuild -runFirstLaunch
cd iOS/FinancialManagement
bundle install            # fastlane, pinned by the Gemfile
```

- `Config/Dev.xcconfig` / `Config/Prod.xcconfig` (git-ignored, Tech Plan §2) hold
  `SUPABASE_URL` / `SUPABASE_ANON_KEY` for local runs — create them if missing.
- Signing is the shared setup for all apps on this Mac (since 2026-11-15):
  `~/.config/ios-signing/README.md`. The Fastfile loads `~/.config/ios-signing/signing.env`
  (API key, match repo, password from the macOS keychain) and `SUPABASE_URL` /
  `SUPABASE_ANON_KEY` from `~/.config/financial-management/testflight.env` by itself,
  so nothing needs exporting. Profile: `ios-signing AppStore com.dthedy.FinancialManagement`.

## Everyday loop (replaces the T1 PR check)

The **pre-push hook** (`.githooks/pre-push`) runs this automatically when a push
touches `iOS/` or `scripts/ios-ci/` (not `.md`) and aborts the push on failure.
Enable it once per clone with `git config core.hooksPath .githooks`; skip a push with
`git push --no-verify`. Tests run pinned to en/US, so the Mac's region doesn't matter.

```bash
cd iOS/FinancialManagement
../../scripts/ios-ci/pr-check.sh /tmp/fm-check   # build + unit/layout tests on the iPhone Duo simulator
# or: bundle exec fastlane build_check            # compile only
```

Gate runs (T2) — the same script with `GATE=1`; T3 adds `UITESTS=1` plus
`UITEST_EMAIL` / `UITEST_PASSWORD`. Device Hub / Xcode can open, fold and rotate the Duo
simulator interactively now, which CI could not.

## TestFlight

```bash
scripts/ios-release/testflight.sh   # fastlane beta: match (read-only) → archive → upload
```

Run it from whatever branch you're testing — this replaces
`gh workflow run ios-testflight.yml --ref <branch>`. The script also restores the
`project.pbxproj` signing edit afterwards. Details: `README-TestFlight.md`.
