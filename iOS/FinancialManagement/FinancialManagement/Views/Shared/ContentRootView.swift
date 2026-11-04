import SwiftUI
import UIKit

/// The signed-in root: one Notes-style `NavigationSplitView` on every display
/// (iPhone Duo design §3.1). Sections | list | detail, where Dashboard and
/// Settings, which have no list, fill the detail column beside the sections.
///
/// - Inner display, landscape: the list beside the detail. The sections slide
///   in from the leading edge, pushing the list and dimming the detail
///   (UIKit's displace behaviour, which SwiftUI's split styles don't offer).
///   Dashboard and Settings stay full width, the sections over them.
/// - Inner display, portrait: the detail full screen; the list, and the
///   sections, slide over it.
/// - Outer display (compact): the split collapses into one stack, sections →
///   list → detail, as Notes does. It's the same root, so a fold or unfold
///   keeps the screen, its selection and its state.
struct ContentRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.foldContext) private var fold

    /// Restored per scene (window), so the app reopens on the last section.
    /// The key and raw values are the former tabs', so it carries over.
    @SceneStorage("root.tab") private var section: AppSection = .dashboard
    @State private var visibility: NavigationSplitViewVisibility = .doubleColumn
    /// Collapsed (compact), the column on top, once the user has moved off
    /// the section's own (`RootColumns.compactColumn`), e.g. back to the
    /// section list. Cleared when the section changes.
    @State private var compactColumnOverride: NavigationSplitViewColumn?
    @State private var size: CGSize = .zero
    /// Whether the list column's screen has something in the detail column.
    @State private var detailHost = SplitDetailHost()
    /// The Transactions detail form's draft, owned above the screens so a fold
    /// / unfold keeps unsaved edits (D3.1).
    @State private var transactionDrafts = TransactionEditorDrafts()
    /// The Transactions list, owned here for the same reason: a fold keeps its
    /// filters and search, and a Filters sheet left open through the fold
    /// still applies to the list on screen.
    @State private var transactionList = TransactionListViewModel()
    /// Keeps the Budgets and Fixed Expenses month across a fold.
    @State private var keptModels = FoldKeptModels()

    private var isRegular: Bool { horizontalSizeClass == .regular }
    private var sideBySide: Bool { SplitColumns.sideBySide(size) }

    /// The app opens on the section's screen rather than on the section list.
    private var compactColumn: Binding<NavigationSplitViewColumn> {
        Binding(
            get: { compactColumnOverride ?? RootColumns.compactColumn(for: section) },
            set: { compactColumnOverride = $0 }
        )
    }

    var body: some View {
        Group {
            if section.hasList {
                NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: compactColumn) {
                    sidebar
                } content: {
                    listColumn
                } detail: {
                    // Filled by the list's `.splitDetail`.
                    Color.clear
                }
            } else {
                NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: compactColumn) {
                    sidebar
                } detail: {
                    NavigationStack { screen(section) }
                }
            }
        }
        .navigationSplitViewStyle(.automatic)
        .background {
            RootSplitBehavior(
                behavior: RootColumns.behavior(regular: isRegular, sideBySide: sideBySide, hasList: section.hasList),
                section: section
            )
        }
        .onGeometryChange(for: CGSize.self, of: \.size) { size = $0 }
        // Picking a section closes the sections, as in Notes.
        .onChange(of: section) { _, section in
            compactColumnOverride = nil
            detailHost.hasSelection = false
            applyVisibility()
            // Switching to or from Dashboard / Settings swaps the split, which
            // takes its initial visibility: close the sections on it too.
            Task { @MainActor in applyVisibility() }
        }
        .onChange(of: sideBySide, initial: true) { applyVisibility() }
        .onChange(of: isRegular) { applyVisibility() }
        .onChange(of: detailHost.hasSelection) { applyVisibility() }
        // Above every screen, so an open sheet and its draft survive a fold (D5.1).
        .hostsFoldSafeSheets()
        // Outside the sheet host too, so the sheets inherit it.
        .environment(\.transactionDrafts, transactionDrafts)
        .environment(\.foldKeptModels, keptModels)
    }

    private func applyVisibility() {
        visibility = RootColumns.visibility(
            hasList: section.hasList, selected: detailHost.hasSelection, sideBySide: sideBySide
        )
    }

    private var sectionSelection: Binding<AppSection?> {
        Binding(get: { section }, set: { if let new = $0 { section = new } })
    }

    private var sidebar: some View {
        List(selection: sectionSelection) {
            Section {
                ForEach(AppSection.primary) { row($0) }
            }
            Section("Management") {
                ForEach(AppSection.management) { row($0) }
            }
            Section {
                SignOutButton()
            }
        }
        .navigationTitle("Financial Management")
        // One width with or without a list column (it was wider beside
        // Dashboard and Settings).
        .navigationSplitViewColumnWidth(RootColumns.sidebarWidth)
    }

    private func row(_ section: AppSection) -> some View {
        Label(section.title, systemImage: section.systemImage)
            .tag(section)
            .layoutProbe("root.section.\(section.rawValue)", interactive: true)
    }

    /// The section's list: tiled beside the detail on regular width.
    @ViewBuilder
    private var listColumn: some View {
        let width = SplitColumns.listWidth(for: size.width, fold: fold)
        let list = screen(section).id(section)
        Group {
            if isRegular {
                list.splitListColumn(detailHost)
            } else {
                list
            }
        }
        .navigationSplitViewColumnWidth(min: min(width, SplitColumns.minimumListWidth), ideal: width, max: width)
    }

    @ViewBuilder
    private func screen(_ section: AppSection) -> some View {
        switch section {
        case .dashboard: DashboardView()
        case .accounts: AccountListView()
        case .transactions: TransactionListView(model: transactionList, isTabRoot: true)
        case .budgets: BudgetListView()
        case .tags: TagsListView()
        case .categories: CategoryListView()
        case .fixedExpenses: FixedExpenseListView()
        case .scheduled: ScheduledListView()
        case .settings: SettingsView()
        }
    }
}

/// The root split's column rules. Pure, so they are unit-tested directly.
enum RootColumns {
    /// What shows, the sections aside (they slide in on demand):
    /// - a list section: as `SplitColumns.visibility` (the list beside the
    ///   detail in landscape; the detail alone in portrait once picked);
    /// - Dashboard and Settings: their screen alone.
    static func visibility(hasList: Bool, selected: Bool, sideBySide: Bool) -> NavigationSplitViewVisibility {
        hasList ? SplitColumns.visibility(selected: selected, sideBySide: sideBySide) : .detailOnly
    }

    /// Collapsed, the column the app opens on: the section's list, or its
    /// screen for Dashboard and Settings.
    static func compactColumn(for section: AppSection) -> NavigationSplitViewColumn {
        section.hasList ? .content : .detail
    }

    /// How the sections come in on regular width, as in Notes: pushing the
    /// list aside in landscape, over everything in portrait. Nil (compact)
    /// leaves the system's.
    ///
    /// Dashboard and Settings always open full width, so their sections only
    /// ever slide over them.
    static func behavior(
        regular: Bool, sideBySide: Bool, hasList: Bool
    ) -> UISplitViewController.SplitBehavior? {
        guard regular else { return nil }
        return hasList && sideBySide ? .displace : .overlay
    }

    /// The sections' width, the system's for a three-column split.
    static let sidebarWidth: CGFloat = 280
}

/// Sets the split behaviour of the `UISplitViewController` behind the root's
/// `NavigationSplitView`, which SwiftUI's split styles can't express.
private struct RootSplitBehavior: UIViewRepresentable {
    let behavior: UISplitViewController.SplitBehavior?
    /// A section change can swap the split for a new one, which needs the
    /// behaviour set again.
    let section: AppSection

    func makeUIView(context: Context) -> BehaviorView {
        let view = BehaviorView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: BehaviorView, context: Context) {
        uiView.behavior = behavior
        uiView.apply()
        // The swapped-in split may not exist until the next pass.
        DispatchQueue.main.async { uiView.apply() }
    }

    final class BehaviorView: UIView {
        var behavior: UISplitViewController.SplitBehavior?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            apply()
        }

        func apply() {
            guard let behavior, let split = rootSplit(), split.preferredSplitBehavior != behavior else { return }
            split.preferredSplitBehavior = behavior
        }

        /// The first split in this window. This view is the split's sibling,
        /// not inside it, so it searches down from the window's root.
        private func rootSplit() -> UISplitViewController? {
            var queue: [UIViewController] = window?.rootViewController.map { [$0] } ?? []
            while !queue.isEmpty {
                let controller = queue.removeFirst()
                if let split = controller as? UISplitViewController { return split }
                queue += controller.children
            }
            return nil
        }
    }
}
