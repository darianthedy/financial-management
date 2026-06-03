# Financial Management — Technical Plan: GitHub Pages Hosting

> Covers: private GitHub repository setup, GitHub Pages configuration, automated deployment via GitHub Actions, environment variable handling, and PWA setup for mobile home-screen install.

---

## 1. Overview

The web application is a **static SPA** (Vite + React) that talks directly to Supabase from the browser. There is no server-side code. GitHub Pages serves the built static files (HTML, JS, CSS) over HTTPS at no cost — even from a private repository.

### 1.1 Architecture

```
┌──────────────────────────────────────────────────────┐
│  Your devices (laptop browser, phone browser / PWA)  │
└──────────────────┬───────────────────────────────────┘
                   │  HTTPS
                   ▼
┌──────────────────────────────────────────────────────┐
│  GitHub Pages (static hosting, free)                 │
│  Serves: index.html + JS bundles + CSS + assets      │
│  URL: https://<username>.github.io/<repo-name>/      │
└──────────────────────────────────────────────────────┘
                   │
                   │  The JS running in YOUR browser
                   │  makes API calls directly to:
                   ▼
┌──────────────────────────────────────────────────────┐
│  Supabase (cloud)                                    │
│  Auth, Database, Realtime                            │
│  Protected by RLS — only authenticated users access  │
└──────────────────────────────────────────────────────┘
```

### 1.2 Cost

| Service | Cost |
|---|---|
| GitHub Pages (private repo) | Free |
| GitHub Actions (build & deploy) | Free (2,000 min/month on free plan) |
| Supabase | Free tier (already in use) |
| **Total** | **$0/month** |

### 1.3 Security

The GitHub Pages URL is publicly accessible, but this is safe because:

- The served files are just UI code — no secrets, no server logic.
- The Supabase **anon key** is public by design; it only grants access permitted by Row Level Security (RLS) policies.
- All data access requires authentication via `supabase.auth.signInWithPassword()`.
- RLS policies on every table ensure only the authenticated user can read/write their own data.

---

## 2. Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Git | >= 2.x | Version control |
| GitHub account | Free plan | Repository + Pages hosting |
| GitHub CLI (`gh`) | >= 2.x | Optional, for repo creation from terminal |
| Node.js | >= 18 | Build toolchain |
| pnpm | latest | Package manager |

---

## 3. Repository Setup

### 3.1 Create a Private Repository

**Option A — GitHub CLI:**

```bash
gh repo create financial-management-web --private --clone
cd financial-management-web
```

**Option B — GitHub Web UI:**

1. Go to https://github.com/new
2. Repository name: `financial-management-web`
3. Visibility: **Private**
4. Do not initialize with README (the Vite scaffold will create one)
5. Click "Create repository"

Then link the local project:

```bash
cd financial-management-web
git remote add origin git@github.com:<username>/financial-management-web.git
git push -u origin main
```

### 3.2 Enable GitHub Pages

1. Go to the repository on GitHub → **Settings** → **Pages**
2. Under **Source**, select **GitHub Actions**
3. No further configuration needed — the workflow in section 4 handles deployment

---

## 4. GitHub Actions Workflow

Create the workflow file at `.github/workflows/deploy.yml`:

```yaml
name: Deploy to GitHub Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: latest

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm build
        env:
          VITE_SUPABASE_URL: ${{ secrets.VITE_SUPABASE_URL }}
          VITE_SUPABASE_ANON_KEY: ${{ secrets.VITE_SUPABASE_ANON_KEY }}

      - uses: actions/upload-pages-artifact@v3
        with:
          path: dist

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - id: deployment
        uses: actions/deploy-pages@v4
```

### 4.1 Add Repository Secrets

The Supabase URL and anon key are injected at **build time** (Vite replaces `import.meta.env.VITE_*` with literal values during the build). They must be set as GitHub repository secrets:

1. Go to the repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add:

| Secret name | Value |
|---|---|
| `VITE_SUPABASE_URL` | `https://<project-ref>.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | Your Supabase project's anon/public key |

These values are baked into the JS bundle at build time. This is safe — the anon key is designed to be public, and RLS protects the data.

---

## 5. Vite Configuration for GitHub Pages

GitHub Pages serves the site at a subpath: `https://<username>.github.io/<repo-name>/`. Vite needs to know this base path so asset URLs resolve correctly.

In `vite.config.ts`:

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: "/financial-management-web/",
  resolve: {
    alias: {
      "@": "/src",
    },
  },
});
```

### 5.1 SPA Routing — 404 Fallback

GitHub Pages doesn't support client-side routing natively — refreshing on `/dashboard` returns a 404. The standard workaround is to copy `index.html` as `404.html` so GitHub Pages serves the SPA shell for any path.

Add to `package.json` scripts:

```json
{
  "scripts": {
    "build": "vite build && cp dist/index.html dist/404.html"
  }
}
```

Alternatively, use `react-router`'s `HashRouter` instead of `BrowserRouter` to avoid this entirely (routes become `/#/dashboard` instead of `/dashboard`). `HashRouter` is simpler but produces less clean URLs.

---

## 6. Environment Variables

### 6.1 Local Development (`.env.local`)

```
VITE_SUPABASE_URL=http://127.0.0.1:54321
VITE_SUPABASE_ANON_KEY=<local-anon-key>
```

### 6.2 Production (GitHub Actions secrets)

Set via repository secrets as described in section 4.1.

### 6.3 Usage in Code

```typescript
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
```

### 6.4 `.gitignore`

Ensure `.env.local` is not committed:

```
.env.local
.env.*.local
```

---

## 7. PWA Setup (Mobile Home-Screen Install)

Adding PWA support lets you "install" the app on Android and iOS home screens so it launches like a native app — fullscreen, with its own icon.

### 7.1 Install the Vite PWA Plugin

```bash
pnpm add -D vite-plugin-pwa
```

### 7.2 Update `vite.config.ts`

```typescript
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      manifest: {
        name: "Financial Management",
        short_name: "FinMan",
        description: "Personal financial management app",
        theme_color: "#0f172a",
        background_color: "#0f172a",
        display: "standalone",
        scope: "/financial-management-web/",
        start_url: "/financial-management-web/",
        icons: [
          {
            src: "pwa-192x192.png",
            sizes: "192x192",
            type: "image/png",
          },
          {
            src: "pwa-512x512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "any maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,ico,png,svg,woff2}"],
      },
    }),
  ],
  base: "/financial-management-web/",
  resolve: {
    alias: {
      "@": "/src",
    },
  },
});
```

### 7.3 Add App Icons

Place icon files in the `public/` folder:

```
public/
├── pwa-192x192.png
├── pwa-512x512.png
└── favicon.ico
```

### 7.4 Installing on Mobile

**Android (Chrome):**
1. Open `https://<username>.github.io/financial-management-web/`
2. Chrome shows an "Add to Home Screen" banner automatically, or tap Menu → "Install app"

**iOS (Safari):**
1. Open the URL in Safari
2. Tap Share → "Add to Home Screen"

---

## 8. Deployment Workflow

### 8.1 Day-to-Day Development

```bash
# Start local Supabase (in the supabase project directory)
supabase start

# Start Vite dev server
pnpm dev
# → http://localhost:5173
```

### 8.2 Deploy to Production

No manual deployment step is needed. Pushing to `main` triggers the GitHub Actions workflow automatically:

```bash
git add .
git commit -m "description of changes"
git push origin main
```

The workflow builds the app, injects production Supabase credentials, and deploys to GitHub Pages. The site is typically live within 1–2 minutes.

### 8.3 Verify Deployment

After the workflow completes:

1. Check workflow status: repository → **Actions** tab
2. Visit `https://<username>.github.io/financial-management-web/`
3. Confirm the login page loads and you can sign in

---

## 9. Custom Domain (Optional)

If you prefer a clean URL like `finance.yourdomain.com` instead of `<username>.github.io/<repo-name>`:

1. Go to repository → **Settings** → **Pages** → **Custom domain**
2. Enter your domain (e.g., `finance.yourdomain.com`)
3. Add a **CNAME** record with your DNS provider:

| Type | Name | Value |
|---|---|---|
| CNAME | `finance` | `<username>.github.io` |

4. Enable **Enforce HTTPS**
5. Update `base` in `vite.config.ts` to `"/"` (no subpath needed with a custom domain)
6. Update `scope` and `start_url` in the PWA manifest to `"/"`

---

## 10. Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Blank page after deploy | `base` in `vite.config.ts` doesn't match the repo name | Set `base: "/<repo-name>/"` |
| 404 on page refresh | GitHub Pages doesn't know about client-side routes | Ensure `cp dist/index.html dist/404.html` runs in the build script, or use `HashRouter` |
| "Add to Home Screen" not showing | Missing manifest, icons, or HTTPS | Check manifest in DevTools → Application tab; ensure HTTPS |
| Supabase auth not persisting | Third-party cookie blocking | Supabase JS stores tokens in `localStorage` by default, which works fine; ensure you're not clearing site data |
| Build fails in GitHub Actions | Missing secrets | Verify `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are set in repository secrets |
