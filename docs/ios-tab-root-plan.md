# iOS root: back to tabs, Music-style list | detail

Status: **done**, device-tested and merged to `main` (2026-11-06). Built on the integration branch `ios/tab-root` (phase PRs #303 and #305–#317).

## Why

The Notes-style root, a sidebar with sections | list | detail on one `NavigationSplitView`, needed `RootSplitBehavior`. That type walks the window's view controllers to reach the `UISplitViewController` SwiftUI creates, then sets `.displace` on it. Owning the split in UIKit would have needed two splits for Dashboard and Settings, which have no list, plus hand-written continuity between two sidebars. Apple's own pattern for an app that mixes list and non-list sections is a **tab bar**: Music, TV and Podcasts. On the iPhone Duo, Music shows:

- **Inner landscape:** the tab bar on the vertical bar; list | detail side by side (Library › Artists | artist).
- **Inner portrait:** the tab bar at the bottom; list → detail **pushes**.
- **Outer display:** the tab bar on the vertical bar; list → detail pushes.

## Design

**Root** (`ContentRootView`): a `TabView` with the `.tabBarOnly` style and the same five tabs on every display:

| Tab | Content |
|---|---|
| Dashboard | `NavigationStack { DashboardView() }` |
| Accounts | `SplitRootContainer { AccountListView() }` |
| Transactions | `SplitRootContainer { TransactionListView(…) }` |
| Budgets | `SplitRootContainer { BudgetListView() }` |
| More | `NavigationStack(path:)`. A list of Tags, Categories, Fixed Expenses, Scheduled, Settings and Sign Out. Each pushes its screen, and that screen pushes its detail. |

- No sidebar and no `sidebarAdaptable`, so there's no tab ⇄ sidebar mapping. The tabs are the same at every size, so a fold keeps the tab with no mapping at all.
- The selected tab and More's pushed screen are kept in `@SceneStorage`. The old `"root.tab"` values (`AppSection` raw values) are migrated: a management section opens More with that screen pushed.

**List | detail** (`SplitRootContainer`) tiles only when **all** of these hold:
- regular width
- landscape (`width > height`)
- both columns fit (`SplitColumns.tiles`, 660 pt)

Otherwise it's a plain `NavigationStack` and `.splitDetail` pushes.

- Tiled, it's a two-column `NavigationSplitView` with both columns always visible: the `.balanced` style, `.toolbar(removing: .sidebarToggle)`, and `.doubleColumn` visibility.
- Everything it uses is public, documented SwiftUI.
- The width class and orientation pick the container, so a fold or a rotation swaps it and re-creates the list. The selection lives in a root-owned `SplitSelectionStore` for the run, with `@SceneStorage` used only for relaunch.

**Fold and rotation behaviour** (final, after on-device fold diagnostics):
- **Outer display:** every tab opens on its list. The selection is kept. It's forgotten only when the user goes back from a detail they opened there. An unsaved Transactions draft is kept too: tapping that transaction reopens it in the editor, and tapping another asks "Discard changes?".
- **Inner display, landscape:** the selection comes back in the detail column (`SplitDetailHost`, the split's `detail` driven by the selection).
- **Inner display, portrait (rotation):** the tab's stack (`SplitPushStack`) starts with the selection on its `NavigationStack(path:)` and builds the detail at its root from the stored ID.
- **Why the outer display doesn't restore a push:** a fold moves the app to the other screen while it re-creates the stack. When that move landed before the new stack's first push, the push was cancelled, at random, and no documented API orders the two. Rotation stays on one screen and has no such race. If it ever shows one, portrait opens on the list too.
- **Sheets and drafts:** `foldSafeSheet` / `hostsFoldSafeSheets` above the `TabView`; `TransactionEditorDrafts`, `FoldKeptModels` and the root-owned `TransactionListViewModel`, which loads once and refreshes on pull.
- **Lists:** every tab's list | detail split is 50/50, with the fold setting the edge in book posture.
- **Not done:** `TrailingBarClearance` was removed. The swipe-action gap on the outer display is back, pending a documented fix. Transactions' date headers use the system background, which removes the book-posture strip.

**Tags, Categories, Fixed Expenses and Scheduled** sit inside More, so they push their detail (the filtered transaction list or the editor) on every display. A "Show in Transactions" action that switches tabs with a filter is deferred as a possible later feature.

**Removed:**
- `RootSplitBehavior`: the window walk
- `RootColumns`, the sections sidebar and the displace/overlay logic
- `ListDetailSplit`'s portrait overlay
- `LayoutHarness.labels` / `tabTitles`: test hierarchy walks, replaced by XCUITests

## Phases (auto mode: builds first, UI tests in parallel)

1. **p1 Root.** Tab root, Music-style `SplitRootContainer`, More stack, `@SceneStorage` migration, and deletes. Layout and unit tests updated where they encoded the sidebar or portrait overlay. TestFlight build from the branch.
2. **p2 UI tests** (in parallel, XCUITest only):
   - the tabs on each display
   - More → Tags → a tag's transactions
   - list | detail in landscape and push in portrait
   - selection kept across rotation

   `DuoProbeTests` gets rewritten on XCUITest queries. `HappyPathUITests` moves from sections to tabs.
3. **p3 Cleanup.** Dead code (`duoSidebarTabPlacement`, `AppSection` sidebar-only parts), the Duo plan docs, and a hierarchy-walk search across `iOS/`.

Device checklist for each build:
- inner landscape, portrait, book and tent
- outer display
- rotate and fold mid-edit, and with a sheet open
- More → Tags → tag → back
