# iOS root: back to tabs, Music-style list | detail

Status: **agreed** (Discord review, 2026-11-06). Integration branch `ios/tab-root`. Phase branches `ios/tab-root-pN`. `main` is untouched until the owner says otherwise.

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
- Rotation and fold swap the container. The existing continuity rebuilds the screen:
  - `@SceneStorage` selection restore (`SplitSelectionRule`)
  - `foldSafeSheet` / `hostsFoldSafeSheets` above the `TabView`
  - `TransactionEditorDrafts`, `FoldKeptModels` and the root-owned `TransactionListViewModel`

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
