# iOS TestFlight setup — progress & handoff

> Notes from the Claude session that set up the no-Mac iOS build pipeline.
> Pull the `claude/ios-compile-no-mac-q7nloj` branch on your PC to continue.

## Goal
Build, sign, and install the iOS app **without owning a Mac**, as cheaply as
possible. Chosen approach: **GitHub Actions (macOS runner) → fastlane match
signing → TestFlight → install via the TestFlight app on iPhone.** Cost is $0
beyond the $99/yr Apple Developer account, within GitHub's free macOS minutes.

## ✅ Done (committed to this branch)
- `.github/workflows/ios-testflight.yml` — CI job (manual run + push to `main`)
- `iOS/FinancialManagement/fastlane/Fastfile` — `beta` (build+sign+upload) and
  `build_check` lanes
- `iOS/FinancialManagement/fastlane/Appfile`, `Matchfile`, `Gemfile`
- `iOS/FinancialManagement/.../xcshareddata/xcschemes/FinancialManagement.xcscheme`
  — shared scheme so CI can find the target (was missing)
- `iOS/README-TestFlight.md` — full setup walkthrough
- `.gitignore` — ignores iOS build artifacts

## ⏳ To do (manual, all browser-based — no Mac needed)
These are done in App Store Connect / GitHub, not in code.

1. **Pick a unique App Store name.** "Financial Management" is already taken
   (App Store names are globally unique). Candidates discussed: **Dthedy
   Finance** (guaranteed unique), **Finora**, **Ledgerly**, **SpendWise**.
   - This only affects the *store listing*, NOT the bundle ID or the on-device
     app name.

2. **Register the Bundle ID** `com.dthedy.FinancialManagement` at
   developer.apple.com → Identifiers → + → App IDs → App → Explicit.
   (The New App screen's Bundle ID dropdown is empty until this exists. It MUST
   match the Xcode project bundle ID exactly.)

3. **Create the app record** in App Store Connect (New App) using that bundle ID.
   - SKU: any unique internal code, e.g. `financial-management`.
   - User Access: Full Access.

4. **Create an App Store Connect API key** (Users and Access → Integrations →
   Team Keys → +). Use **Admin** for the first build (match needs it to create
   the signing cert), can downgrade to App Manager later. Download the `.p8`
   ONCE. Capture Key ID, Issuer ID, and `base64` of the `.p8`.

5. **Create a private repo for match certs** (e.g. `darianthedy/ios-certificates`)
   + a PAT with read/write to it. Choose a `MATCH_PASSWORD` passphrase.

6. **Add GitHub secrets** to this repo (Settings → Secrets and variables →
   Actions): `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT`, `MATCH_GIT_URL`,
   `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION`.
   (Exact commands for each are in `iOS/README-TestFlight.md`.)

7. **Run it:** Actions tab → iOS TestFlight → Run workflow. After the first
   success, set repo Variable `MATCH_READONLY = true`.

8. **Install on iPhone:** add yourself as an Internal Tester in TestFlight, then
   install via the TestFlight app.

## Resume on your PC
```bash
git fetch origin
git checkout claude/ios-compile-no-mac-q7nloj
git pull
```
Then open the repo in Claude Code (or your editor) and continue from the "To do"
list above. The detailed reference is `iOS/README-TestFlight.md`.

## Open question (was being decided when the session paused)
- Whether to add a lightweight **PR build-check workflow** (compiles on
  simulator, no signing) that calls the existing `build_check` lane. Not yet
  added.
