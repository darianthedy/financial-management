import SwiftUI

// List → detail scaffold (iPhone Duo design §3.2, implementation plan D2.0).
//
// A list screen adopts it in two places:
// 1. Its tab root is a `SplitRootContainer` instead of a `NavigationStack`.
// 2. Its body applies `.splitDetail(selection:…)` where it used
//    `.navigationDestination(item:)`, after its title, toolbar and overlay.
//
// On regular width the container lets the modifier tile the screen: a list
// column | a detail column (each its own `NavigationStack`), with a
// placeholder while nothing is selected. Everywhere else — compact width, or the screen pushed
// onto another stack (More › Tags on the outer display) — the modifier is the
// same `navigationDestination(item:)` push as before, so compact is unchanged.
//
// The modifier sits *inside* the screen, so the screen's own state (its view
// model, sheets, the selection) lives above the container switch.

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
struct SplitRootContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: Content

    var body: some View {
        if horizontalSizeClass == .regular {
            content.environment(\.canTileSplitRoot, true)
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

    /// Outlines a card (e.g. a grid tile or a budget card) while it is the
    /// selection of a tiled split. No-op on compact width.
    func splitCardSelected(_ isSelected: Bool, cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(SplitCardSelectedModifier(isSelected: isSelected, cornerRadius: cornerRadius))
    }
}

/// The tiled list column's width: 40% of the space, kept between 300 and
/// 420 pt, so the detail column always gets the larger share.
enum SplitColumns {
    static func listWidth(for width: CGFloat) -> CGFloat {
        min(420, max(300, (width * 0.4).rounded()))
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
    @Binding var selection: Item?
    let items: [Item]
    let id: (Item) -> String
    let placeholder: SplitPlaceholder
    let detail: (Item) -> Detail

    @SceneStorage private var storedID: String?
    /// The stored selection is restored once per appearance, on first data.
    @State private var hasRestored = false

    init(
        selection: Binding<Item?>, items: [Item], id: @escaping (Item) -> String,
        storageKey: String, placeholder: SplitPlaceholder, detail: @escaping (Item) -> Detail
    ) {
        _selection = selection
        self.items = items
        self.id = id
        self.placeholder = placeholder
        self.detail = detail
        _storedID = SceneStorage("split.\(storageKey)")
    }

    func body(content: Content) -> some View {
        Group {
            if canTile {
                // A fixed two-column layout rather than `NavigationSplitView`,
                // which on the inner display in portrait (669 pt) overlays the
                // list on a dimmed detail even with `.balanced` / `.all`.
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        NavigationStack {
                            content
                                .environment(\.canTileSplitRoot, false)
                                .environment(\.isSplitListColumn, true)
                        }
                        .frame(width: SplitColumns.listWidth(for: geo.size.width))
                        .layoutProbe("split.list")

                        Divider().ignoresSafeArea()

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
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                content.navigationDestination(item: $selection) { item in
                    detail(item).layoutProbe("split.detail")
                }
            }
        }
        .onChange(of: items.map(id), initial: true) { _, available in
            reconcile(available)
        }
        .onChange(of: selection) { _, new in
            storedID = new.map { SplitSelectionRule.Stored(id: id($0), wasTiled: canTile).rawValue }
        }
    }

    private func reconcile(_ available: [String]) {
        let current = selection.map(id)
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
