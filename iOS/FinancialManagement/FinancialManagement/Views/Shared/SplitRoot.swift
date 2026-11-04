import SwiftUI

// List → detail scaffold (iPhone Duo design §3.2, implementation plan D2.0).
//
// A list screen adopts it in two places:
// 1. Its tab root is a `SplitRootContainer` instead of a `NavigationStack`.
// 2. Its body applies `.splitDetail(selection:…)` where it used
//    `.navigationDestination(item:)`, after its title, toolbar and overlay.
//
// On regular width the container lets the modifier split the screen with the
// system's `NavigationSplitView`, as Notes does: list | detail side by side in
// landscape; in portrait the detail fills the screen and the list slides over
// it. A placeholder fills the detail while nothing is selected. Everywhere else — compact width, or the screen pushed
// onto another stack (More › Tags on the outer display) — the modifier is the
// same `navigationDestination(item:)` push as before, so compact is unchanged.
//
// The modifier sits *inside* the screen, so the screen's own state (its view
// model, the selection) lives above the modifier's switch. `SplitRootContainer`
// still re-creates the screen on a size-class change, which is why the selection
// is restored from `@SceneStorage` and sheets use `.foldSafeSheet`.

extension EnvironmentValues {
    /// Set by `SplitRootContainer` on regular width: the next `.splitDetail`
    /// below it may tile. Reset inside the split, so nested screens push.
    @Entry var canTileSplitRoot = false
    /// True inside a tiled split's list column, where the selected row is
    /// highlighted (`.splitRowSelected(_:)`).
    @Entry var isSplitListColumn = false
}

/// The tab root of a screen that uses `.splitDetail`: a `NavigationStack` on
/// compact width (exactly as before), and on regular width no stack at all,
/// because the screen's tiled columns bring their own.
///
/// Regular width that is still too narrow for two columns (the inner display in
/// book posture with the sidebar filling the leading region leaves ~390 pt)
/// gets the compact stack too, rather than a crushed detail column.
struct SplitRootContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: Content

    var body: some View {
        if horizontalSizeClass == .regular {
            GeometryReader { geo in
                if SplitColumns.tiles(width: geo.size.width) {
                    content.environment(\.canTileSplitRoot, true)
                } else {
                    NavigationStack { content }
                }
            }
        } else {
            NavigationStack { content }
        }
    }
}

/// The detail column's empty state, e.g. "Select an Account".
struct SplitPlaceholder {
    var title: String
    var systemImage: String
    var description: String?
}

extension View {
    /// Shows `detail(item)` for the selected item: in a tiled detail column on
    /// regular width (see `SplitRootContainer`), else pushed, like
    /// `navigationDestination(item:)`.
    ///
    /// - Parameters:
    ///   - items: the list's current items. The selection is restored from
    ///     `@SceneStorage` (`storageKey`) once it appears in them — so it
    ///     survives a fold / unfold that swaps the tab (see
    ///     `SplitSelectionRule`) — and cleared when it disappears from them
    ///     (deleted, or another month is shown).
    ///   - id: a stable, persistable identity for an item.
    func splitDetail<Item: Hashable, Detail: View>(
        selection: Binding<Item?>,
        in items: [Item],
        id: @escaping (Item) -> String,
        storageKey: String,
        placeholder: SplitPlaceholder,
        @ViewBuilder detail: @escaping (Item) -> Detail
    ) -> some View {
        modifier(SplitDetailModifier(
            selection: selection, items: items, id: id,
            storageKey: storageKey, placeholder: placeholder, detail: detail
        ))
    }

    /// Highlights a list row while it is the selection of a tiled split. No-op
    /// on compact width, where selecting pushes.
    func splitRowSelected(_ isSelected: Bool) -> some View {
        modifier(SplitRowSelectedModifier(isSelected: isSelected))
    }

    /// Makes a row that has no tap action on compact width select itself in a
    /// tiled split (e.g. Fixed Expenses, Scheduled). No-op on compact, so the
    /// row's swipe actions and context menu behave exactly as before.
    func splitSelectOnTap(_ select: @escaping () -> Void) -> some View {
        modifier(SplitSelectOnTapModifier(select: select))
    }

    /// Outlines a card (e.g. a grid tile or a budget card) while it is the
    /// selection of a tiled split. No-op on compact width.
    func splitCardSelected(_ isSelected: Bool, cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(SplitCardSelectedModifier(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

/// The tiled split's columns. Pure, so it is unit-tested directly.
enum SplitColumns {
    static let minimumListWidth: CGFloat = 300
    /// The narrowest detail column worth tiling: the embedded transaction form
    /// keeps "Cancel", its title and "Save and Confirm" on the bar. At ~290 pt
    /// (flat, sidebar open) Save fell into "…" and the list column's rows were
    /// cut to one letter (device test, build 144), so that layout pushes now.
    static let minimumDetailWidth: CGFloat = 360

    /// Whether `width` fits a list and a detail column at their minimums
    /// (660 pt): the inner display in landscape or portrait, but not beside an
    /// open sidebar.
    static func tiles(width: CGFloat) -> Bool {
        width >= minimumListWidth + minimumDetailWidth
    }

    /// Landscape: list | detail side by side. Portrait: the detail fills the
    /// screen and the list slides over it, as in Notes.
    static func sideBySide(_ size: CGSize) -> Bool {
        size.width > size.height
    }

    /// The split's column visibility. Side by side, always both: handing it
    /// to the system (`.automatic`) hid the list on every tap (build 150).
    /// Portrait: the list over the detail until something is picked.
    static func visibility(selected: Bool, sideBySide: Bool) -> NavigationSplitViewVisibility {
        sideBySide || !selected ? .all : .detailOnly
    }

    /// The list column's width: on the fold in book posture, when both regions
    /// fit a column, so neither column straddles it; else 40% of the space,
    /// kept between 300 and 420 pt, so the detail column gets the larger share.
    static func listWidth(for width: CGFloat, fold: FoldContext = .none) -> CGFloat {
        if case .book(let x) = fold, x >= minimumListWidth, width - x >= minimumDetailWidth {
            return x.rounded()
        }
        return min(420, max(minimumListWidth, (width * 0.4).rounded()))
    }
}

/// The pure selection rule behind `.splitDetail`, kept apart so it is unit
/// tested without rendering.
enum SplitSelectionRule {
    /// A persisted selection: the item's ID and whether it was chosen in a
    /// tiled split. Stored as `"t:<id>"` or `"s:<id>"`.
    struct Stored: Equatable {
        var id: String
        var wasTiled: Bool

        init(id: String, wasTiled: Bool) {
            self.id = id
            self.wasTiled = wasTiled
        }

        init?(rawValue: String?) {
            guard let rawValue, rawValue.count > 2,
                  let mode = rawValue.first, mode == "t" || mode == "s",
                  rawValue.dropFirst().first == ":" else { return nil }
            self.init(id: String(rawValue.dropFirst(2)), wasTiled: mode == "t")
        }

        var rawValue: String { "\(wasTiled ? "t" : "s"):\(id)" }
    }

    /// The selected ID after the list's items change.
    ///
    /// - An empty list is treated as "still loading": nothing changes.
    /// - A selection that is no longer listed is cleared.
    /// - With nothing selected, the stored selection is restored once
    ///   (`restoring`) if that can't surprise anyone: into a tiled split
    ///   (it only fills the detail column), or from a tiled split into a push
    ///   (fold continuity). A push → push restore is skipped, so relaunching
    ///   the iPhone layout, or popping a stack to its root, never re-pushes.
    static func resolve(
        selected: String?, stored: Stored?, available: [String], restoring: Bool, isTiled: Bool
    ) -> String? {
        guard !available.isEmpty else { return selected }
        if let selected { return available.contains(selected) ? selected : nil }
        guard restoring, let stored, isTiled || stored.wasTiled,
              available.contains(stored.id) else { return nil }
        return stored.id
    }
}

private struct SplitDetailModifier<Item: Hashable, Detail: View>: ViewModifier {
    @Environment(\.canTileSplitRoot) private var canTile
    @Environment(\.foldKeptModels) private var keptModels
    @Binding var selection: Item?
    let storageKey: String
    let items: [Item]
    let id: (Item) -> String
    let placeholder: SplitPlaceholder
    let detail: (Item) -> Detail

    @SceneStorage private var storedID: String?
    /// The stored selection is restored once per appearance, on first data.
    @State private var hasRestored = false
    /// Set once the screen is on screen. A push restored before then is
    /// dropped by its `NavigationStack`, which writes nil back and so clears
    /// the stored selection and the draft with it.
    @State private var hasAppeared = false

    init(
        selection: Binding<Item?>, items: [Item], id: @escaping (Item) -> String,
        storageKey: String, placeholder: SplitPlaceholder, detail: @escaping (Item) -> Detail
    ) {
        _selection = selection
        self.storageKey = storageKey
        self.items = items
        self.id = id
        self.placeholder = placeholder
        self.detail = detail
        _storedID = SceneStorage("split.\(storageKey)")
    }

    func body(content: Content) -> some View {
        Group {
            if canTile {
                // The system split, as in Notes: side by side in landscape,
                // the detail full screen with the list sliding over it in
                // portrait. The system knows the list is the leading column,
                // so its bar stays horizontal; two side-by-side stacks each
                // took the vertical bar in landscape, which cut an 84 pt
                // strip off the list (device test, builds 148–149).
                SystemSplitColumns(selected: selection != nil) {
                    content
                        .environment(\.canTileSplitRoot, false)
                        .environment(\.isSplitListColumn, true)
                } detail: {
                    NavigationStack {
                        if let selection {
                            detail(selection)
                                .id(id(selection))
                                .layoutProbe("split.detail")
                        } else {
                            ContentUnavailableView {
                                Label(placeholder.title, systemImage: placeholder.systemImage)
                            } description: {
                                if let description = placeholder.description { Text(description) }
                            }
                            .layoutProbe("split.placeholder")
                        }
                    }
                    .environment(\.canTileSplitRoot, false)
                }
                .readsFoldContext()
            } else {
                content.navigationDestination(item: $selection) { item in
                    detail(item).layoutProbe("split.detail")
                }
            }
        }
        .onChange(of: items.map(id), initial: true) { _, available in
            reconcile(available)
        }
        .task {
            hasAppeared = true
            reconcile(items.map(id))
        }
        .onChange(of: selection) { _, new in
            storedID = new.map { SplitSelectionRule.Stored(id: id($0), wasTiled: canTile).rawValue }
            if new == nil { keptModels?.discardDrilldown(screen: storageKey) }
        }
    }

    private func reconcile(_ available: [String]) {
        let current = selection.map(id)
        // A push restore waits for `.task` (e.g. a fold onto the outer display
        // with the Transactions list already loaded, which reports its items
        // before its stack exists).
        if !canTile, current == nil, !hasRestored, !hasAppeared { return }
        let resolved = SplitSelectionRule.resolve(
            selected: current, stored: SplitSelectionRule.Stored(rawValue: storedID),
            available: available, restoring: !hasRestored, isTiled: canTile
        )
        if !available.isEmpty { hasRestored = true }
        guard resolved != current else { return }
        selection = resolved.flatMap { wanted in items.first { id($0) == wanted } }
    }
}

/// The system split's two columns, with the list as wide as `SplitColumns`
/// says: on the fold in book posture, so each column gets a region.
private struct SystemSplitColumns<ListColumn: View, DetailColumn: View>: View {
    @Environment(\.foldContext) private var fold
    let selected: Bool
    @State private var visibility: NavigationSplitViewVisibility = .all
    @ViewBuilder var list: ListColumn
    @ViewBuilder var detail: DetailColumn

    var body: some View {
        GeometryReader { geo in
            let width = SplitColumns.listWidth(for: geo.size.width, fold: fold)
            let split = NavigationSplitView(columnVisibility: $visibility) {
                list
                    .layoutProbe("split.list")
                    // May shrink to the minimum rather than overlay the
                    // detail when both don't fit at the ideal width.
                    .navigationSplitViewColumnWidth(
                        min: min(width, SplitColumns.minimumListWidth), ideal: width, max: width
                    )
            } detail: {
                detail
            }
            // Explicit, because `.automatic` overlaid the list in landscape
            // too, e.g. in book posture. Rotating swaps the style, which rebuilds
            // the split; the selection and drafts live above it.
            let sideBySide = SplitColumns.sideBySide(geo.size)
            Group {
                if sideBySide {
                    split.navigationSplitViewStyle(.balanced)
                } else {
                    split.navigationSplitViewStyle(.prominentDetail)
                }
            }
            .onChange(of: sideBySide, initial: true) { _, sideBySide in
                visibility = SplitColumns.visibility(selected: selected, sideBySide: sideBySide)
            }
            .onChange(of: selected) { _, selected in
                visibility = SplitColumns.visibility(selected: selected, sideBySide: sideBySide)
            }
        }
    }
}

private struct SplitRowSelectedModifier: ViewModifier {
    @Environment(\.isSplitListColumn) private var isSplitListColumn
    let isSelected: Bool

    func body(content: Content) -> some View {
        content.listRowBackground(
            isSplitListColumn && isSelected ? Color.appPrimary.opacity(0.15) : nil
        )
    }
}

private struct SplitCardSelectedModifier: ViewModifier {
    @Environment(\.isSplitListColumn) private var isSplitListColumn
    let isSelected: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            if isSplitListColumn && isSelected {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.appPrimary, lineWidth: 2)
            }
        }
    }
}

private struct SplitSelectOnTapModifier: ViewModifier {
    @Environment(\.isSplitListColumn) private var isSplitListColumn
    let select: () -> Void

    func body(content: Content) -> some View {
        if isSplitListColumn {
            Button(action: select) {
                content.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }
}
