# Financial Management iOS: iPhone Duo Implementation Plan

Status: Proposal · Date: 2026-10-29
Design: [`ios-iphone-duo-plan.md`](ios-iphone-duo-plan.md) · Mockups: [iPhone Duo Mockups canvas](https://claude.ai/artifact/Ptpqw6RjFrLEXJvSPMf2oS)

This plan breaks the Duo work into **22 small PRs** in 7 phases, with **4 checkpoints** ("gates") between them. It is shaped around one constraint: every PR waits on GitHub Actions macOS CI. So the expensive checks run at the gates, not on every PR. A runtime switch called the **adaptive kill switch** lets each PR merge straight to `main` without changing what users see.

---

## 1. CI strategy

### 1.1 Three test tiers

| Tier | Runs | What | Target time | Runner |
|---|---|---|---|---|
| **T1: PR check** | Every PR that touches `iOS/**` (skipped for drafts and doc-only changes) | One `build-for-testing`, then all **unit tests and layout tests** in the iPhone Duo simulator | **≤ 10 min** | `xcode-27` |
| **T2: Gate run** | At the 4 gates, via manual run or a `duo-gate` label | The probe workflow, extended to capture a **screenshot matrix of the real screens** (fixture data, every state), to compare against the canvas | ~20 min | `xcode-27` |
| **T3: Final pass** | Once, before switching Duo layouts on (D7.1) | `HappyPathUITests` against a live test account, plus a manual Device Hub or real-device pass of the inner display and postures | ~30 min plus manual | `xcode-27` / Mac |

Measured baselines from this repo:
- **TestFlight:** builds take 4–5 min.
- **Duo probe:** each run took 14–22 min, including discovery and the SDK scan, which T1 skips.
- **Billing:** the repo is public, so standard macOS minutes are free. The cost is **wait time, not money**.

### 1.2 Should all UI tests wait until the end?

**Yes for the XCUITests. No for layout checks.**

- **XCUITests wait until the end.** `HappyPathUITests` already skips on CI because it needs live credentials, and no PR workflow runs tests today. XCUITests are slow for reasons unrelated to Duo work: an app launch per test, logging in, and a real backend. Running them on every PR would roughly double T1 for little benefit. Run them once at T3 and at gate G4.
- **Layout checks don't wait.** The Duo work *is* layout work. If layout were checked only at the end, a wrong assumption made in PR 3 would surface after PRs 4–20 had built on it. Every one of those would then need rework, which costs far more CI time than checking as we go. So layout is verified on every PR, but **cheaply**: as hosted unit tests (D0.3) that render real screens in-process with fixture data and assert on frames. They need no app relaunch, no login and no network, and add seconds per test, not minutes.
- **Why gates still matter.** The hosted tests can't see what the system draws, such as Liquid Glass bars, the vertical rail and sheet chrome. The 4 gate runs cover that with real screenshots.

**Gate G2 finding: regular-width renders need an iPad.** On the Duo simulator the hosted scene is the 466 pt outer display, so T1 and T2 renders at inner sizes inherit its rail: an 84 pt inset, a floating vertical toolbar and a narrowed list. Column *positions* are still valid there; what's *inside* a column is not. Run the gate a second time with `device=iPad` (iOS 27.1 ships only the Duo, so this uses iOS 27.0) to judge regular-width content and the Summary inspector. `LayoutHarness.sceneFits` skips the in-column checks where they'd be wrong.

### 1.3 Other CI rules

1. **Build once, test twice.** Run `build-for-testing` once, then `test-without-building` against the same DerivedData. Never run a bare `xcodebuild test` after a separate build.
2. **Cache Swift packages.** Cache the `SourcePackages` checkout (Supabase and friends) on `Package.resolved`. Don't cache DerivedData, which is fragile across Xcode builds.
3. **Cancel superseded runs.** Use `concurrency: { group: ios-pr-${{ github.head_ref }}, cancel-in-progress: true }`, so pushing a fix cancels the stale run.
4. **Skip unnecessary runs.** Ignore paths `**/*.md` and `docs/**`, and skip draft PRs. Open a PR as a draft while iterating, then mark it ready to get T1.
5. **TestFlight stays as is.** It is async, takes 4–5 min after a merge to `main`, and never blocks a PR. It moves to the `xcode-27` runner in D0.1, because Duo code needs the iOS 27.1 SDK.
6. **Stack PRs and use merge commits** (as the `/done` workflow does). Start PR *n+1* from PR *n*'s branch while *n*'s CI runs, so nobody waits idle.

### 1.4 Adaptive kill switch: why chunks can merge to `main`

The app also targets iPad (`TARGETED_DEVICE_FAMILY = 1,2`), so every regular-width change reaches iPad testers as soon as it merges. The kill switch, `AdaptiveLayout.isEnabled` from D0.2, is applied once at the root:

```swift
.environment(\.horizontalSizeClass, AdaptiveLayout.isEnabled ? horizontalSizeClass : .compact)
```

- **Debug builds** turn it **on**. **Release and TestFlight** builds keep it **off** until D7.1.
- While it's off, every device renders today's compact layout. Half-finished split views never ship, and there's no long-lived integration branch to drift away from `main`, which the hourly autotask routine also targets.
- Every PR keeps the compact layout pixel-identical. The outer display *is* compact, and the probe confirmed it behaves like an iPhone. Compact regressions are caught by T1's existing unit tests plus the new compact layout assertions.

---

## 2. Task breakdown

Each task is one PR. Fields: **Scope** (files), **Done when** (merge criteria), **Tests** (what it adds to T1), **After** (dependencies). Sizes: S is under 150 changed lines, M is 150–400, L is 400+ (split it if it gets bigger).

### Phase 0: Foundation (blocks everything)

**D0.1 Toolchain and PR CI** · S
- **Scope:** new `.github/workflows/ios-pr-check.yml` (T1, with the rules in §1.3); `ios-testflight.yml` moves to `runs-on: xcode-27` with Xcode 27.1 selected; `fastlane/Fastfile` gets a `pr_check` lane, or the workflow calls `xcodebuild` directly. The deployment target **stays iOS 26.1**.
- **Done when:** T1 is green on a no-op PR in ≤ 10 min (record the time here); a TestFlight build from the `xcode-27` runner installs and launches on a current iPhone.
- **Tests:** the existing unit suite, now running on CI for the first time.
- **After:** nothing.

**D0.2 Kill switch and iOS 27.1 shims** · S
- **Scope:**
  - `App/AdaptiveLayout.swift`: the flag, read from an Info.plist key set per configuration.
  - `Views/Shared/DuoCompat.swift`: each iOS 27.1 API behind `#available(iOS 27.1, *)` with a fallback.
    - `.duoVisibilityPriority(_:)` wraps `ToolbarItem.visibilityPriority`.
    - `.duoSidebarTabPlacement()` wraps `.defaultTabBarPlacement(.sidebar)`.
    - A `FoldContext` environment value (`none / book(divisionX) / tent(divisionY)`) fed from `GeometryProxy.reservedRegions(kind: .division)` and `onHingeChange`.
- **Done when:** the app builds with no `#available` warnings; with the switch off, Release behaves exactly as it does today.
- **Tests:** `FoldContextTests` cover the region → context mapping, using a stubbed region list; `AdaptiveLayoutTests` cover the flag by configuration.
- **After:** D0.1.

**D0.3 Layout test harness and fixtures** · M
- **Scope:**
  - `FinancialManagementTests/Layout/LayoutHarness.swift` hosts any view in a window at a given size, with trait overrides and an injected `FoldContext`. This builds on `DuoProbeTests`. The standard sizes:

    | Size | Points | Size class |
    |---|---|---|
    | Outer portrait | 466×678, of which 382 pt is content | compact |
    | Inner landscape | 951×669 | regular |
    | Inner portrait | 669×951 | regular |
    | Split View, ½ width | ~475 wide | compact |

  - A debug-only `.layoutProbe("id")` modifier records frames.
  - `FixtureURLProtocol` (debug-only, modelled on the existing `MockURLProtocol`) serves canned JSON for each Supabase table plus a fake session, so real screens render with data. It is enabled by the `DUO_FIXTURES=1` environment variable.
  - Shared assertions: no interactive frame overlaps the safe-area rail or the fold division; the content width is at least 382 pt on compact.
- **Done when:** a sample test renders today's `DashboardView` with fixtures at all 4 sizes and attaches screenshots.
- **Tests:** the harness smoke test.
- **After:** D0.2.

### Phase 1: Root navigation

**D1.1 Tab model and selection persistence** · S
- **Scope:** an `AppTab` enum, a `@SceneStorage` selection, and a pure function mapping a tab between compact and regular width. For example, `.tags` on compact becomes `.more` with Tags pushed.
- **Done when:** the mapping covers every tab both ways.
- **Tests:** `AppTabMappingTests`, which are pure logic and run instantly.
- **After:** D0.2.

**D1.2 Root `TabView`** · M
- **Scope:** rewrite `ContentRootView` with the `Tab` API, tabs chosen by size class (§3.1 of the design doc; the probe showed `defaultVisibility(.hidden, for: .tabBar)` doesn't work), `.sidebarAdaptable` plus the sidebar shim, and Sign Out in the sidebar footer. `MoreView` is unchanged on compact.
- **Done when:** compact shows exactly 5 tabs; regular shows the sidebar with Management and Settings.
- **Tests:** layout tests at the 4 sizes (counting tabs and sidebar rows).
- **After:** D1.1, D0.3.

→ **Gate G1** (T2 run): check the root against the canvas overview and the Dashboard board.

### Phase 2: List → detail (D2.1–D2.6 can run in parallel after D2.0)

**D2.0 `SplitRoot` scaffold** · S
- **Scope:** a generic `NavigationSplitView` wrapper: list column, detail column, a `ContentUnavailableView` placeholder, and a selection ID in `@SceneStorage`. Compact collapses to a push, exactly as today.
- **Tests:** a compact push versus regular tiling layout test on a dummy list.
- **After:** D1.2.

Each feature PR below adopts `SplitRoot` and adds layout tests for compact (unchanged) and regular (tiled, with a placeholder when nothing is selected).

| Task | Screen | Size | Notes |
|---|---|---|---|
| **D2.1** | Accounts → `AccountDetailView` | S | The Edit text button stays horizontal |
| **D2.2** | Categories → filtered transactions | S | — |
| **D2.3** | Tags → filtered transactions | S | Grid with an **even** column count (replaces `.adaptive(minimum: 140)`) |
| **D2.4** | Fixed Expenses → linked transactions | S | The month navigator stays in the list column |
| **D2.5** | Budgets → drill-down | M | Selection is keyed by name and month; it clears on a month change |
| **D2.6** | Scheduled → `ScheduledFormView` in detail | M | Unsaved-changes dialog when switching selection (shares D3.1's helper; whichever lands first owns it) |

### Phase 3: Transactions (sequential)

**D3.1 Split and embedded edit form** · M
- **Scope:** `TransactionListView` moves into `SplitRoot`. The regular-width detail column is `TransactionFormView` in edit mode. A "Discard changes?" dialog appears when the selection changes while the form has unsaved edits. Compact keeps the sheet.
- **Tests:** layout tests, plus a view-model test that unsaved edits survive a size-class change.
- **After:** D2.0.

**D3.2 Summary inspector** · S
- **Scope:** `.inspector` on regular width; it falls back to a sheet on compact.
- **After:** D3.1.

**D3.3 Toolbar priority and Filters** · S
- **Scope:** Add `.duoVisibilityPriority(.high)` and Summary `.low`. Filters gets `.presentationSizing(.page)` and From/To dates in a `ViewThatFits`.
- **Tests:** a layout test that Add is visible at 382 pt.
- **After:** D3.1.

### Phase 4: Dashboard

**D4.1 Two-column reflow** · M
- **Scope:** a custom `Layout` with 2 columns on regular width: Verdict, Cashflow and Trend on the left; Accounts, Planned and Unplanned on the right. The amount column stays shared across both.
- **After:** D0.3.

**D4.2 Width fixes** · S
- **Scope:** `CashflowTrendCard`'s legend `minWidth: 240` moves into a `ViewThatFits`; `BudgetCard`'s max width stretches to its column; `CreateInstallmentSheet`'s allocation grid gets 2 columns.
- **Tests:** no clipping at a ⅓ Split View width (~317 pt).
- **After:** D4.1.

→ **Gate G2** (T2 run, after Phases 2–4): screenshot every screen board.

### Phase 5: Sheets and margins

**D5.1 Sheet sizing** · S
- **Scope:** `.presentationSizing(.form)` on F1 and F5–F10 (F2 and F4 use `.page`); category swatches in an even column count (6 on compact, 8 when form-sized); an audit that sheet draft state lives outside size-class branches.
- **Tests:** a sheet survives a trait flip with its draft intact.

**D5.2 Readable width** · S
- **Scope:** content margins derived from the width for Settings and More on regular width.
- **Tests:** the segmented control is ≤ 560 pt wide at 951 pt.

→ **Gate G3** (T2 run): the sheet and form boards.

### Phase 6: Fold awareness (iOS 27.1 only, optional for the first release)

**D6.1 Book posture** · M
- **Scope:** using `FoldContext.book`: the Dashboard column gutter sits on the division; Login and Splash place their content in one region.
- **Tests:** layout tests with an injected division asserting nothing interactive overlaps it.

**D6.2 Tent posture** · M
- **Scope:** `ArrangementView` with `.split` puts read-only glance content on top and controls plus the list at the bottom, for Dashboard, Transactions, Budgets and Fixed Expenses.
- **Tests:** injected tent division layout tests.

### Phase 7: Release

**D7.1 Switch it on** · S
- **Scope:**
  - Flip `AdaptiveLayout` on for Release.
  - Run **T3**: `HappyPathUITests` plus the manual Device Hub or device pass of I-L, I-P, I-B, I-T and I-S.
  - Fill in the inner-display rows of design doc §1.3.
- **Done when:** gate **G4** is green, T3 passes, and the TestFlight build is checked on an iPhone (and an iPad, if available).

---

## 3. Order and parallelism

```
D0.1 → D0.2 → D0.3 ─┬→ D1.1 → D1.2 ─G1─→ D2.0 ─┬→ D2.1 … D2.6 (parallel) ─┐
                    │                          └→ D3.1 → D3.2, D3.3 ──────┼─G2─→ D5.1, D5.2 ─G3─→ D6.1, D6.2 ─G4─→ D7.1
                    └→ D4.1 → D4.2 ───────────────────────────────────────┘
```

The critical path is **D0.1 → D0.2 → D0.3 → D1.1 → D1.2 → D2.0 → D3.1 → D3.3 → G2 → D5.x → G3 → D6.x → G4 → D7.1**. That is 11 PRs one after another, plus the 4 gates. The other 11 PRs (D2.1–D2.6, D3.2, D4.x and the second PR of D5 and D6) run alongside it.

The work could also be fed to the local autotask routine: one GitHub issue per task, labelled `auto`. Every task above has its own Scope, Done when and Tests, so each can be an issue as written.

## 4. Why this plan is efficient

1. **Expensive checks are batched.** About 22 PRs × a T1 of about 10 min, plus 4 gate runs × about 20 min, comes to roughly **300 runner-minutes**. Running the full screenshot or probe run on every PR would be about 22 × 20, or **440+ minutes**, and each PR would wait twice as long.
2. **Checking runs where it's cheapest.** Layout bugs are caught on every PR by in-process tests that cost seconds, not by slow UI automation. That finds rework early, which is where it's cheapest.
3. **Merging to `main` behind a switch.** There's no integration branch to keep rebasing, and no merge-day conflict with the autotask PRs. TestFlight keeps working with Duo layouts invisible until D7.1.
4. **Foundation first.** Shims (D0.2) and the harness (D0.3) land once, so the next 19 PRs never re-solve `#available`, fixtures or how to measure a frame.
5. **Small, independent PRs.** Most are S or M and touch one screen. CI failures point at one change; reviews take minutes; Phase 2 runs in parallel.
6. **Iterate on drafts.** Superseded runs are cancelled, docs-only changes skip CI, and drafts don't run CI. Only the version you intend to merge spends runner time.
7. **Unreachable checks are left to the end deliberately.** The inner display, postures and Split View can't be driven from CI, as the probe showed. Fold logic is still tested on every PR through the injected `FoldContext`. Only the final, human visual check of real postures waits for T3.
