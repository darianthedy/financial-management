import SwiftUI

/// The signed-in root: a tab bar with the same five tabs on every display,
/// as in Music (docs/ios-tab-root-plan.md).
///
/// - Dashboard is a plain stack.
/// - Accounts, Transactions and Budgets are list → detail screens: side by
///   side on the inner display in landscape, pushed everywhere else
///   (`SplitRootContainer`).
/// - More lists the management screens and Settings; each pushes, and pushes
///   its own detail.
///
/// The tabs never change with the size class, so a fold or a rotation keeps
/// the tab. What a fold or rotation re-creates inside a tab is restored by the
/// state owned here and by `.splitDetail`'s `@SceneStorage` selection.
struct ContentRootView: View {
    /// Restored per scene (window). Holds a `RootTab` raw value, or, from
    /// builds with the sections sidebar, an `AppSection` one (`RootRoute`).
    @SceneStorage("root.tab") private var storedTab = RootTab.dashboard.rawValue
    /// The screen pushed on More's stack, as an `AppSection` raw value.
    @SceneStorage("root.more") private var storedMore = ""

    @State private var tab: RootTab = .dashboard
    @State private var morePath: [AppSection] = []
    @State private var hasRestored = false

    /// The Transactions detail form's draft, owned above the tabs so a fold /
    /// unfold or a rotation keeps unsaved edits (D3.1).
    @State private var transactionDrafts = TransactionEditorDrafts()
    /// The Transactions list, owned here for the same reason: a fold keeps its
    /// filters and search, and a Filters sheet left open through the fold
    /// still applies to the list on screen.
    @State private var transactionList = TransactionListViewModel()
    /// Keeps the Budgets and Fixed Expenses month across a fold.
    @State private var keptModels = FoldKeptModels()

    var body: some View {
        TabView(selection: $tab) {
            Tab(AppSection.dashboard.title, systemImage: AppSection.dashboard.systemImage, value: RootTab.dashboard) {
                NavigationStack { DashboardView() }
            }
            Tab(AppSection.accounts.title, systemImage: AppSection.accounts.systemImage, value: RootTab.accounts) {
                SplitRootContainer(storageKey: "accounts") { AccountListView() }
            }
            Tab(AppSection.transactions.title, systemImage: AppSection.transactions.systemImage, value: RootTab.transactions) {
                SplitRootContainer(storageKey: "transactions") {
                    TransactionListView(model: transactionList, isTabRoot: true)
                }
            }
            Tab(AppSection.budgets.title, systemImage: AppSection.budgets.systemImage, value: RootTab.budgets) {
                SplitRootContainer(storageKey: "budgets") { BudgetListView() }
            }
            Tab("More", systemImage: "ellipsis", value: RootTab.more) {
                NavigationStack(path: $morePath) {
                    MoreView()
                        .navigationDestination(for: AppSection.self) { section in
                            MoreDestinationView(section: section)
                        }
                }
            }
        }
        // A tab bar on every display, never a sidebar: the bottom bar in
        // portrait, the Duo's vertical bar in landscape and on the outer
        // display, as in Music.
        .tabViewStyle(.tabBarOnly)
        .onAppear(perform: restore)
        .onChange(of: tab) { _, tab in storedTab = tab.rawValue }
        .onChange(of: morePath) { _, path in storedMore = path.first?.rawValue ?? "" }
        // Above every tab, so an open sheet and its draft survive a fold or
        // a rotation (D5.1).
        .hostsFoldSafeSheets()
        // Outside the sheet host too, so the sheets inherit it.
        .environment(\.transactionDrafts, transactionDrafts)
        .environment(\.foldKeptModels, keptModels)
    }

    private func restore() {
        guard !hasRestored else { return }
        hasRestored = true
        let route = RootRoute(storedTab: storedTab, storedMore: storedMore)
        tab = route.tab
        morePath = route.morePath
    }
}

/// The root's tabs. The raw values are persisted in `@SceneStorage`, so don't
/// rename them; the first four match the `AppSection`s they show.
enum RootTab: String, CaseIterable, Hashable {
    case dashboard
    case accounts
    case transactions
    case budgets
    case more

    /// The section a primary tab shows; nil for More.
    var section: AppSection? { AppSection(rawValue: rawValue) }
}

/// Where the root opens, from what the scene stored. Pure, so it is unit
/// tested directly.
struct RootRoute: Equatable {
    var tab: RootTab
    var morePath: [AppSection]

    /// - `storedTab`: a `RootTab` raw value, or an `AppSection` one stored by
    ///   the sections sidebar (a management section opens More with it pushed).
    /// - `storedMore`: the `AppSection` pushed on More, if any.
    init(storedTab: String, storedMore: String) {
        if let tab = RootTab(rawValue: storedTab) {
            self.tab = tab
            let pushed = AppSection(rawValue: storedMore).flatMap { AppSection.more.contains($0) ? $0 : nil }
            morePath = tab == .more ? pushed.map { [$0] } ?? [] : []
        } else if let section = AppSection(rawValue: storedTab), AppSection.more.contains(section) {
            tab = .more
            morePath = [section]
        } else {
            tab = .dashboard
            morePath = []
        }
    }

    init(tab: RootTab, morePath: [AppSection]) {
        self.tab = tab
        self.morePath = morePath
    }
}

/// The More tab's list: the management screens, Settings, then Sign Out.
struct MoreView: View {
    var body: some View {
        List {
            Section("Management") {
                ForEach(AppSection.management) { row($0) }
            }
            Section {
                row(.settings)
            }
            Section {
                SignOutButton()
            }
        }
        .readableContentMargins()
        .navigationTitle("More")
    }

    private func row(_ section: AppSection) -> some View {
        NavigationLink(value: section) {
            Label(section.title, systemImage: section.systemImage)
        }
        .layoutProbe("more.\(section.rawValue)", interactive: true)
    }
}

/// A screen pushed from More. Its detail pushes too: list | detail only tiles
/// at a tab's root.
private struct MoreDestinationView: View {
    let section: AppSection

    var body: some View {
        switch section {
        case .tags: TagsListView()
        case .categories: CategoryListView()
        case .fixedExpenses: FixedExpenseListView()
        case .scheduled: ScheduledListView()
        case .settings: SettingsView()
        case .dashboard, .accounts, .transactions, .budgets: EmptyView()
        }
    }
}
