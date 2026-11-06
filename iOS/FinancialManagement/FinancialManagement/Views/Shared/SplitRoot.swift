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
    @Environment(\.splitSelectionStore) private var store
    private let storageKey: String?
    /// The list's selection, as `.splitDetail(storageKey:)` keeps it. Read
    /// here so a stack that pushes is created with the selected detail
    /// already on its path (`SplitPushStack`).
    @SceneStorage private var storedID: String?
    private let restoresSelection: Bool
    private let content: Content

    /// - Parameter storageKey: the list's `.splitDetail` storage key. Without
    ///   one, the stack starts on the list and `.splitDetail` pushes itself.
    init(storageKey: String? = nil, @ViewBuilder content: () -> Content) {
        _storedID = SceneStorage("split.\(storageKey ?? "")")
        self.storageKey = storageKey
        restoresSelection = storageKey != nil
        self.content = content()
    }

    var body: some View {
        GeometryReader { geo in
            if SplitColumns.tiles(geo.size, regular: horizontalSizeClass == .regular) {
                ListDetailSplit { content }
            } else if restoresSelection {
                SplitPushStack(restoring: currentStoredID) { content }
            } else {
                NavigationStack { content }
            }
        }
    }

    /// This run's stored selection, else the scene's (a relaunch).
    private var currentStoredID: String? {
        guard let storageKey, let kept = store?.value(for: storageKey) else { return storedID }
        return kept
    }
}

/// Each list's stored selection (`SplitSelectionRule.Stored`), by its
/// `.splitDetail` storage key, owned by `ContentRootView` above every tab.
///
/// `@SceneStorage` is for restoring a scene on relaunch: each view reading a
/// key keeps its own copy, which needn't see another view's writes while the
/// app runs. A fold or a rotation re-creates the list and its container in
/// the same run, so they read the selection from here, and fall back to
/// their `@SceneStorage` only when this has nothing (a relaunch).
///
/// A cache, not view state: nothing here is observed.
@MainActor
final class SplitSelectionStore {
    private var values: [String: String?] = [:]

    /// The stored selection for `key`: `.some(nil)` once it was cleared,
    /// nil while this run hasn't stored anything for it.
    func value(for key: String) -> String?? {
        values[key]
    }

    func set(_ value: String?, for key: String) {
        values[key] = .some(value)
    }
}

extension EnvironmentValues {
    /// Set by `ContentRootView`. Absent (e.g. in a hosted test), lists use
    /// their `@SceneStorage` alone.
    @Entry var splitSelectionStore: SplitSelectionStore? = nil
}

/// A `.splitDetail` item pushed on a `SplitPushStack`, by its stored ID.
struct SplitPushID: Hashable {
    let id: String
}

extension EnvironmentValues {
    /// The path of the `SplitPushStack` around a list, which its
    /// `.splitDetail` pushes onto.
    @Entry var splitPushPath: Binding<[SplitPushID]>? = nil
}

/// A stack whose path starts with the stored selection, the state
/// restoration `NavigationStack(path:)` is built for: a fold, an unfold or
/// a rotation re-creates the stack already showing the detail, instead of
/// pushing it once the list is on screen.
private struct SplitPushStack<Content: View>: View {
    @State private var path: [SplitPushID]
    /// Until the stack is on screen, it shows what it was created with
    /// without animating: a fold or a rotation re-creates it already on the
    /// detail, which slid in as if just opened.
    @State private var isOnScreen = false
    let content: Content

    init(restoring storedID: String?, @ViewBuilder content: () -> Content) {
        let stored = SplitSelectionRule.Stored(rawValue: storedID)
        _path = State(initialValue: stored.map { [SplitPushID(id: $0.id)] } ?? [])
        self.content = content()
    }

    var body: some View {
        NavigationStack(path: $path) {
            content.environment(\.splitPushPath, $path)
        }
        .transaction { transaction in
            if !isOnScreen { transaction.disablesAnimations = true }
        }
        .onAppear { isOnScreen = true }
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
    ///   (`restoring`), tiled or pushed, so a fold, an unfold or a rotation
    ///   keeps it. Going Back forgets it (`.splitDetail`), so a stack popped
    ///   to its root never re-pushes.
    static func resolve(
        selected: String?, stored: Stored?, available: [String], restoring: Bool, isTiled: Bool
    ) -> String? {
        guard !available.isEmpty else { return selected }
        if let selected { return available.contains(selected) ? selected : nil }
        guard restoring, let stored, available.contains(stored.id) else { return nil }
        return stored.id
    }
}

private struct SplitDetailModifier<Item: Hashable, Detail: View>: ViewModifier {
    @Environment(\.canTileSplitRoot) private var canTile
    @Environment(\.foldKeptModels) private var keptModels
    @Environment(\.splitDetailHost) private var host
    @Environment(\.splitPushPath) private var pushPath
    @Environment(\.splitSelectionStore) private var store
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
            } else if let pushPath {
                // Pushed by value on the stack's path, which a re-created
                // stack starts with (`SplitPushStack`).
                content
                    .navigationDestination(for: SplitPushID.self) { pushed in
                        pushedDetail(pushed.id)
                    }
                    .onChange(of: pushPath.wrappedValue) { _, path in
                        // Back: the list is on screen again with nothing
                        // pushed (it forgets the selection in `onAppear`).
                        if path.isEmpty, selection != nil { selection = nil }
                    }
            } else {
                // Inside another stack (More): pushed by the selection.
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
                remember(SplitSelectionRule.Stored(id: id(new), wasTiled: canTile).rawValue)
                if !canTile, let pushPath, pushPath.wrappedValue.last?.id != id(new) {
                    pushPath.wrappedValue = [SplitPushID(id: id(new))]
                }
            } else if canTile {
                forgetSelection()
            } else if let pushPath, !pushPath.wrappedValue.isEmpty {
                // Closed from the detail (saved, deleted): back to the list.
                pushPath.wrappedValue = []
            }
            // Pushed, nil is also what a fold or a rotation writes as it tears
            // the stack down, which must not forget what the next layout
            // restores. The list forgets only once it is back on screen with
            // nothing pushed: the user went Back (`onAppear` below).
        }
        .onAppear {
            if !canTile, selection == nil, hasRestored, pushPath?.wrappedValue.isEmpty ?? true {
                forgetSelection()
            }
        }
    }

    /// The user left the selection: don't restore it, and start its
    /// drill-down afresh next time.
    private func forgetSelection() {
        remember(nil)
        keptModels?.discardDrilldown(screen: storageKey)
    }

    /// Stores the selection for this run (`SplitSelectionStore`) and for a
    /// relaunch (`@SceneStorage`).
    private func remember(_ value: String?) {
        store?.set(value, for: storageKey)
        storedID = value
    }

    /// This run's stored selection, else the scene's (a relaunch).
    private var currentStoredID: String? {
        store?.value(for: storageKey) ?? storedID
    }

    /// The detail of the item `pushedID` names, once it's in the list.
    @ViewBuilder
    private func pushedDetail(_ pushedID: String) -> some View {
        if let item = items.first(where: { id($0) == pushedID }) {
            detail(item).layoutProbe("split.detail")
        } else {
            ProgressView()
        }
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
        if !canTile, pushPath == nil, current == nil, !hasRestored, !hasAppeared { return }
        let resolved = SplitSelectionRule.resolve(
            selected: current, stored: SplitSelectionRule.Stored(rawValue: currentStoredID),
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
