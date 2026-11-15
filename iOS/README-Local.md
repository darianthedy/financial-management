# Building the iOS app on the Mac Mini (local, default since 2026-11-14)

We now have a **Mac Mini** (Apple Silicon, macOS 27, **Xcode 27.2**, iOS 27.2 simulators
including **iPhone Duo**). Everything that used to run on GitHub Actions macOS runners —
PR checks, Duo gate/probe runs, TestFlight builds — runs **here** instead.

**Don't** use `gh workflow run ios-*`, don't wait on the `ios-pr-check` / `ios-duo-*` /
`ios-testflight` workflows, and don't add Codemagic or other cloud builders.
`README-TestFlight.md` and `TestFlight-Setup-Progress.md` describe the retired CI
pipeline; they remain the reference for the App Store Connect key and the match repo.

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
cd iOS/FinancialManagement
bundle exec fastlane beta      # match (read-only) → archive → upload
```

Run it from whatever branch you're testing — this replaces
`gh workflow run ios-testflight.yml --ref <branch>`.
