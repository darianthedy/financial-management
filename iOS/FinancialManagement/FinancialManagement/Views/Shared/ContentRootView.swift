import SwiftUI

struct ContentRootView: View {
    var body: some View {
        TabView {
            // Tab set / order / labels mirror web's nav-config.ts primary items
            // (Dashboard, Accounts, Transactions, Budgets); SF Symbols are chosen
            // to match each Lucide icon there.
            NavigationStack {
                DashboardView()
            }
            // web LayoutDashboard (grid)
            .tabItem { Label("Dashboard", systemImage: "square.grid.2x2") }

            NavigationStack {
                AccountListView()
            }
            // web Wallet
            .tabItem { Label("Accounts", systemImage: "wallet.bifold") }

            NavigationStack {
                TransactionListView()
            }
            // web ArrowLeftRight
            .tabItem { Label("Transactions", systemImage: "arrow.left.arrow.right") }

            NavigationStack {
                BudgetListView()
            }
            // web PiggyBank (no SF piggy-bank symbol; target reads as a budget goal)
            .tabItem { Label("Budgets", systemImage: "target") }

            NavigationStack {
                MoreView()
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
        }
    }
}
