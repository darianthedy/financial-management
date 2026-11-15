# 12 — Deprecated `foregroundColor` in the verdict banner

- **Severity:** Low
- **Where:** `FinancialManagement/Views/Dashboard/BudgetVerdictBanner.swift:124-128`

## What

The banner builds its line with `Text` concatenation and colors each part with
the deprecated `foregroundColor(_:)`:

```swift
(Text(row.label)
    .font(.subheadline.weight(.semibold))
    .foregroundColor(row.tone.color)
 + (row.detail.map { detail in
     Text(" · \(detail)")
         .font(.subheadline)
         .foregroundColor(Color.appMutedForeground)
 } ?? Text("")))
```

## Why

swiftui-pro `api.md`: use `foregroundStyle()` instead of `foregroundColor()`.
`Text` concatenation with `+` is also discouraged in favor of interpolation.

## Fix

```swift
let label = Text(row.label)
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(row.tone.color)
let detail = Text(row.detail.map { " · \($0)" } ?? "")
    .font(.subheadline)
    .foregroundStyle(Color.appMutedForeground)

Text("\(label)\(detail)")
    .lineLimit(2)   // see finding 03
```

## Verify

Builds without the deprecation warning; banner looks unchanged in light and dark.
