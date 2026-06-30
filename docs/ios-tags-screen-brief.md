# iOS Tags Screen — Implementation Brief
Source: `web/src/pages/tags.tsx`, `web/src/components/tags/tag-form.tsx`, `web/src/lib/hooks/use-tags.ts`

## What you are building
A native SwiftUI `TagsListView` in the iOS app that implements feature parity with the web Tags page, adapted to iOS design standards. Reuse the shared token/theme layer from `Views/Theme/AppTheme.swift` and the existing form/list patterns in iOS (`AccountListView`, `AccountFormSheet`, `BudgetListView`) — do not introduce a new theme system.

## Stack
- SwiftUI + NavigationStack
- Supabase client from `SupabaseService` pattern
- Shared tokens: `Color.appPrimary`, `Color.appCard`, `AppTheme.cornerRadius`, etc.

## Data
- Model: `models/Tag.swift` (already present)
- Table: `tags`
- Columns used by web: `id`, `user_id`, `name`, `created_at`
- Auth: current session `client.auth.session.user.id` -> `user_id`
- Ordering: alphabetical by `name` (case-insensitive / localized)
- Real-time: subscribe to postgres changes on `public.tags` and refetch list on `INSERT`, `UPDATE`, `DELETE`

## Required behaviors (from `web/src/lib/hooks/use-tags.ts`)
1) `fetchTags()` returns `tags`, `isLoading`, and path to refetch.
2) `createTag(name:)` inserts with `user_id` + `name`
3) `updateTag(id:name:)` updates `name`
4) `deleteTag(id:)` hard-deletes; FKs are cascade-safe (deleting a tag removes its `transaction_tags` mapping, transactions keep their other tags).

## Screen flow (from `web/src/pages/tags.tsx`)
- Top area: navigation title `Tags` + primary create button.
- Loading: show loading indicator when first fetch is in flight.
- Empty state when there are no tags:
  - Title: `No tags yet`
  - Description: align with web: `Create tags to label transactions across categories.`
  - Primary action: `Add tag`
- Tag list when populated:
  - Two columns on regular-width (home screen), collapse to one column on compact size classes.
  - Each tag is a tappable card:
    - Leading tag glyph + tag name
    - Trailing context menu:
      - `Edit` -> opens edit sheet
      - `Delete` -> confirms deletion, then deletes + refetches

## iOS-native adaptations
- Do **not** use Material card styling verbatim. Use `.appCardSurface()` (defined in `Views/Theme/AppTheme.swift`) so the app stays visually consistent.
- Prefer `LazyVGrid` for the tag cards with adaptive layout across device/size class.
- Keep delete behavior safe: present confirmation alert with exact copy from web: `Delete "NAME"? It will be removed from any transactions using it.`
- Tapping a tag drills into the transactions list filtered by that tag. Mirror how `BudgetDrilldown` builds filters in `BudgetListView`: create a small value type (e.g. `TagDrilldown`) that holds the tag id/name and produces the `TransactionFilters` needed by `TransactionListView` once that initial-filter API exists; then navigate via `.navigationDestination`. If `TransactionListView` does not yet accept initial filters, implement that plumbing first before wiring the tag tap.
- For edits/creates, build a native sheet form that matches `TagForm` semantics (name-only, create vs. edit) but uses iOS Form styling. Reuse the same validation/error messaging conventions as `AccountFormSheet` if they exist.
- Real-time subscriptions must clean up on `onDisappear`, mirroring existing list views.

## UI spec proposal
- Navigation bar title: `Tags`
- Primary action: plus icon button (`.primaryAction`) in toolbar
- Loading: full-screen `ProgressView`
- Empty state: `EmptyStateView` with:
  - title: `No tags yet`
  - message: `Create tags to label transactions across categories.`
  - primary button: `Add tag`
- List:
  - Section header: none
  - Grid spacing: `12` pt
  - Card shape: `.appCardSurface()`
  ## Screen context
`TagsListView` is a standard push destination in the app’s `NavigationStack`, like `BudgetListView` and `AccountListView`. It owns its title, toolbar, and sheet state. It should not embed its own `NavigationStack` unless specific drill-down destinations require it (e.g. the tag-filtered `TransactionListView` push).

## Auth / session edge case
If `client.auth.session.user.id` is nil, treat the user as unauthenticated for tag CRUD: show the empty state and ensure create/edit/delete actions are blocked or implicitly short-circuit rather than crashing. Mirror how other iOS list views handle missing auth.

## List cards
Each tag is a tappable card using `.appCardSurface()`:
- Leading tag SF Symbol: `.tag.fill`
- Name label: `.headline`
- Tap -> navigate to transactions list filtered by that tag; do not open the editor here.
- Context menu (`.contextMenu`):
  - Edit -> open editor sheet
  - Delete -> confirm alert, then delete + refetch

## Form sheet requirements (mirror `TagForm`)
- Title: `New tag` / `Edit tag`
- Single `TextField("Name", text:)` with no autocorrection and text capitalization `.never`
- Save action:
  - Create: `name.trimmingCharacters(in: .whitespaces).isEmpty` -> do nothing / show error if empty
  - Edit: update only if new name differs
  - Show saving indicator
- Error message: on failure, show alert restoring `error.localizedDescription`
- Validation: max 50 chars

## Examples to mirror
- `BudgetListView` for real-time list loading and empty states
- `AccountFormSheet` for form/validation/discard-on-cancel conventions
- `TagPicker.swift` for existing tag search/create behavior (be careful to keep this independent of tags list)

## Files to create
- `Views/Tags/TagsListView.swift`
- `Views/Tags/TagFormSheet.swift`

## Do NOT
- Do not modify unrelated files (Accounts, Budgets, etc.)
- Do not duplicate namespace definitions (all ContentView constants already shared, verify them first)
- Do not add a new Colors page beyond existing `AppTheme.swift`
