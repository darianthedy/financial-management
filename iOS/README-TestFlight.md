# Building & installing the iOS app without a Mac

You have an Apple Developer account but no Mac. This pipeline builds the app on
a **GitHub-hosted macOS runner**, signs it, and uploads it to **TestFlight**.
You then install it on your iPhone from the **TestFlight** app. Everything is
done from the browser — no Mac, and **$0 beyond the $99/yr developer account**
as long as you stay within GitHub's free macOS minutes.

```
git push / manual run  →  GitHub Actions (macOS)  →  fastlane match (sign)
                       →  build IPA  →  upload to App Store Connect  →  TestFlight  →  your iPhone
```

Files involved:

| File | Purpose |
|---|---|
| `.github/workflows/ios-testflight.yml` | The CI job (runs `fastlane beta`) |
| `iOS/FinancialManagement/fastlane/Fastfile` | Build + sign + upload lanes |
| `iOS/FinancialManagement/fastlane/Appfile` | App identifier / team |
| `iOS/FinancialManagement/fastlane/Matchfile` | Where signing assets are stored |
| `iOS/FinancialManagement/Gemfile` | Pins fastlane |

---

## One-time setup

### 1. Create the app record in App Store Connect
At [App Store Connect → Apps](https://appstoreconnect.apple.com) → **+** → **New App**,
using bundle ID `com.dthedy.FinancialManagement`. (TestFlight needs the app to exist.)

### 2. Create an App Store Connect API key
Users and Access → **Integrations** → **App Store Connect API** → **+**.
Give it **Admin** access (needed so `match` can create the distribution
certificate/profile on the first run; you can lower it to **App Manager**
afterwards). Download the `.p8` file — **you only get one chance**.

Note the **Issuer ID** (top of the page) and the **Key ID**.

Base64-encode the key for the secret. `-w0` keeps it on a **single line** —
GNU `base64` (Linux/WSL) wraps at 76 columns by default, and a wrapped
multi-line secret breaks the build:
```bash
base64 -w0 AuthKey_XXXXXXXXXX.p8   # macOS: base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

### 3. Create a private repo to hold signing assets
`match` stores the (encrypted) certificate and provisioning profile in a
separate **private** git repo. Create an empty one, e.g.
`darianthedy/ios-certificates`.

Create a **Personal Access Token** (classic, `repo` scope, or a fine-grained
token with read/write to just that repo) so CI can read/write it. Then:
```bash
echo -n "darianthedy:ghp_YOUR_PAT" | base64 -w0
```
That value is `MATCH_GIT_BASIC_AUTHORIZATION`. The `-w0` (no line wrapping) and
`echo -n` (no trailing newline) matter: a multi-line value puts a newline in the
git `Authorization` header and `match` fails to clone with *"A libcurl function
was given a bad argument."* On macOS use `… | base64 | tr -d '\n'` instead.

Pick any strong passphrase for `MATCH_PASSWORD` — it encrypts the contents of
that repo. Save it somewhere safe; you'll need the same value forever.

### 4. Add the GitHub secrets
In **this** repo → Settings → Secrets and variables → **Actions** → New secret:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the API Key ID |
| `ASC_ISSUER_ID` | the API Issuer ID |
| `ASC_KEY_CONTENT` | base64 of the `.p8` (step 2) |
| `MATCH_GIT_URL` | `https://github.com/darianthedy/ios-certificates.git` |
| `MATCH_PASSWORD` | the passphrase you chose (step 3) |
| `MATCH_GIT_BASIC_AUTHORIZATION` | base64 of `user:PAT` (step 3) |
| `SUPABASE_URL` | your Supabase project URL, e.g. `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | your Supabase anon/public key |

`SUPABASE_URL` / `SUPABASE_ANON_KEY` are baked into the build (the local
`Config/Prod.xcconfig` that defines them is git-ignored, so CI must supply them).
Without them the app builds but **crashes on launch** unwrapping an empty URL.

---

## Run it

**Actions** tab → **iOS TestFlight** → **Run workflow**. (It also runs
automatically on pushes to `main` that touch `iOS/**`.)

- **First run only:** before running, add a repo **Variable**
  `MATCH_CREATE_CERTS = true` (Settings → Secrets and variables → Actions →
  **Variables**). On CI, fastlane's `setup_ci` forces match into read-only mode
  so builds never mint duplicate signing assets — this variable opts the first
  run out so `match` can create and store the distribution certificate + App
  Store provisioning profile in the certs repo.
- **After it succeeds, delete the `MATCH_CREATE_CERTS` variable.** Every later
  run then stays read-only and just reuses the stored cert/profile.
- When the job finishes, the build appears in **App Store Connect → TestFlight**
  after a few minutes of Apple-side processing.

## Install on your iPhone
1. Install **TestFlight** from the App Store.
2. In App Store Connect → TestFlight, add yourself as an **Internal Tester**
   (uses your Apple Account email — internal builds need no App Review).
3. Open the invite / the TestFlight app → install. Future CI uploads show up as
   updates automatically.

---

## Cost notes
- macOS runners bill at **10× minutes**. Private repos include 2,000 free
  minutes/month → ~**200 macOS minutes/month free**; a build here is ~10–15 min,
  so roughly ~12 builds/month at no cost. Public repos get free macOS minutes.
- If you'd rather not track minutes, **Codemagic**'s free tier (500 min/month)
  runs the same `Fastfile` — only the CI yaml changes.

## Gotchas
- **Xcode version**: the deployment target is iOS **26.1**, so the runner needs
  Xcode 26 — that's why the workflow uses `macos-26`. If GitHub renames the
  image, update `runs-on`.
- **Capabilities**: the target enables app-group / sandbox settings. If a build
  fails with a provisioning/entitlements mismatch, enable the matching
  capability on the App ID in the Developer portal, delete the profile from the
  certs repo, and re-run with `MATCH_READONLY` unset so `match` regenerates it.
- The committed shared scheme
  (`FinancialManagement.xcodeproj/xcshareddata/xcschemes/FinancialManagement.xcscheme`)
  is what lets CI find the `FinancialManagement` scheme — don't delete it.
