# 08 — More list straddles the fold when partially open

- **Severity:** Medium
- **Where:** inner display, landscape, partially open; `FinancialManagement/Views/Shared/ContentRootView.swift:148-163` (`MoreView`, `.readableContentMargins()`)

## What

`MoreView` centers a readable-width grouped list in the window. When the device
is partially folded (book posture), the fold runs vertically through the middle
of every row: the labels sit left of the hinge, the chevrons right of it.
Dashboard (`DashboardColumns`) and the tiled splits (`SplitColumns.listWidth`)
already move their gutter onto the fold; More doesn't.

Screenshot: `screenshots/L-half-more-inner.png` (fold at the horizontal center).

## Why

- `designing-for-iphone-duo.md › Reserved regions`: "Adapt your layout when the
  device folds … Use the ReservedRegion API to keep important elements clear of
  the center if the system doesn't move them automatically."
- Same page: "Avoid extreme layout changes as people fold the device", so
  prefer a small shift over a re-layout.

## Fix

In book posture, constrain the list to one region instead of centering it
across the hinge. The app already publishes the fold as `\.foldContext`:

```swift
// MoreView
@Environment(\.foldContext) private var fold

List { ... }
    .readableContentMargins()
    .contentMargins(.horizontal, foldMargins, for: .scrollContent)

private var foldMargins: EdgeInsets {
    guard case .book(let x) = fold else { return EdgeInsets() }
    // Keep rows in the leading region, a gutter clear of the hinge.
    return EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: windowWidth - x + 16)
}
```

Alternatively, drop the readable-width centering on the inner display so rows
span full width. The hinge then crosses empty row space, not between a label
and its chevron.

Apply the same check to Settings, Tags, Categories, Fixed Expenses and Scheduled.

## Verify

Inner landscape, Partially Open, in Device Hub: no row text or chevron within
~16 pt of the fold. Fully open: unchanged.
