import SwiftUI
import UIKit

// List → detail scaffold (iPhone Duo design §3.2, implementation plan D2.0,
// docs/ios-tab-root-plan.md).
//
// Accounts, Transactions and Budgets each sit in a `SplitRootContainer` at the
// root of their tab. A list screen applies `.splitDetail(selection:…)` where
// it used `.navigationDestination(item:)`, after its title, toolbar and
// overlay.
//
// As in Music, list | detail tiles only on the inner display in landscape:
// regular width, wider than tall, and room for both columns. There the
// modifier fills the split's detail column with the selected item, or a
// placeholder while nothing is selected. Everywhere else (portrait, the outer
// display, a narrow Split View, and screens pushed from More) the container
// is a plain stack and the modifier is the same `navigationDestination(item:)`
// push as before. A screen pushed further (e.g. inside a detail) always pushes.
//
// The modifier sits *inside* the screen, so the screen's own state (its view
// model, the selection) lives above the modifier's switch. A fold or a rotation
// flips the container, which re-creates the screen, which is why the selection
// is restored from `@SceneStorage` and sheets use `.foldSafeSheet`.

extension EnvironmentValues {
    /// Set in a tiled split's list column: the next
    /// `.splitDetail` below it fills the detail column. Reset in the detail, so
    /// nested screens push.
    @Entry var canTileSplitRoot = false
    /// True inside a tiled split's list column, where the selected row is
    /// highlighted (`.splitRowSelected(_:)`).
    @Entry var isSplitListColumn = false
    /// The split around a tiled list column, told whether something is
    /// selected.
    @Entry var splitDetailHost: SplitDetailHost? = nil
}

/// What a tiled list column tells the split around it: the list's
/// `.splitDetail` hands it the detail, which the split shows in its `detail`
/// column, as SwiftUI's split view expects (the detail driven by the
/// selection, a placeholder while there is none).
@MainActor
@Observable
final class SplitDetailHost {
    var hasSelection = false
    /// Builds the selected item's detail. Called in the detail column's body,
    /// so what it reads (the list's view models) keeps the detail current.
    fileprivate(set) var detail: (() -> AnyView)?
    /// Identifies the detail, so another selection starts a fresh one.
    fileprivate(set) var detailID: String?
    fileprivate(set) var placeholder: SplitPlaceholder?

    fileprivate func show(id: String?, placeholder: SplitPlaceholder, detail: (() -> AnyView)?) {
        self.placeholder = placeholder
        detailID = id
        self.detail = detail
        hasSelection = id != nil
    }
}

/// Hosts a tab's list screen: list | detail side by side when
/// `SplitColumns.tiles(_:regular:)`, else a stack where the detail pushes.
/// The app's tabs and the layout tests both use it.
struct SplitRootContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { geo in
            if SplitColumns.tiles(geo.size, regular: horizontalSizeClass == .regular) {
                ListDetailSplit { content }
            } else {
                NavigationStack { content }
            }
        }
    }
}

/// A list column beside a detail column, both always on screen, as Music's
/// Artists | artist on the inner display in landscape.
private struct ListDetailSplit<ListColumn: View>: View {
    @Environment(\.foldContext) private var fold
    @State private var host = SplitDetailHost()
    /// Both columns, always: the system toggle that hides the list is removed.
    @State private var visibility: NavigationSplitViewVisibility = .doubleColumn
    @ViewBuilder var list: ListColumn

    var body: some View {
        GeometryReader { geo in
            let width = SplitColumns.listWidth(for: geo.size.width, fold: fold)
            NavigationSplitView(columnVisibility: $visibility) {
                list
                    .splitListColumn(host)
                    .toolbar(removing: .sidebarToggle)
                    .navigationSplitViewColumnWidth(
                        min: min(width, SplitColumns.minimumListWidth), ideal: width, max: width
                    )
            } detail: {
                // Its own stack, so a detail can push further.
                NavigationStack { SplitDetailColumn(host: host) }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .readsFoldContext()
    }
}

/// The tiled split's detail column: the list's selected item, or its
/// placeholder while nothing is selected.
private struct SplitDetailColumn: View {
    let host: SplitDetailHost

    var body: some View {
        if let detail = host.detail {
            detail()
                .id(host.detailID)
                .layoutProbe("split.detail")
        } else if let placeholder = host.placeholder {
            ContentUnavailableView {
                Label(placeholder.title, systemImage: placeholder.systemImage)
            } description: {
                if let description = placeholder.description { Text(description) }
            }
            .layoutProbe("split.placeholder")
        }
    }
}

extension View {
    /// Marks this view as a tiled split's list column: its `.splitDetail`
    /// fills the detail column and reports to `host`.
    func splitListColumn(_ host: SplitDetailHost) -> some View {
        self
            .environment(\.canTileSplitRoot, true)
            .environment(\.isSplitListColumn, true)
            .environment(\.splitDetailHost, host)
            .layoutProbe("split.list")
    }
}

/// The detail column's empty state, e.g. "Select an Account".
struct SplitPlaceholder: Equatable {
    var title: String
    var systemImage: String
    var description: String?
}

extension View {
    /// Shows `detail(item)` for the selected item: in a tiled detail column
    /// (see `SplitRootContainer`), else pushed, like
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
    /// (660 pt).
    static func tiles(width: CGFloat) -> Bool {
        width >= minimumListWidth + minimumDetailWidth
    }

    /// Whether list | detail tiles at `size`, as in Music: regular width, in
    /// landscape, with room for both columns. Portrait, the outer display and
    /// a narrow Split View push instead.
    static func tiles(_ size: CGSize, regular: Bool) -> Bool {
        regular && size.width > size.height && tiles(width: size.width)
    }

    /// The list column's width, the same on every tab: on the fold in book
    /// posture, when both regions fit a column, so neither column straddles
    /// it; else half the space, as long as the detail keeps its minimum.
    static func listWidth(for width: CGFloat, fold: FoldContext = .none) -> CGFloat {
        if case .book(let x) = fold, x >= minimumListWidth, width - x >= minimumDetailWidth {
            return x.rounded()
        }
        return max(minimumListWidth, min((width / 2).rounded(), width - minimumDetailWidth))
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
    @Environment(\.splitDetailHost) private var host
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
                // The split's detail column shows it (`SplitDetailColumn`).
                content.onChange(of: selection.map(id), initial: true) { publish() }
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
            if let new {
                storedID = SplitSelectionRule.Stored(id: id(new), wasTiled: canTile).rawValue
            } else if canTile {
                forgetSelection()
            }
            // Pushed, nil is also what a fold or a rotation writes as it tears
            // the stack down, which must not forget what the next layout
            // restores. The list forgets only once it is back on screen with
            // nothing pushed: the user went Back (`onAppear` below).
        }
        .onAppear {
            if !canTile, selection == nil, hasRestored { forgetSelection() }
        }
    }

    /// The user left the selection: don't restore it, and start its
    /// drill-down afresh next time.
    private func forgetSelection() {
        storedID = nil
        keptModels?.discardDrilldown(screen: storageKey)
    }

    /// Hands the tiled split the selected item's detail, or the placeholder.
    private func publish() {
        guard let host else { return }
        let detail = detail
        host.show(
            id: selection.map(id),
            placeholder: placeholder,
            detail: selection.map { item in { AnyView(detail(item)) } }
        )
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
