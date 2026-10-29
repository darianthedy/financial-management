import SwiftUI

/// The signed-in root (iPhone Duo design §3.1, implementation plan D1.2).
///
/// Compact width (iPhone, the Duo's outer display, narrow Split View): the
/// four primary tabs plus More, exactly as before. Regular width (the inner
/// display, iPad, when `AdaptiveLayout` is on): an adaptable tab bar / sidebar
/// where More's destinations become their own tabs and Sign Out moves to the
/// sidebar footer.
///
/// Tabs are chosen by size class rather than `.defaultVisibility(.hidden, for:)`,
/// which the probe showed doesn't hide tabs on compact width (design §1.3 #5).
struct ContentRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Restored per scene (window), so the app reopens on the last tab.
    @SceneStorage("root.tab") private var selection: AppTab = .dashboard
    /// What is pushed on More's stack (compact width only).
    @State private var morePath: [MoreDestination] = []

    var body: some View {
        TabView(selection: $selection) {
            // Tab set / order / labels mirror web's nav-config.ts primary items
            // (Dashboard, Accounts, Transactions, Budgets); SF Symbols are chosen
            // to match each Lucide icon there.

            // web LayoutDashboard (grid)
            Tab("Dashboard", systemImage: "square.grid.2x2", value: AppTab.dashboard) {
                NavigationStack { DashboardView() }
            }
            // web Wallet
            Tab("Accounts", systemImage: "wallet.bifold", value: AppTab.accounts) {
                NavigationStack { AccountListView() }
            }
            // web ArrowLeftRight
            Tab("Transactions", systemImage: "arrow.left.arrow.right", value: AppTab.transactions) {
                NavigationStack { TransactionListView() }
            }
            // web PiggyBank (no SF piggy-bank symbol; target reads as a budget goal)
            Tab("Budgets", systemImage: "target", value: AppTab.budgets) {
                NavigationStack { BudgetListView() }
            }

            if horizontalSizeClass == .regular {
                // Inner display: More's destinations, promoted into the sidebar.
                TabSection("Management") {
                    ForEach(MoreDestination.managementCases, id: \.self) { destination in
                        Tab(destination.title, systemImage: destination.systemImage, value: destination.tab) {
                            NavigationStack { destination.view }
                        }
                    }
                }
                Tab(MoreDestination.settings.title, systemImage: MoreDestination.settings.systemImage, value: AppTab.settings) {
                    NavigationStack { MoreDestination.settings.view }
                }
            } else {
                Tab("More", systemImage: "ellipsis", value: AppTab.more) {
                    NavigationStack(path: $morePath) {
                        MoreView()
                            .navigationDestination(for: MoreDestination.self) { $0.view }
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .duoSidebarTabPlacement()
        .tabViewSidebarBottomBar {
            SignOutButton()
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        // Continuity (design §3.1): fold / unfold or a Split View resize keeps
        // the user on the same screen, e.g. Tags ⇄ More › Tags.
        .onAppear { resolveRoute(for: horizontalSizeClass) }
        .onChange(of: horizontalSizeClass) { _, sizeClass in resolveRoute(for: sizeClass) }
    }

    private func resolveRoute(for sizeClass: UserInterfaceSizeClass?) {
        let route = TabRoute(tab: selection, morePath: morePath).resolved(for: sizeClass)
        if route.tab != selection { selection = route.tab }
        if route.morePath != morePath { morePath = route.morePath }
    }
}

extension MoreDestination {
    /// The More list's Management section, in order (Settings has its own).
    static let managementCases: [MoreDestination] = [.tags, .categories, .fixedExpenses, .scheduled]

    var title: String {
        switch self {
        case .tags: "Tags"
        case .categories: "Categories"
        case .fixedExpenses: "Fixed Expenses"
        // label matches nav-config ("Scheduled")
        case .scheduled: "Scheduled"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .tags: "tag"
        // web Tag
        case .categories: "tag"
        // web Receipt
        case .fixedExpenses: "receipt"
        // web CalendarClock
        case .scheduled: "calendar.badge.clock"
        case .settings: "gear"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .tags: TagsListView()
        case .categories: CategoryListView()
        case .fixedExpenses: FixedExpenseListView()
        case .scheduled: ScheduledListView()
        case .settings: SettingsView()
        }
    }
}
