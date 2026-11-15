# 01 — List | detail split follows orientation, not size class

- **Severity:** High
- **Where:** inner display (portrait vs landscape); `FinancialManagement/Views/Shared/SplitRoot.swift:101-119`, `:356-358`
- **Reviewed:** 2026-11-15, iPhone Duo simulator (iOS 27.2), `DUO_FIXTURES=1`

## What

`SplitRootContainer` tiles list | detail only when the window is regular width
**and wider than tall** (`SplitColumns.tiles(_:regular:)`). The inner display in
portrait is regular width and about 669 pt wide, enough for both columns
(`minimumListWidth + minimumDetailWidth` = 660 pt), but it falls back to a
pushing `NavigationStack`.

Every rotation therefore swaps the whole tab hierarchy (`ListDetailSplit` ⇄
`SplitPushStack`). The selection-restore machinery in this file
(`SplitSelectionStore`, `SplitPushStack`, `@SceneStorage` restores,
`hasShownDetail`, "fold diagnostics" workarounds) exists to paper over that
swap. Finding 07 (stray search button) is a likely symptom.

Screenshots: `screenshots/L-open-tx-inner.png` (landscape, tiled) vs
`screenshots/L-port-tx-inner.png` (portrait, single column).

## Why

- `designing-for-iphone-duo.md › Device poses`: "use size classes so your app
  adapts naturally as it changes size … Don't reinvent your app when it resizes."
- `designing-for-iphone-duo.md › Best practices`: "show an additional level of
  hierarchy on the larger inner display if it makes sense for your content."
- swiftui-pro `resizability.md › Choosing layouts`: base layout on size class,
  not orientation; when size classes select different hierarchies, state inside
  the replaced hierarchy resets.

## Fix

Use one `NavigationSplitView` per list tab, always, and let SwiftUI collapse it
to a stack in compact width (the outer display, narrow Split View):

```swift
// Before (SplitRootContainer.body)
GeometryReader { geo in
    if SplitColumns.tiles(geo.size, regular: horizontalSizeClass == .regular) {
        ListDetailSplit { content }
    } else if let pushedDetail, horizontalSizeClass == .regular {
        SplitPushStack(restoring: currentStoredID, detail: pushedDetail, onBack: forget) { content }
    } else if let pushedDetail { ... } else { NavigationStack { content } }
}

// After
NavigationSplitView(columnVisibility: $visibility) {
    content   // list, selection bound to a @SceneStorage-backed id
} detail: {
    NavigationStack { detailForSelection }
}
.navigationSplitViewStyle(.balanced)
```

Keep `SplitColumns.listWidth(for:fold:)` for the fold-aligned column width.
Then delete `SplitPushStack`, `SplitSelectionStore` and the restore branches
that only exist because of the hierarchy swap.

If the portrait inner display should still show one column on purpose (the
Music pattern), make that decision with `horizontalSizeClass` plus the
available width only, not `width > height`. Keep the same `NavigationSplitView`
and set `columnVisibility`, so rotation never swaps the view tree.

## Verify

Inner display: rotate portrait ⇄ landscape with a transaction selected and the
search field filled. Selection, search text and toolbar must survive without
any restore code. Fold onto the outer display: list shown, detail one push away.
