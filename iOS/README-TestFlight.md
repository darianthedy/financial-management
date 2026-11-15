# Shipping the iOS app to TestFlight (from the Mac Mini)

The app is built, signed (fastlane match) and uploaded to TestFlight **locally
on the Mac Mini**. This replaced the old `ios-testflight.yml` GitHub workflow.

```bash
scripts/ios-release/testflight.sh   # = bundle exec fastlane beta, then restores the pbxproj
```

The build appears in **App Store Connect → TestFlight** a few minutes after the
upload, once Apple finishes processing. Build numbers are `YYYYMMDDHHMM`
timestamps (the Fastfile's fallback when `BUILD_NUMBER` is unset), always
higher than the old CI run numbers.

## Configuration (outside git)

- **Signing:** shared by every app on this Mac. One Apple Distribution cert,
  one App Store Connect API key, one match password, all described in
  `~/.config/ios-signing/README.md`. The Fastfile loads
  `~/.config/ios-signing/signing.env` by itself, and the match password comes
  from the login keychain. Profile: `ios-signing AppStore com.dthedy.FinancialManagement`.
- **Supabase:** `~/.config/financial-management/testflight.env` holds
  `SUPABASE_URL` / `SUPABASE_ANON_KEY`, which are baked into the build. Without
  them the app builds but **crashes on launch** unwrapping an empty URL.

| File | Purpose |
|---|---|
| `scripts/ios-release/testflight.sh` | Runs `fastlane beta` and cleans up |
| `iOS/FinancialManagement/fastlane/Fastfile` | Build + sign + upload lanes |
| `iOS/FinancialManagement/fastlane/Appfile` | App identifier / team |
| `iOS/FinancialManagement/fastlane/Matchfile` | Where signing assets are stored |
| `iOS/FinancialManagement/Gemfile` | Pins fastlane |

## Install on your iPhone
1. Install **TestFlight** from the App Store.
2. In App Store Connect → TestFlight, add yourself as an **Internal Tester**
   (internal builds need no App Review).
3. Open the invite / the TestFlight app → install. Later uploads show up as
   updates automatically.

## Gotchas
- `match` is always read-only here. Never run `fastlane match nuke`: it revokes
  the distribution cert every app shares.
- The lane edits the app target's signing settings (`update_code_signing_settings`)
  before archiving; the script restores `project.pbxproj` when it exits, and
  refuses to start if that file already has uncommitted changes.
- The committed shared scheme
  (`FinancialManagement.xcodeproj/xcshareddata/xcschemes/FinancialManagement.xcscheme`)
  is what lets fastlane find the `FinancialManagement` scheme — don't delete it.
