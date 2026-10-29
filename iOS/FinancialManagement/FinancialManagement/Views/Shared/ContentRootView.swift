import SwiftUI

struct ContentRootView: View {
    /// Restored per scene (window), so the app reopens on the last tab.
    @SceneStorage("root.tab") private var selection: AppTab = .dashboard

    var body: some View {
        TabView(selection: $selection) {
            // Tab set / order / labels mirror web's nav-config.ts primary items
            // (Dashboard, Accounts, Transactions, Budgets); SF Symbols are chosen
            // to match each Lucide icon there.
            NavigationStack {
                DashboardView()
            }
            // web LayoutDashboard (grid)
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }
            .tag(AppTab.dashboard)

            NavigationStack {
                AccountListView()
            }
            // web Wallet
            .tabItem { Label("Accounts", systemImage: "wallet.bifold") }
            .tag(AppTab.accounts)

            NavigationStack {
                TransactionListView()
            }
            // web ArrowLeftRight
            .tabItem { Label("Transactions", systemImage: "arrow.left.arrow.right") }
            .tag(AppTab.transactions)

            NavigationStack {
                BudgetListView()
            }
            // web PiggyBank (no SF piggy-bank symbol; target reads as a budget goal)
            .tabItem { Label("Budgets", systemImage: "target") }
            .tag(AppTab.budgets)

            NavigationStack {
                MoreView()
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
            .tag(AppTab.more)
        }
    }
}
